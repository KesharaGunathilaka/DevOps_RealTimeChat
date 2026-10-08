// End-to-end smoke test of a running stack, exercised through nginx exactly as
// a browser would: static files, SPA routing, health, auth cookie, and a chat
// message delivered in real time over a proxied WebSocket.
//
//   npm --prefix frontend install          # provides socket.io-client
//   node scripts/smoke-test.cjs http://localhost:3000
//   node scripts/smoke-test.cjs http://<ec2-public-ip>
//
// Creates two throwaway users (*@e2e.local) on each run.
const path = require("path");
const { io } = require(path.join(__dirname, "../frontend/node_modules/socket.io-client"));
const BASE = process.argv[2] || "http://localhost:3000";
let pass = 0, fail = 0;
const ok = (c, m) => { console.log(`${c ? "PASS" : "FAIL"}  ${m}`); c ? pass++ : fail++; };

(async () => {
  let r = await fetch(BASE + "/");
  ok(r.status === 200 && (await r.text()).includes('id="root"'), "GET /  -> SPA index.html via nginx");
  r = await fetch(BASE + "/settings");
  ok(r.status === 200, "GET /settings -> SPA fallback (client-side route)");
  r = await fetch(BASE + "/api/health");
  const h = await r.json();
  ok(r.status === 200 && h.db === true, `GET /api/health -> ${r.status} ${JSON.stringify(h)}`);

  const pw = "e2e-" + Math.random().toString(36).slice(2, 12), tag = Date.now();
  const mk = async name => {
    const r = await fetch(BASE + "/api/auth/signup", { method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ fullName: name, email: `${name.toLowerCase()}${tag}@e2e.local`, password: pw }) });
    const sc = r.headers.get("set-cookie") || "";
    return { status: r.status, id: (await r.json())._id, cookie: sc.split(";")[0], secure: /;\s*secure/i.test(sc) };
  };
  const a = await mk("Sender"), b = await mk("Receiver");
  ok(a.status === 201 && b.status === 201, "POST /api/auth/signup x2 -> 201");
  ok(!a.secure, "jwt cookie has no Secure flag (survives plain-HTTP deploy)");

  r = await fetch(BASE + "/api/auth/check", { headers: { Cookie: b.cookie } });
  ok(r.status === 200, "GET /api/auth/check with cookie -> 200 (session works)");

  // Receiver connects over a WebSocket proxied by nginx
  const sock = io(BASE, { transports: ["websocket"], query: { userId: b.id } });
  const online = await new Promise((res, rej) => {
    sock.on("getOnlineUsers", ids => res(ids));
    sock.on("connect_error", e => rej(e));
    setTimeout(() => rej(new Error("timeout")), 8000);
  }).catch(e => { ok(false, "WebSocket connect: " + e.message); return []; });
  ok(sock.io.engine && sock.io.engine.transport.name === "websocket", "Socket.IO upgraded to a real WebSocket through nginx");
  ok(online.includes(b.id), "presence: receiver appears in getOnlineUsers");

  // Sender posts over REST; receiver should get a push
  const got = new Promise((res, rej) => { sock.on("newMessage", m => res(m)); setTimeout(() => rej(new Error("no push")), 8000); });
  r = await fetch(`${BASE}/api/chat/send/${b.id}`, { method: "POST",
    headers: { "Content-Type": "application/json", Cookie: a.cookie }, body: JSON.stringify({ text: "hello over nginx" }) });
  ok(r.status === 201, "POST /api/chat/send -> 201 (persisted)");
  const m = await got.catch(e => ({ err: e.message }));
  ok(m.text === "hello over nginx", "receiver got newMessage over WebSocket: " + (m.text || m.err));

  sock.close();
  console.log(`\n${pass} passed, ${fail} failed`);
  process.exit(fail ? 1 : 0);
})().catch(e => { console.error("ERROR", e); process.exit(1); });
