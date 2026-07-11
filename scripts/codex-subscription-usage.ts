#!/usr/bin/env -S node
/**
 * Fetch Codex subscription rate-limit usage through llm-proxy,
 * then print an InfluxDB line-protocol snapshot to stdout.
 *
 * The proxy response's `body` property is a JSON-encoded string and is
 * decoded before the subscription data is processed.
 *
 * Required env vars:
 *   - CODEX_USAGE_PROXY_TOKEN
 *   - CODEX_USAGE_AUTH_INDEX
 *   - CODEX_USAGE_ACCOUNT_ID
 *
 * Optional env vars:
 *   - CODEX_USAGE_CHATGPT_TOKEN (default: $TOKEN$; resolved by llm-proxy for the selected auth index)
 *   - CODEX_USAGE_PROXY_URL (default: https://llm-proxy.os.gkzhb.top/v0/management/api-call)
 *   - CODEX_USAGE_MEASUREMENT (default: codex_subscription_usage)
 *   - CODEX_USAGE_USER_AGENT (default: codex_cli_rs/0.76.0)
 */

type RateLimitWindow = {
  used_percent?: number;
  limit_window_seconds?: number;
  reset_after_seconds?: number;
  reset_at?: number;
};

type UsageResponse = {
  plan_type?: string;
  rate_limit?: {
    allowed?: boolean;
    limit_reached?: boolean;
    primary_window?: RateLimitWindow;
    secondary_window?: RateLimitWindow;
  };
  credits?: {
    has_credits?: boolean;
    unlimited?: boolean;
    overage_limit_reached?: boolean;
    balance?: string;
  };
  rate_limit_reset_credits?: {
    available_count?: number;
  };
};

type ProxyResponse = {
  status_code?: number;
  body?: string;
};

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required env var: ${name}`);
  return value;
}

function escapeTag(value: string): string {
  return value
    .replaceAll('\\', '\\\\')
    .replaceAll(',', '\\,')
    .replaceAll(' ', '\\ ')
    .replaceAll('=', '\\=');
}

function intField(name: string, value: number | undefined): string {
  return `${name}=${Math.trunc(value ?? 0)}i`;
}

function boolField(name: string, value: boolean | undefined): string {
  return `${name}=${value ?? false}`;
}

function remainingPercent(usedPercent: number | undefined): number {
  return Math.max(0, Math.min(100, 100 - (usedPercent ?? 0)));
}

function toLineProtocol(measurement: string, usage: UsageResponse): string {
  const rateLimit = usage.rate_limit ?? {};
  const primary = rateLimit.primary_window ?? {};
  const secondary = rateLimit.secondary_window ?? {};
  const planType = usage.plan_type ?? 'unknown';
  const credits = usage.credits ?? {};

  const fields = [
    intField('primary_used_percent', primary.used_percent),
    intField('primary_remaining_percent', remainingPercent(primary.used_percent)),
    intField('primary_limit_window_seconds', primary.limit_window_seconds),
    intField('primary_reset_at', primary.reset_at),
    intField('secondary_used_percent', secondary.used_percent),
    intField('secondary_remaining_percent', remainingPercent(secondary.used_percent)),
    intField('secondary_limit_window_seconds', secondary.limit_window_seconds),
    intField('secondary_reset_at', secondary.reset_at),
    boolField('allowed', rateLimit.allowed),
    boolField('limit_reached', rateLimit.limit_reached),
    boolField('has_credits', credits.has_credits),
    boolField('unlimited_credits', credits.unlimited),
    boolField('overage_limit_reached', credits.overage_limit_reached),
    intField('rate_limit_reset_credits_available', usage.rate_limit_reset_credits?.available_count),
  ];

  return `${measurement},plan_type=${escapeTag(planType)} ${fields.join(',')} ${Date.now() * 1000000}`;
}

async function main() {
  const proxyToken = requireEnv('CODEX_USAGE_PROXY_TOKEN');
  const authIndex = requireEnv('CODEX_USAGE_AUTH_INDEX');
  const accountId = requireEnv('CODEX_USAGE_ACCOUNT_ID');
  const chatgptToken = process.env.CODEX_USAGE_CHATGPT_TOKEN ?? '$TOKEN$';
  const proxyUrl = process.env.CODEX_USAGE_PROXY_URL ?? 'https://llm-proxy.os.gkzhb.top/v0/management/api-call';
  const measurement = process.env.CODEX_USAGE_MEASUREMENT ?? 'codex_subscription_usage';
  const userAgent = process.env.CODEX_USAGE_USER_AGENT ?? 'codex_cli_rs/0.76.0 (Debian 13.0.0; x86_64) WindowsTerminal';

  const response = await fetch(proxyUrl, {
    method: 'POST',
    headers: {
      Accept: 'application/json',
      Authorization: `Bearer ${proxyToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      authIndex,
      method: 'GET',
      url: 'https://chatgpt.com/backend-api/wham/usage',
      header: {
        Authorization: `Bearer ${chatgptToken}`,
        'Content-Type': 'application/json',
        'User-Agent': userAgent,
        'Chatgpt-Account-Id': accountId,
      },
    }),
  });

  if (!response.ok) {
    throw new Error(`Codex proxy request failed: ${response.status} ${response.statusText}\n${await response.text()}`);
  }

  const proxyPayload = (await response.json()) as ProxyResponse;
  if (proxyPayload.status_code !== 200) {
    throw new Error(`Codex usage request returned status_code=${proxyPayload.status_code ?? 'unknown'}`);
  }
  if (typeof proxyPayload.body !== 'string') {
    throw new Error('Codex proxy response is missing string body');
  }

  let usage: UsageResponse;
  try {
    usage = JSON.parse(proxyPayload.body) as UsageResponse;
  } catch (error) {
    throw new Error(`Failed to parse Codex proxy response body: ${error instanceof Error ? error.message : String(error)}`);
  }

  process.stdout.write(toLineProtocol(measurement, usage) + '\n');
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});
