// Send SMS Hook для Supabase Auth: отправка кода входа через SMS.ru,
// чтобы коды доходили на российские номера без Twilio.
//
// Секреты: SMS_HOOK_SECRET (вида v1,whsec_... из настроек хука),
// SMSRU_API_ID (ключ API из личного кабинета sms.ru), SMS_SENDER (необязательно).

import { Webhook } from "npm:standardwebhooks@1.0.0";
import { env } from "../_shared/http.ts";

function hookError(message: string, status = 500): Response {
  return new Response(JSON.stringify({ error: { http_code: status, message } }), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  const payload = await req.text();
  const secret = env("SMS_HOOK_SECRET").replace("v1,whsec_", "");
  let data: { user: { phone: string }; sms: { otp: string } };
  try {
    data = new Webhook(secret).verify(payload, Object.fromEntries(req.headers)) as typeof data;
  } catch {
    return hookError("Неверная подпись хука", 401);
  }

  const params = new URLSearchParams({
    api_id: env("SMSRU_API_ID"),
    to: data.user.phone.replace(/\D/g, ""),
    msg: `ASBooka: код входа ${data.sms.otp}`,
    json: "1",
  });
  const sender = Deno.env.get("SMS_SENDER");
  if (sender) params.set("from", sender);

  const res = await fetch(`https://sms.ru/sms/send?${params}`);
  const body = await res.json().catch(() => null);
  if (!res.ok || body?.status !== "OK") {
    return hookError(`SMS не отправлено: ${body?.status_text ?? res.status}`);
  }
  const perPhone = Object.values(body.sms ?? {})[0] as { status?: string; status_text?: string } | undefined;
  if (perPhone && perPhone.status !== "OK") {
    return hookError(`SMS не отправлено: ${perPhone.status_text ?? perPhone.status}`);
  }
  return new Response("{}", { status: 200, headers: { "Content-Type": "application/json" } });
});
