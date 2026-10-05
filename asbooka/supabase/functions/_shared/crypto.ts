// Шифрование паролей приложений CalDAV (AES-GCM). Ключ — SHA-256 от
// секрета CALDAV_ENCRYPTION_KEY, который задаётся в секретах функций.

async function key(secret: string): Promise<CryptoKey> {
  const raw = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(secret));
  return crypto.subtle.importKey("raw", raw, "AES-GCM", false, ["encrypt", "decrypt"]);
}

function toB64(bytes: Uint8Array): string {
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s);
}

function fromB64(s: string): Uint8Array {
  return Uint8Array.from(atob(s), (c) => c.charCodeAt(0));
}

export async function encryptSecret(plain: string, secret: string): Promise<string> {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ct = new Uint8Array(
    await crypto.subtle.encrypt({ name: "AES-GCM", iv }, await key(secret), new TextEncoder().encode(plain)),
  );
  const out = new Uint8Array(iv.length + ct.length);
  out.set(iv);
  out.set(ct, iv.length);
  return toB64(out);
}

export async function decryptSecret(enc: string, secret: string): Promise<string> {
  const bytes = fromB64(enc);
  const plain = await crypto.subtle.decrypt(
    { name: "AES-GCM", iv: bytes.slice(0, 12) },
    await key(secret),
    bytes.slice(12),
  );
  return new TextDecoder().decode(plain);
}

/** HMAC-SHA256 в base64url — для подписи state в OAuth. */
export async function hmac(data: string, secret: string): Promise<string> {
  const k = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = new Uint8Array(await crypto.subtle.sign("HMAC", k, new TextEncoder().encode(data)));
  return toB64(sig).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}
