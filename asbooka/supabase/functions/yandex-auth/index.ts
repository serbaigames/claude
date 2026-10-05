// Вход через Яндекс ID.
//
// GET  /yandex-auth?redirect_to=<адрес приложения>
//      → перенаправляет на oauth.yandex.ru
// GET  /yandex-auth/callback?code=...&state=...
//      → создаёт или находит пользователя и возвращает в приложение
//        <redirect_to>?yandex_token_hash=..., приложение вызывает verifyOTP
// GET  /yandex-auth?mode=code
//      → Яндекс покажет код подтверждения (для Windows, где нет ссылок asbooka://)
// POST /yandex-auth/exchange { code }
//      → { token_hash } для кода, введённого вручную
//
// Секреты: YANDEX_CLIENT_ID, YANDEX_CLIENT_SECRET, AUTH_STATE_SECRET,
// ALLOWED_REDIRECTS (через запятую префиксы адресов возврата).

import { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { adminClient, corsHeaders, env, json } from "../_shared/http.ts";
import { hmac, timingSafeEqual } from "../_shared/crypto.ts";

const VERIFICATION_CODE_URI = "https://oauth.yandex.ru/verification_code";

function callbackUri(): string {
  return `${env("SUPABASE_URL")}/functions/v1/yandex-auth/callback`;
}

function allowedRedirect(url: string): boolean {
  const prefixes = (Deno.env.get("ALLOWED_REDIRECTS") ?? "asbooka://")
    .split(",").map((s) => s.trim()).filter(Boolean);
  return prefixes.some((p) => url.startsWith(p));
}

function b64url(s: string): string {
  return btoa(unescape(encodeURIComponent(s))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function fromB64url(s: string): string {
  const b = s.replace(/-/g, "+").replace(/_/g, "/");
  return decodeURIComponent(escape(atob(b + "===".slice((b.length + 3) % 4))));
}

async function signState(redirectTo: string): Promise<string> {
  const payload = b64url(JSON.stringify({ r: redirectTo, t: Date.now(), n: crypto.randomUUID() }));
  return `${payload}.${await hmac(payload, env("AUTH_STATE_SECRET"))}`;
}

async function readState(state: string): Promise<string | null> {
  const [payload, sig] = state.split(".");
  if (!payload || !sig) return null;
  if (!timingSafeEqual(sig, await hmac(payload, env("AUTH_STATE_SECRET")))) return null;
  const { r, t } = JSON.parse(fromB64url(payload));
  if (Date.now() - t > 15 * 60 * 1000 || !allowedRedirect(r)) return null;
  return r;
}

function withParams(url: string, params: Record<string, string>): string {
  const qs = new URLSearchParams(params).toString();
  // Для веб-версии с hash-маршрутами параметры кладём перед '#'.
  const hash = url.indexOf("#");
  const base = hash >= 0 ? url.slice(0, hash) : url;
  const tail = hash >= 0 ? url.slice(hash) : "";
  return base + (base.includes("?") ? "&" : "?") + qs + tail;
}

function redirect(url: string): Response {
  return new Response(null, { status: 302, headers: { Location: url } });
}

async function exchangeCode(code: string): Promise<string> {
  const res = await fetch("https://oauth.yandex.ru/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "authorization_code",
      code,
      client_id: env("YANDEX_CLIENT_ID"),
      client_secret: env("YANDEX_CLIENT_SECRET"),
    }),
  });
  const data = await res.json();
  if (!res.ok || !data.access_token) throw new Error(data.error_description ?? "Яндекс не выдал токен");
  return data.access_token;
}

interface YandexInfo {
  id: string;
  login?: string;
  default_email?: string;
  real_name?: string;
  display_name?: string;
  default_phone?: { number?: string };
}

function normalizePhone(p?: string): string | null {
  let d = (p ?? "").replace(/\D/g, "");
  if (d.length === 11 && d.startsWith("8")) d = "7" + d.slice(1);
  if (d.length === 10 && d.startsWith("9")) d = "7" + d;
  return d || null;
}

async function tokenHashFor(db: SupabaseClient, info: YandexInfo): Promise<string> {
  const yid = String(info.id);
  const synthetic = `yandex-${yid}@users.asbooka.app`;
  const phone = normalizePhone(info.default_phone?.number);
  const name = info.real_name || info.display_name || info.login || "";

  let userId: string | null = null;
  const byYandex = await db.from("profiles").select("id").eq("yandex_id", yid).maybeSingle();
  userId = byYandex.data?.id ?? null;

  // Тот же человек уже входил по телефону — подключаем Яндекс к его аккаунту.
  if (!userId && phone) {
    const byPhone = await db.from("profiles").select("id,yandex_id").eq("phone", phone).maybeSingle();
    if (byPhone.data && !byPhone.data.yandex_id) {
      userId = byPhone.data.id;
      await db.from("profiles").update({ yandex_id: yid }).eq("id", userId);
    }
  }

  let email: string;
  if (userId) {
    const { data, error } = await db.auth.admin.getUserById(userId);
    if (error) throw error;
    email = data.user.email ?? "";
    if (!email) {
      email = synthetic;
      const upd = await db.auth.admin.updateUserById(userId, { email, email_confirm: true });
      if (upd.error) throw upd.error;
    }
  } else {
    const meta = { app_metadata: { provider: "yandex", yandex_id: yid }, user_metadata: { display_name: name } };
    let created = await db.auth.admin.createUser({
      email: info.default_email || synthetic,
      email_confirm: true,
      ...meta,
    });
    if (created.error && info.default_email) {
      created = await db.auth.admin.createUser({ email: synthetic, email_confirm: true, ...meta });
    }
    if (created.error) throw created.error;
    userId = created.data.user.id;
    email = created.data.user.email!;
    if (phone) {
      // Если номер свободен, он подтверждён Яндексом — привязываем.
      const taken = await db.from("profiles").select("id").eq("phone", phone).maybeSingle();
      if (!taken.data) await db.auth.admin.updateUserById(userId, { phone, phone_confirm: true });
    }
  }

  const link = await db.auth.admin.generateLink({ type: "magiclink", email });
  if (link.error) throw link.error;
  return link.data.properties.hashed_token;
}

async function loginWithCode(code: string): Promise<string> {
  const token = await exchangeCode(code);
  const res = await fetch("https://login.yandex.ru/info?format=json", {
    headers: { Authorization: `OAuth ${token}` },
  });
  if (!res.ok) throw new Error("Не удалось получить профиль Яндекса");
  return tokenHashFor(adminClient(), await res.json());
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  const url = new URL(req.url);

  try {
    if (req.method === "POST" && url.pathname.endsWith("/exchange")) {
      const { code } = await req.json();
      if (!code) return json({ error: "Нет кода" }, 400);
      return json({ token_hash: await loginWithCode(String(code).trim()) });
    }

    if (url.pathname.endsWith("/callback")) {
      const redirectTo = await readState(url.searchParams.get("state") ?? "");
      if (!redirectTo) return json({ error: "Неверный или устаревший state" }, 400);
      const err = url.searchParams.get("error");
      const code = url.searchParams.get("code");
      if (err || !code) return redirect(withParams(redirectTo, { yandex_error: err ?? "no_code" }));
      try {
        return redirect(withParams(redirectTo, { yandex_token_hash: await loginWithCode(code) }));
      } catch (e) {
        return redirect(withParams(redirectTo, { yandex_error: (e as Error).message }));
      }
    }

    // Начало входа
    const params = new URLSearchParams({ response_type: "code", client_id: env("YANDEX_CLIENT_ID") });
    if (url.searchParams.get("mode") === "code") {
      params.set("redirect_uri", VERIFICATION_CODE_URI);
    } else {
      const redirectTo = url.searchParams.get("redirect_to") ?? "";
      if (!allowedRedirect(redirectTo)) return json({ error: "Адрес возврата не разрешён" }, 400);
      params.set("redirect_uri", callbackUri());
      params.set("state", await signState(redirectTo));
    }
    return redirect(`https://oauth.yandex.ru/authorize?${params}`);
  } catch (e) {
    return json({ error: (e as Error).message }, 500);
  }
});
