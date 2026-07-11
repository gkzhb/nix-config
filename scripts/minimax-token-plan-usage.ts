#!/usr/bin/env -S node
/**
 * Fetch MiniMax token plan remaining quota snapshot,
 * then print InfluxDB line protocol to stdout.
 *
 * Required env vars:
 *   - MINIMAX_API_TOKEN
 *
 * Optional env vars:
 *   - MINIMAX_BASE_URL (default: https://www.minimaxi.com)
 *   - MINIMAX_MEASUREMENT (default: minimax_token_plan_usage)
 */

type ModelRemain = {
  start_time?: number;
  end_time?: number;
  remains_time?: number;
  current_interval_total_count?: number;
  current_interval_usage_count?: number;
  model_name?: string;
  current_weekly_total_count?: number;
  current_weekly_usage_count?: number;
  weekly_start_time?: number;
  weekly_end_time?: number;
  weekly_remains_time?: number;
  current_interval_status?: number;
  current_interval_remaining_percent?: number;
  current_weekly_status?: number;
  current_weekly_remaining_percent?: number;
};

type ApiResponse = {
  model_remains?: ModelRemain[];
  base_resp?: {
    status_code?: number;
    status_msg?: string;
  };
};

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required env var: ${name}`);
  }
  return value;
}

function escapeTag(value: string): string {
  return value
    .replaceAll('\\', '\\\\')
    .replaceAll(',', '\\,')
    .replaceAll(' ', '\\ ')
    .replaceAll('=', '\\=');
}

function escapeStringField(value: string): string {
  return `"${value.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"`;
}

function intField(value: number | undefined, name: string): string {
  return `${name}=${Math.trunc(value ?? 0)}i`;
}

function toLineProtocol(measurement: string, record: ModelRemain, timestampMs: number): string {
  const modelName = record.model_name || 'unknown';
  const tags = [`model_name=${escapeTag(modelName)}`];

  const fields = [
    intField(record.remains_time, 'remains_time'),
    intField(record.current_interval_total_count, 'current_interval_total_count'),
    intField(record.current_interval_usage_count, 'current_interval_usage_count'),
    intField(record.current_weekly_total_count, 'current_weekly_total_count'),
    intField(record.current_weekly_usage_count, 'current_weekly_usage_count'),
    intField(record.weekly_remains_time, 'weekly_remains_time'),
    intField(record.current_interval_status, 'current_interval_status'),
    intField(record.current_interval_remaining_percent, 'current_interval_remaining_percent'),
    intField(record.current_weekly_status, 'current_weekly_status'),
    intField(record.current_weekly_remaining_percent, 'current_weekly_remaining_percent'),
    intField(record.start_time, 'start_time_ms'),
    intField(record.end_time, 'end_time_ms'),
    intField(record.weekly_start_time, 'weekly_start_time_ms'),
    intField(record.weekly_end_time, 'weekly_end_time_ms'),
    `model_name_str=${escapeStringField(modelName)}`,
  ];

  const timestampNs = BigInt(timestampMs) * 1000000n;
  return `${measurement},${tags.join(',')} ${fields.join(',')} ${timestampNs.toString()}`;
}

async function main() {
  const apiToken = requireEnv('MINIMAX_API_TOKEN');
  const baseUrl = process.env.MINIMAX_BASE_URL ?? 'https://www.minimaxi.com';
  const measurement = process.env.MINIMAX_MEASUREMENT ?? 'minimax_token_plan_usage';

  const url = new URL('/v1/token_plan/remains', baseUrl);
  const response = await fetch(url, {
    headers: {
      Authorization: `Bearer ${apiToken}`,
      'Content-Type': 'application/json',
    },
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`MiniMax request failed: ${response.status} ${response.statusText}\n${body}`);
  }

  const payload = (await response.json()) as ApiResponse;
  if ((payload.base_resp?.status_code ?? -1) !== 0) {
    throw new Error(`MiniMax returned error: ${payload.base_resp?.status_msg ?? 'unknown error'}`);
  }

  const rows = (payload.model_remains ?? [])
    .filter((row) => row && typeof row === 'object')
    .sort((a, b) => (a.model_name ?? '').localeCompare(b.model_name ?? ''));

  const nowMs = Date.now();
  for (const row of rows) {
    process.stdout.write(toLineProtocol(measurement, row, nowMs) + '\n');
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});
