/**
 * ICEDRAGON HUB - VampAuth Standalone Key Check Proxy (Cloudflare Worker)
 * Keeps VAMPAUTH_AUTH_SECRET inside Cloudflare Secrets (never in public GitHub).
 *
 * Required Cloudflare Secret:
 *   VAMPAUTH_AUTH_SECRET  (48-char Auth Secret from VampAuth Dashboard)
 * Optional Cloudflare Variable:
 *   VAMPAUTH_PROJECT_ID   (defaults to "JUHQH1GGWXPPS4UU")
 */

const VAMPAUTH_API_URL = "https://vampauth.com/api/v1/key/check";
const DEFAULT_PROJECT_ID = "JUHQH1GGWXPPS4UU";
const MAX_BODY_BYTES = 8192;

function jsonResponse(payload, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Accept",
    },
  });
}

function bytesToHex(bytes) {
  let out = "";
  for (let i = 0; i < bytes.length; i++) {
    out += bytes[i].toString(16).padStart(2, "0");
  }
  return out;
}

function randomNonceHex(byteLen = 16) {
  const buf = new Uint8Array(byteLen);
  crypto.getRandomValues(buf);
  return bytesToHex(buf);
}

async function hmacSha1Hex(secretUtf8, messageUtf8) {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(secretUtf8),
    { name: "HMAC", hash: "SHA-1" },
    false,
    ["sign"]
  );
  const sig = await crypto.subtle.sign("HMAC", key, enc.encode(messageUtf8));
  return bytesToHex(new Uint8Array(sig));
}

function constantTimeEquals(a, b) {
  if (typeof a !== "string" || typeof b !== "string" || a.length !== b.length) {
    return false;
  }
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

function expirySecondsFromIso(expiresAt) {
  if (expiresAt === null || expiresAt === undefined || expiresAt === "") {
    return 0;
  }
  const ms = Date.parse(String(expiresAt));
  if (!Number.isFinite(ms)) {
    return 0;
  }
  return Math.floor(ms / 1000);
}

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return jsonResponse({ ok: true }, 204);
    }

    const url = new URL(request.url);
    const projectId = (env && env.VAMPAUTH_PROJECT_ID) || DEFAULT_PROJECT_ID;

    if (request.method === "GET" && (url.pathname === "/" || url.pathname === "/health")) {
      return jsonResponse({
        ok: true,
        service: "icedragon-vampauth-proxy",
        project_id: projectId,
        configured: Boolean(env && env.VAMPAUTH_AUTH_SECRET),
      });
    }

    if (request.method !== "POST" || url.pathname !== "/check") {
      return jsonResponse({ valid: false, error: "not_found" }, 404);
    }

    const authSecret = env && env.VAMPAUTH_AUTH_SECRET ? String(env.VAMPAUTH_AUTH_SECRET) : "";
    if (!authSecret) {
      return jsonResponse({ valid: false, error: "server_misconfigured" }, 500);
    }

    let rawBody = "";
    try {
      rawBody = await request.text();
    } catch {
      return jsonResponse({ valid: false, error: "invalid_request" }, 400);
    }

    if (!rawBody || rawBody.length > MAX_BODY_BYTES) {
      return jsonResponse({ valid: false, error: "invalid_request" }, 400);
    }

    let input;
    try {
      input = JSON.parse(rawBody);
    } catch {
      return jsonResponse({ valid: false, error: "invalid_request" }, 400);
    }

    const rawKey = typeof input?.key === "string" ? input.key.trim() : "";
    const hwid = typeof input?.hwid === "string" ? input.hwid.toLowerCase().trim() : "";

    if (!rawKey || rawKey.length > 128 || /[\x00-\x1f\x7f]/.test(rawKey)) {
      return jsonResponse({ valid: false, error: "invalid_request" }, 400);
    }
    if (!/^[0-9a-f]{64}$/.test(hwid)) {
      return jsonResponse({ valid: false, error: "invalid_request" }, 400);
    }

    const nonce = randomNonceHex(16);
    const signature = await hmacSha1Hex(authSecret, `${nonce}|${rawKey}|${hwid}`);

    let upstreamResp;
    let upstreamText = "";
    try {
      upstreamResp = await fetch(VAMPAUTH_API_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "User-Agent": "IceDragonHub-Worker/1.0",
        },
        body: JSON.stringify({
          project_id: projectId,
          key: rawKey,
          hwid,
          nonce,
          signature,
        }),
      });
      upstreamText = await upstreamResp.text();
    } catch {
      return jsonResponse({ valid: false, error: "service_unavailable" }, 503);
    }

    let data = null;
    try {
      data = JSON.parse(upstreamText);
    } catch {
      return jsonResponse({ valid: false, error: `HTTP_${upstreamResp.status}` }, 502);
    }

    if (!upstreamResp.ok) {
      return jsonResponse(
        {
          valid: false,
          error: String(data?.error || data?.message || `HTTP_${upstreamResp.status}`),
        },
        upstreamResp.status
      );
    }

    if (
      data?.status !== "valid" ||
      data?.project_id !== projectId ||
      data?.nonce_echo !== nonce ||
      typeof data?.signature !== "string" ||
      !/^[0-9a-f]{40}$/.test(data.signature)
    ) {
      return jsonResponse({ valid: false, error: "invalid_server_response" }, 502);
    }

    const expSec = expirySecondsFromIso(data.expires_at);
    const verifyMsg = `${nonce}|${data.status}|${expSec}|${projectId}`;
    const expectedSig = await hmacSha1Hex(authSecret, verifyMsg);
    if (!constantTimeEquals(expectedSig, data.signature)) {
      return jsonResponse({ valid: false, error: "bad_response_signature" }, 502);
    }

    if (data.expires_at !== null && data.expires_at !== undefined) {
      const expMs = Date.parse(String(data.expires_at));
      if (!Number.isFinite(expMs) || expMs <= Date.now()) {
        return jsonResponse({ valid: false, error: "key_expired" }, 410);
      }
    }

    return jsonResponse({
      valid: true,
      status: "valid",
      project_id: data.project_id,
      hwid_bound: Boolean(data.hwid_bound),
      expires_at: data.expires_at ?? null,
    });
  },
};
