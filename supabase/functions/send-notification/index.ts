// Skickar en notis som push till telefonen och, för viktiga händelser, som mejl via Resend.
// Anropas av databasen (pg_net) när en rad läggs i public.notifications.
// Funktionen tar bara emot ett notis-id och skickar bara notiser som inte redan skickats,
// så ett anrop utifrån kan inte skapa eller ändra innehåll.
import { createClient } from "npm:@supabase/supabase-js@2.45.4";
import webpush from "npm:web-push@3.6.7";

const APP_URL = "https://ludvigjbohlin-afk.github.io/TeeTime/";
const EMAIL_KINDS = new Set(["watch", "proposal", "proposal_booked", "cancelled_by_club", "round_cancelled", "reminder", "friend_request"]);

function esc(s: string) {
  return String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]!));
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("method", { status: 405 });
  let id = "";
  try { id = (await req.json()).id; } catch { /* tomt */ }
  if (!id || !/^[0-9a-f-]{36}$/.test(id)) return new Response("bad id", { status: 400 });

  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });

  // Ta notisen exakt en gång
  const { data: n } = await sb.from("notifications").update({ sent_at: new Date().toISOString() })
    .eq("id", id).is("sent_at", null).select().maybeSingle();
  if (!n) return new Response("already sent", { status: 200 });

  const { data: st } = await sb.from("settings").select("notify_push, notify_email").eq("user_id", n.user_id).maybeSingle();
  const result: Record<string, unknown> = { push: 0, email: false };
  const url = APP_URL + (n.kind === "watch" ? "#bevaka" : /^(proposal|friend)/.test(n.kind) ? "#vanner" : "#mina");

  // Push
  if (!st || st.notify_push) {
    const { data: subs } = await sb.from("push_subscriptions").select("id, endpoint, p256dh, auth").eq("user_id", n.user_id);
    if (subs && subs.length) {
      const { data: cfg } = await sb.rpc("get_push_config");
      if (cfg?.public && cfg?.private) {
        webpush.setVapidDetails("mailto:noreply@teetime.app", cfg.public, cfg.private);
        const payload = JSON.stringify({ title: n.title, body: n.body, url, kind: n.kind, id: n.id, tag: n.kind + ":" + (n.data?.watch_id || n.data?.proposal_id || n.id) });
        for (const s of subs) {
          try {
            await webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, payload, { TTL: 60 * 60 * 12, urgency: "high" });
            (result.push as number)++;
          } catch (e) {
            const code = (e as { statusCode?: number }).statusCode;
            if (code === 404 || code === 410) await sb.from("push_subscriptions").delete().eq("id", s.id);
            else console.error("push", code, String(e));
          }
        }
      }
    }
  }

  // Mejl
  const key = Deno.env.get("RESEND_API_KEY");
  if (key && EMAIL_KINDS.has(n.kind) && (!st || st.notify_email)) {
    const { data: u } = await sb.auth.admin.getUserById(n.user_id);
    const to = u?.user?.email;
    if (to) {
      const from = Deno.env.get("EMAIL_FROM") || "TeeTime <onboarding@resend.dev>";
      const html = `<div style="font-family:system-ui,-apple-system,Segoe UI,sans-serif;max-width:520px;margin:0 auto;padding:24px;color:#14281e">
        <p style="font-weight:700;font-size:20px;margin:0 0 8px">${esc(n.title)}</p>
        <p style="font-size:16px;line-height:1.5;margin:0 0 20px">${esc(n.body)}</p>
        <a href="${url}" style="display:inline-block;background:#1d5c3b;color:#fff;text-decoration:none;padding:12px 18px;border-radius:10px;font-weight:600">Öppna TeeTime</a>
        <p style="font-size:12px;color:#5b6e63;margin-top:24px">Du får det här mejlet eftersom du har mejlnotiser påslagna i TeeTime. Stäng av dem under Profil.</p></div>`;
      const r = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: { "Authorization": `Bearer ${key}`, "Content-Type": "application/json" },
        body: JSON.stringify({ from, to: [to], subject: n.title, html, text: `${n.title}\n\n${n.body}\n\n${url}` }),
      });
      result.email = r.ok;
      if (!r.ok) console.error("resend", r.status, await r.text());
    }
  }

  return new Response(JSON.stringify(result), { headers: { "Content-Type": "application/json" } });
});
