import { execFile } from "node:child_process";
import { readFile } from "node:fs/promises";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

const batteryDir = "/sys/class/power_supply/qcom-battery";
const usbOnlinePath = "/sys/class/power_supply/qcom-smbchg-usb/online";

type BatteryPayload = {
  battery: number;
  charging: number;
  temperature?: number;
};

async function readTrimmed(file: string, optional = false): Promise<string | undefined> {
  try {
    return (await readFile(file, "utf8")).trim();
  } catch (error: unknown) {
    const code = (error as NodeJS.ErrnoException).code;
    if (optional && (code === "ENOENT" || code === "ENOTDIR")) {
      return undefined;
    }
    throw error;
  }
}

function parseTemperature(raw: string): number | undefined {
  const value = Number(raw);
  if (!Number.isFinite(value)) {
    return undefined;
  }

  // qcom-battery exposes temperature in tenths of a degree Celsius.
  return Math.round(value) / 10;
}

async function main(): Promise<void> {
  const capacityRaw = await readTrimmed(`${batteryDir}/capacity`);
  if (!/^\d+$/.test(capacityRaw)) {
    throw new Error(`Invalid battery capacity: ${capacityRaw}`);
  }

  const payload: BatteryPayload = {
    battery: Math.max(0, Math.min(100, Number(capacityRaw))),
    // The battery status changes on USB insertion; USB online=1 means power
    // is actually available from the charger.
    charging: (await readTrimmed(usbOnlinePath)) === "1" ? 1 : 0,
  };

  const temperatureRaw = await readTrimmed(`${batteryDir}/temp`, true);
  if (temperatureRaw !== undefined) {
    const temperature = parseTemperature(temperatureRaw);
    if (temperature !== undefined) {
      payload.temperature = temperature;
    }
  }

  const host = process.env.MQTT_HOST ?? "127.0.0.1";
  const port = process.env.MQTT_PORT ?? "1883";
  const topic = process.env.MQTT_TOPIC ?? "device/mido/battery";
  const qos = process.env.MQTT_QOS ?? "1";
  const message = JSON.stringify(payload);

  await execFileAsync("mosquitto_pub", [
    "-h", host,
    "-p", port,
    "-t", topic,
    "-q", qos,
    "-m", message,
  ], { timeout: 15_000 });

  console.log(`Published battery telemetry to ${topic}: ${message}`);
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.stack ?? error.message : String(error));
  process.exitCode = 1;
});
