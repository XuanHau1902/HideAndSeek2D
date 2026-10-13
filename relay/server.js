// Máy chủ chuyển tiếp cho game "Trốn Tìm Hóa Trang".
// - Giữ danh sách phòng theo mã 6 ký tự.
// - Chủ phòng (peer 1) là "máy chủ" của trận; người vào chỉ nói chuyện với chủ phòng,
//   máy chủ này chỉ chuyển gói tin qua lại (không chạy luật chơi).
// - Không cần thư viện ngoài: WebSocket được viết tay bằng module có sẵn của Node.js.
//
// Chạy:  node server.js        (cổng lấy từ biến môi trường PORT, mặc định 8080)
//
// Giao thức:
//   Tin chữ (JSON):  {"t":"host","name":...}  -> {"t":"hosted","code":"K7F2QX","id":1}
//                    {"t":"join","code":"..."} -> {"t":"joined","id":N}   (chủ phòng nhận {"t":"peer_connected","id":N})
//                    {"t":"kick","id":N}       (chỉ chủ phòng)
//                    {"t":"error","msg":...}, {"t":"peer_disconnected","id":N}, {"t":"closed"}
//   Tin nhị phân:    gửi đi   [int32 đích][dữ liệu]   (đích: 0 = mọi người, N = một người, -N = mọi người trừ N)
//                    nhận về  [int32 nguồn][dữ liệu]

"use strict";
const http = require("http");
const crypto = require("crypto");

const PORT = parseInt(process.env.PORT || "8080", 10);
const CODE_CHARS = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
const CODE_LENGTH = 6;
const MAX_PEERS_PER_ROOM = 16;
const MAX_MESSAGE = 1 << 20; // 1 MB
const PING_INTERVAL_MS = 25000;

/** @type {Map<string, {code:string, host:Conn, peers:Map<number, Conn>, nextId:number}>} */
const rooms = new Map();
let connCounter = 0;

// ------------------------------------------------------------------ WebSocket tối giản

class Conn {
  constructor(socket) {
    this.socket = socket;
    this.id = 0;          // id trong phòng (1 = chủ phòng)
    this.room = null;
    this.buf = Buffer.alloc(0);
    this.fragments = [];
    this.fragOpcode = 0;
    this.closed = false;
    this.alive = true;
    this.tag = ++connCounter;
    socket.on("data", (d) => this.onData(d));
    socket.on("close", () => this.onClose());
    socket.on("error", () => this.onClose());
  }

  onData(chunk) {
    this.buf = Buffer.concat([this.buf, chunk]);
    for (;;) {
      if (this.buf.length < 2) return;
      const b0 = this.buf[0], b1 = this.buf[1];
      const fin = (b0 & 0x80) !== 0;
      const opcode = b0 & 0x0f;
      const masked = (b1 & 0x80) !== 0;
      let len = b1 & 0x7f;
      let off = 2;
      if (len === 126) {
        if (this.buf.length < 4) return;
        len = this.buf.readUInt16BE(2); off = 4;
      } else if (len === 127) {
        if (this.buf.length < 10) return;
        const big = this.buf.readBigUInt64BE(2);
        if (big > BigInt(MAX_MESSAGE)) return this.close(1009);
        len = Number(big); off = 10;
      }
      if (len > MAX_MESSAGE) return this.close(1009);
      const maskOff = off;
      if (masked) off += 4;
      if (this.buf.length < off + len) return;
      let payload = this.buf.subarray(off, off + len);
      if (masked) {
        const mask = this.buf.subarray(maskOff, maskOff + 4);
        payload = Buffer.from(payload);
        for (let i = 0; i < payload.length; i++) payload[i] ^= mask[i & 3];
      }
      this.buf = this.buf.subarray(off + len);

      if (opcode === 0x8) return this.close(1000);
      if (opcode === 0x9) { this.sendFrame(0xA, payload); continue; }   // ping -> pong
      if (opcode === 0xA) { this.alive = true; continue; }               // pong
      if (opcode === 0x0) {                                              // phần tiếp theo
        this.fragments.push(payload);
        if (fin) { const all = Buffer.concat(this.fragments); this.fragments = []; this.onMessage(this.fragOpcode, all); }
        continue;
      }
      if (!fin) { this.fragOpcode = opcode; this.fragments = [payload]; continue; }
      this.onMessage(opcode, payload);
    }
  }

  sendFrame(opcode, data) {
    if (this.closed) return;
    const len = data.length;
    let header;
    if (len < 126) { header = Buffer.from([0x80 | opcode, len]); }
    else if (len < 65536) { header = Buffer.alloc(4); header[0] = 0x80 | opcode; header[1] = 126; header.writeUInt16BE(len, 2); }
    else { header = Buffer.alloc(10); header[0] = 0x80 | opcode; header[1] = 127; header.writeBigUInt64BE(BigInt(len), 2); }
    this.socket.write(Buffer.concat([header, data]));
  }

  sendJSON(obj) { this.sendFrame(0x1, Buffer.from(JSON.stringify(obj), "utf8")); }
  sendBinary(buf) { this.sendFrame(0x2, buf); }

  close(code = 1000) {
    if (this.closed) return;
    const b = Buffer.alloc(2); b.writeUInt16BE(code, 0);
    try { this.sendFrame(0x8, b); } catch (e) {}
    this.closed = true;
    try { this.socket.end(); } catch (e) {}
    setTimeout(() => { try { this.socket.destroy(); } catch (e) {} }, 1000);
    this.onClose();
  }

  onClose() {
    if (this._cleaned) return;
    this._cleaned = true;
    this.closed = true;
    leaveRoom(this);
  }

  onMessage(opcode, data) {
    if (opcode === 0x1) {
      let msg;
      try { msg = JSON.parse(data.toString("utf8")); } catch (e) { return; }
      onControl(this, msg);
    } else if (opcode === 0x2) {
      onGamePacket(this, data);
    }
  }
}

// ------------------------------------------------------------------ Phòng

function makeCode() {
  for (;;) {
    let c = "";
    for (let i = 0; i < CODE_LENGTH; i++) c += CODE_CHARS[crypto.randomInt(CODE_CHARS.length)];
    if (!rooms.has(c)) return c;
  }
}

function onControl(conn, msg) {
  if (msg.t === "host" && !conn.room) {
    const code = makeCode();
    const room = { code, host: conn, peers: new Map(), nextId: 2 };
    rooms.set(code, room);
    conn.room = room; conn.id = 1;
    conn.sendJSON({ t: "hosted", code, id: 1 });
    log(`phòng ${code} được tạo (tổng ${rooms.size} phòng)`);
  } else if (msg.t === "join" && !conn.room) {
    const code = String(msg.code || "").toUpperCase();
    const room = rooms.get(code);
    if (!room) return conn.sendJSON({ t: "error", msg: `Không có phòng nào mang mã ${code}.` });
    if (room.peers.size + 1 >= MAX_PEERS_PER_ROOM) return conn.sendJSON({ t: "error", msg: "Phòng đã đầy." });
    const id = room.nextId++ ;
    conn.room = room; conn.id = id;
    room.peers.set(id, conn);
    conn.sendJSON({ t: "joined", id, code });
    room.host.sendJSON({ t: "peer_connected", id });
  } else if (msg.t === "kick" && conn.room && conn.id === 1) {
    const target = conn.room.peers.get(msg.id | 0);
    if (target) target.close(4000);
  }
}

function onGamePacket(conn, data) {
  const room = conn.room;
  if (!room || data.length < 4) return;
  const target = data.readInt32LE(0);
  const payload = data.subarray(4);
  const out = Buffer.alloc(4 + payload.length);
  out.writeInt32LE(conn.id, 0);
  payload.copy(out, 4);
  if (conn.id !== 1) {
    // Người vào chỉ gửi được cho chủ phòng; chủ phòng sẽ tự chuyển tiếp nếu cần.
    room.host.sendBinary(out);
    return;
  }
  if (target > 0) {
    const p = room.peers.get(target);
    if (p) p.sendBinary(out);
  } else {
    for (const [id, p] of room.peers) {
      if (target < 0 && id === -target) continue;
      p.sendBinary(out);
    }
  }
}

function leaveRoom(conn) {
  const room = conn.room;
  if (!room) return;
  conn.room = null;
  if (conn.id === 1) {
    rooms.delete(room.code);
    for (const p of room.peers.values()) { p.room = null; p.sendJSON({ t: "closed" }); p.close(1000); }
    log(`phòng ${room.code} đã đóng (còn ${rooms.size} phòng)`);
  } else {
    room.peers.delete(conn.id);
    room.host.sendJSON({ t: "peer_disconnected", id: conn.id });
  }
}

function log(s) { console.log(new Date().toISOString(), s); }

// ------------------------------------------------------------------ HTTP + nâng cấp WebSocket

const server = http.createServer((req, res) => {
  // Trang kiểm tra: Render dùng để biết máy chủ còn sống; mở trên trình duyệt cũng thấy.
  res.writeHead(200, { "Content-Type": "text/plain; charset=utf-8", "Access-Control-Allow-Origin": "*" });
  res.end(`Tron Tim relay OK - ${rooms.size} phong dang mo\n`);
});

server.on("upgrade", (req, socket) => {
  const key = req.headers["sec-websocket-key"];
  if (!key || (req.headers.upgrade || "").toLowerCase() !== "websocket") { socket.destroy(); return; }
  const accept = crypto.createHash("sha1").update(key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").digest("base64");
  const headers = [
    "HTTP/1.1 101 Switching Protocols",
    "Upgrade: websocket",
    "Connection: Upgrade",
    `Sec-WebSocket-Accept: ${accept}`,
  ];
  socket.write(headers.join("\r\n") + "\r\n\r\n");
  socket.setNoDelay(true);
  const conn = new Conn(socket);
  conns.add(conn);
  socket.on("close", () => conns.delete(conn));
});

const conns = new Set();
setInterval(() => {
  for (const c of conns) {
    if (!c.alive) { c.close(1001); continue; }
    c.alive = false;
    c.sendFrame(0x9, Buffer.alloc(0));
  }
}, PING_INTERVAL_MS);

server.listen(PORT, () => log(`relay đang chạy ở cổng ${PORT}`));
