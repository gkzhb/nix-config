#!/usr/bin/env -S node
/**
 * Fetch NewAPI usage data for the past 3 hours,
 * then print InfluxDB line protocol to stdout.
 *
 * Required env vars:
 *   - NEWAPI_API_KEY
 *   - NEWAPI_USER_ID
 *
 * Optional env vars:
 *   - NEWAPI_BASE_URL (default: https://newapi.gkzhb.top)
 *   - NEWAPI_USERNAME (default: empty)
 *   - NEWAPI_LOOKBACK_SECONDS (default: 10800)
 *   - NEWAPI_MEASUREMENT (default: newapi_usage)
 */

type ApiRecord = {
  id: number;
  user_id: number;
  username: string;
  model_name: string;
  created_at: number;
  token_used: number;
  count: number;
  quota: number;
};

type ApiResponse = {
  data?: ApiRecord[];
  message?: string;
  success?: boolean;
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

function toLineProtocol(measurement: string, record: ApiRecord): string {
  const tags = [
    `model_name=${escapeTag(record.model_name || "unknown")}`,
  ];

  const fields = [
    `token_used=${Math.trunc(record.token_used)}i`,
    `request_count=${Math.trunc(record.count)}i`,
    `quota=${Math.trunc(record.quota)}i`,
    `model_name_str=${escapeStringField(record.model_name || "unknown")}`,
  ];

  const timestampNs = BigInt(record.created_at) * 1000000000n;
  return `${measurement},${tags.join(',')} ${fields.join(',')} ${timestampNs.toString()}`;
}

async function main() {
  const apiKey = requireEnv('NEWAPI_API_KEY');
  const userId = requireEnv('NEWAPI_USER_ID');
  const baseUrl = process.env.NEWAPI_BASE_URL ?? 'https://newapi.gkzhb.top';
  const username = process.env.NEWAPI_USERNAME ?? '';
  const lookbackSeconds = Number(process.env.NEWAPI_LOOKBACK_SECONDS ?? '10800');

  const measurement = process.env.NEWAPI_MEASUREMENT ?? 'newapi_usage';

  if (!Number.isFinite(lookbackSeconds) || lookbackSeconds <= 0) {
    throw new Error(`Invalid NEWAPI_LOOKBACK_SECONDS: ${process.env.NEWAPI_LOOKBACK_SECONDS}`);
  }

  const end = Math.floor(Date.now() / 1000);
  const start = end - lookbackSeconds;

  const url = new URL('/api/data/', baseUrl);
  url.searchParams.set('username', username);
  url.searchParams.set('start_timestamp', String(start));
  url.searchParams.set('end_timestamp', String(end));

  const response = await fetch(url, {
    headers: {
      accept: 'application/json',
      'new-api-user': userId,
      Authorization: apiKey,
    },
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`NewAPI request failed: ${response.status} ${response.statusText}\n${body}`);
  }

  const payload = (await response.json()) as ApiResponse;
  if (!payload.success) {
    throw new Error(`NewAPI returned success=false: ${payload.message ?? 'unknown error'}`);
  }

  const rows = (payload.data ?? [])
    .filter((row) => row && Number.isFinite(row.created_at) && row.created_at > 0)
    .sort((a, b) => a.created_at - b.created_at || a.model_name.localeCompare(b.model_name));

  for (const row of rows) {
    process.stdout.write(toLineProtocol(measurement, row) + '\n');
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});
