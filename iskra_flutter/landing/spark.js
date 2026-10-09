// Анимация искры для первого экрана: звезда с грануляцией, протуберанцами и короной,
// орбитальные ядра со шлейфами, искры-угольки, сетка шестигранников с волной энергии и
// сущности тьмы по краю. Всё рисуется на canvas без библиотек; встаёт на паузу, когда не видно.
(() => {
  const cv = document.getElementById('spark');
  if (!cv) return;
  const ctx = cv.getContext('2d');
  const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const TAU = Math.PI * 2;
  let W = 0, H = 0, dpr = 1, cx = 0, cy = 0, R = 60, mobile = false;
  let bg = null, gran = null, hexes = [], stars = [], embers = [], cores = [], proms = [];
  const rnd = (a, b) => a + Math.random() * (b - a);
  // гладкий «шум» из суммы синусов — для мерцания лучей и дыхания свечения
  const wob = (x, s = 0) => (Math.sin(x * 1.7 + s) + Math.sin(x * 2.9 + s * 1.3) * 0.6 + Math.sin(x * 5.3 + s * 2.1) * 0.3) / 1.9;

  function resize() {
    const r = cv.getBoundingClientRect();
    W = Math.max(1, r.width); H = Math.max(1, r.height);
    mobile = W < 700;
    dpr = Math.min(window.devicePixelRatio || 1, mobile ? 1.75 : 2);
    cv.width = Math.round(W * dpr); cv.height = Math.round(H * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    R = Math.max(42, Math.min(130, Math.min(W, H) * (mobile ? 0.13 : 0.11)));
    cx = W / 2; cy = H * (mobile ? 0.29 : 0.3);
    buildBackground(); buildGranulation(); buildHexes(); buildStars(); buildCores(); buildProms();
    embers = [];
  }

  /* ---------- фон: космос, туманности и неподвижные звёзды (рисуется один раз) ---------- */
  function buildBackground() {
    bg = document.createElement('canvas');
    bg.width = cv.width; bg.height = cv.height;
    const g = bg.getContext('2d');
    g.setTransform(dpr, 0, 0, dpr, 0, 0);
    const base = g.createLinearGradient(0, 0, 0, H);
    base.addColorStop(0, '#07050f'); base.addColorStop(0.55, '#0e0a1d'); base.addColorStop(1, '#141026');
    g.fillStyle = base; g.fillRect(0, 0, W, H);
    const neb = [['#5b3aa8', 0.16], ['#2d5aa0', 0.12], ['#a83a6e', 0.09], ['#3a2a7a', 0.14]];
    for (let i = 0; i < 9; i++) {
      const [c, a] = neb[i % neb.length];
      const x = rnd(0, W), y = rnd(0, H * 0.9), r = rnd(Math.min(W, H) * 0.25, Math.max(W, H) * 0.55);
      const rg = g.createRadialGradient(x, y, 0, x, y, r);
      rg.addColorStop(0, hexA(c, a)); rg.addColorStop(1, hexA(c, 0));
      g.fillStyle = rg; g.fillRect(0, 0, W, H);
    }
    for (let i = 0, n = Math.round(W * H / 2200); i < n; i++) {
      const x = rnd(0, W), y = rnd(0, H), s = Math.random() ** 3 * 1.3 + 0.25;
      g.fillStyle = `rgba(${200 + rnd(0, 55) | 0},${190 + rnd(0, 60) | 0},255,${rnd(0.25, 0.85)})`;
      g.beginPath(); g.arc(x, y, s, 0, TAU); g.fill();
    }
  }
  function hexA(hex, a) {
    const n = parseInt(hex.slice(1), 16);
    return `rgba(${n >> 16},${(n >> 8) & 255},${n & 255},${a})`;
  }

  /* ---------- грануляция поверхности: ячейки конвекции, вращаются вместе со звездой ---------- */
  function buildGranulation() {
    const s = Math.ceil(R * 2 * dpr);
    gran = document.createElement('canvas');
    gran.width = gran.height = s;
    const g = gran.getContext('2d');
    for (let i = 0; i < 520; i++) {
      const x = rnd(0, s), y = rnd(0, s), r = rnd(s * 0.02, s * 0.075), hot = Math.random() < 0.55;
      const rg = g.createRadialGradient(x, y, 0, x, y, r);
      rg.addColorStop(0, hot ? 'rgba(255,250,215,0.55)' : 'rgba(150,50,0,0.45)');
      rg.addColorStop(1, hot ? 'rgba(255,240,200,0)' : 'rgba(150,50,0,0)');
      g.fillStyle = rg; g.beginPath(); g.arc(x, y, r, 0, TAU); g.fill();
    }
  }

  /* ---------- сетка шестигранников: свои клетки у искры, тьма по краю ---------- */
  function buildHexes() {
    hexes = [];
    const size = R * 1.05, rings = mobile ? 4 : 5;
    for (let q = -rings; q <= rings; q++) {
      for (let r = -rings; r <= rings; r++) {
        const d = (Math.abs(q) + Math.abs(r) + Math.abs(q + r)) / 2;
        if (d > rings || d === 0) continue;
        const x = cx + size * Math.sqrt(3) * (q + r / 2), y = cy + size * 1.5 * r;
        hexes.push({ x, y, d, own: d <= 1 || (d === 2 && Math.random() < 0.45), dark: d >= rings - 1 && Math.random() < 0.28, ph: rnd(0, TAU), size });
      }
    }
  }
  function hexPath(x, y, s) {
    ctx.beginPath();
    for (let i = 0; i < 6; i++) {
      const a = Math.PI / 6 + i * Math.PI / 3;
      const px = x + s * Math.cos(a), py = y + s * Math.sin(a);
      i ? ctx.lineTo(px, py) : ctx.moveTo(px, py);
    }
    ctx.closePath();
  }

  function buildStars() {
    stars = Array.from({ length: mobile ? 40 : 80 }, () => ({ x: rnd(0, W), y: rnd(0, H), s: rnd(0.6, 1.8), ph: rnd(0, TAU), sp: rnd(0.6, 2.2) }));
  }

  /* ---------- орбитальные ядра искры ---------- */
  function buildCores() {
    const cols = ['#ffd27a', '#7cc8ff', '#c7a6ff'];
    cores = cols.map((c, i) => ({
      c, a: rnd(0, TAU), rx: R * (1.9 + i * 0.55), tilt: -0.35 + i * 0.32, flat: 0.3 + i * 0.05,
      sp: (0.55 - i * 0.12) * (i % 2 ? -1 : 1), r: R * (0.11 - i * 0.015), trail: [],
    }));
  }

  /* ---------- протуберанцы: петли плазмы над поверхностью ---------- */
  function newProm(t) {
    return { a: rnd(0, TAU), span: rnd(0.18, 0.42), h: rnd(0.45, 1.15), born: t, life: rnd(4, 9), w: rnd(0.8, 1.6) };
  }
  function buildProms() { proms = Array.from({ length: mobile ? 5 : 7 }, () => { const p = newProm(0); p.born = -rnd(0, p.life); return p; }); }

  /* ---------- кадр ---------- */
  let last = 0, t0 = performance.now();
  function frame(now) {
    const t = (now - t0) / 1000, dt = Math.min(0.05, (now - last) / 1000 || 0.016);
    last = now;
    ctx.globalCompositeOperation = 'source-over';
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.drawImage(bg, 0, 0);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    const breathe = 1 + 0.04 * Math.sin(t * 1.3) + 0.02 * wob(t * 0.7);

    // мерцающие звёзды
    for (const s of stars) {
      const a = 0.35 + 0.65 * (0.5 + 0.5 * Math.sin(t * s.sp + s.ph));
      ctx.fillStyle = `rgba(230,225,255,${a})`;
      ctx.beginPath(); ctx.arc(s.x, s.y, s.s, 0, TAU); ctx.fill();
    }

    drawHexes(t);

    // большое свечение вокруг искры
    ctx.globalCompositeOperation = 'lighter';
    radial(cx, cy, R * 7 * breathe, [[0, 'rgba(255,170,60,0.22)'], [0.25, 'rgba(242,140,40,0.10)'], [1, 'rgba(242,120,40,0)']]);
    radial(cx, cy, R * 2.6 * breathe, [[0, 'rgba(255,220,140,0.55)'], [0.5, 'rgba(255,170,70,0.18)'], [1, 'rgba(255,150,50,0)']]);

    drawCorona(t);
    drawCores(t, dt, false);
    drawProms(t);
    drawBody(t);
    drawCores(t, dt, true);
    drawEmbers(t, dt);
    drawFlare(t, breathe);
    ctx.globalCompositeOperation = 'source-over';
  }

  function radial(x, y, r, stops) {
    const g = ctx.createRadialGradient(x, y, 0, x, y, r);
    for (const [o, c] of stops) g.addColorStop(o, c);
    ctx.fillStyle = g;
    ctx.fillRect(x - r, y - r, r * 2, r * 2);
  }

  function drawHexes(t) {
    const wave = ((t * 0.32) % 1) * (mobile ? 5 : 6); // волна энергии бежит от искры
    ctx.lineWidth = 1.2;
    for (const h of hexes) {
      const fade = Math.max(0, 1 - h.d / ((mobile ? 4 : 5) + 0.6));
      const pulse = Math.exp(-((h.d - wave) ** 2) * 2.2);
      if (h.own) {
        ctx.globalCompositeOperation = 'lighter';
        hexPath(h.x, h.y, h.size * 0.94);
        ctx.fillStyle = `rgba(242,180,65,${0.035 + 0.06 * pulse})`;
        ctx.fill();
        ctx.strokeStyle = `rgba(255,200,110,${0.22 * fade + 0.35 * pulse})`;
        ctx.stroke();
        // узел-колония в центре своей клетки
        radial(h.x, h.y, h.size * 0.28, [[0, `rgba(255,220,150,${0.35 + 0.3 * pulse})`], [1, 'rgba(255,200,120,0)']]);
      } else {
        ctx.globalCompositeOperation = 'source-over';
        hexPath(h.x, h.y, h.size * 0.94);
        ctx.strokeStyle = `rgba(150,130,210,${0.10 * fade + 0.18 * pulse})`;
        ctx.stroke();
      }
      if (h.dark) drawEntity(h, t, fade);
    }
    ctx.globalCompositeOperation = 'source-over';
  }

  // сущность тьмы: маленькая чёрная дыра с аккреционным кольцом
  function drawEntity(h, t, fade) {
    const r = h.size * 0.22;
    ctx.save();
    ctx.translate(h.x, h.y);
    ctx.globalCompositeOperation = 'lighter';
    ctx.rotate(Math.sin(t * 0.4 + h.ph) * 0.2);
    ctx.scale(1, 0.38);
    ctx.strokeStyle = `rgba(200,140,255,${0.5 * fade + 0.15})`;
    ctx.lineWidth = r * 0.5;
    ctx.beginPath(); ctx.arc(0, 0, r * 1.5, 0, TAU); ctx.stroke();
    ctx.restore();
    ctx.globalCompositeOperation = 'source-over';
    ctx.fillStyle = '#05030a';
    ctx.beginPath(); ctx.arc(h.x, h.y, r, 0, TAU); ctx.fill();
    ctx.strokeStyle = `rgba(239,107,144,${0.55 * fade})`;
    ctx.lineWidth = 1;
    ctx.stroke();
  }

  function drawCorona(t) {
    const n = mobile ? 48 : 72;
    for (let i = 0; i < n; i++) {
      const a = (i / n) * TAU + t * 0.03;
      const len = R * (0.55 + 0.9 * Math.max(0, wob(t * 0.6 + i * 0.9, i))) * (i % 3 ? 1 : 1.5);
      const x0 = cx + Math.cos(a) * R * 0.95, y0 = cy + Math.sin(a) * R * 0.95;
      const x1 = cx + Math.cos(a) * (R + len), y1 = cy + Math.sin(a) * (R + len);
      const g = ctx.createLinearGradient(x0, y0, x1, y1);
      g.addColorStop(0, 'rgba(255,215,140,0.32)'); g.addColorStop(1, 'rgba(255,160,60,0)');
      ctx.strokeStyle = g;
      ctx.lineWidth = i % 3 ? 1.2 : 2.2;
      ctx.beginPath(); ctx.moveTo(x0, y0); ctx.lineTo(x1, y1); ctx.stroke();
    }
  }

  function drawProms(t) {
    ctx.lineCap = 'round';
    for (let i = 0; i < proms.length; i++) {
      let p = proms[i];
      let k = (t - p.born) / p.life;
      if (k >= 1) { p = proms[i] = newProm(t); k = 0; }
      const grow = Math.sin(Math.PI * Math.min(1, k * 1.15)); // поднимается и опадает
      const a0 = p.a - p.span, a1 = p.a + p.span, h = R * p.h * grow;
      const x0 = cx + Math.cos(a0) * R * 0.96, y0 = cy + Math.sin(a0) * R * 0.96;
      const x1 = cx + Math.cos(a1) * R * 0.96, y1 = cy + Math.sin(a1) * R * 0.96;
      const tw = Math.sin(t * 0.8 + i) * 0.12;
      const qx = cx + Math.cos(p.a + tw) * (R + h * 1.7), qy = cy + Math.sin(p.a + tw) * (R + h * 1.7);
      const alpha = Math.min(1, grow * 1.4);
      // три прохода: широкое красное гало, оранжевое тело, горячая жила
      for (const [w, c] of [[9, `rgba(255,70,30,${0.10 * alpha})`], [4.5, `rgba(255,130,40,${0.32 * alpha})`], [1.6, `rgba(255,230,160,${0.75 * alpha})`]]) {
        ctx.strokeStyle = c; ctx.lineWidth = w * p.w * (R / 80);
        ctx.beginPath(); ctx.moveTo(x0, y0); ctx.quadraticCurveTo(qx, qy, x1, y1); ctx.stroke();
      }
      // сгустки плазмы стекают по петле
      for (let j = 0; j < 3; j++) {
        const u = ((t * 0.35 + j / 3 + i * 0.17) % 1);
        const bx = (1 - u) ** 2 * x0 + 2 * (1 - u) * u * qx + u * u * x1;
        const by = (1 - u) ** 2 * y0 + 2 * (1 - u) * u * qy + u * u * y1;
        radial(bx, by, 5 * (R / 80), [[0, `rgba(255,240,190,${0.8 * alpha})`], [1, 'rgba(255,150,60,0)']]);
      }
    }
  }

  function drawBody(t) {
    ctx.globalCompositeOperation = 'source-over';
    // тело звезды
    const g = ctx.createRadialGradient(cx - R * 0.18, cy - R * 0.2, R * 0.05, cx, cy, R);
    g.addColorStop(0, '#fffdf0'); g.addColorStop(0.35, '#ffe9a8'); g.addColorStop(0.7, '#ffbf4d'); g.addColorStop(1, '#f07a22');
    ctx.fillStyle = g;
    ctx.beginPath(); ctx.arc(cx, cy, R, 0, TAU); ctx.fill();
    // грануляция, медленно вращается
    ctx.save();
    ctx.beginPath(); ctx.arc(cx, cy, R, 0, TAU); ctx.clip();
    ctx.translate(cx, cy);
    ctx.globalCompositeOperation = 'soft-light';
    for (const [rot, sc, al] of [[t * 0.05, 1.15, 0.9], [-t * 0.032 + 1, 1.4, 0.6]]) {
      ctx.save(); ctx.rotate(rot); ctx.scale(sc, sc); ctx.globalAlpha = al;
      ctx.drawImage(gran, -R, -R, R * 2, R * 2);
      ctx.restore();
    }
    ctx.restore();
    // потемнение к краю диска
    ctx.globalCompositeOperation = 'source-over';
    radial(cx, cy, R, [[0.55, 'rgba(160,50,0,0)'], [0.92, 'rgba(160,50,0,0.28)'], [0.995, 'rgba(120,30,0,0.55)'], [1, 'rgba(120,30,0,0)']]);
    // горячее ядро мерцает
    ctx.globalCompositeOperation = 'lighter';
    radial(cx, cy, R * (0.55 + 0.05 * wob(t * 3)), [[0, 'rgba(255,255,240,0.7)'], [1, 'rgba(255,240,200,0)']]);
    // тонкий ободок
    ctx.strokeStyle = 'rgba(255,230,170,0.6)';
    ctx.lineWidth = 1.2;
    ctx.beginPath(); ctx.arc(cx, cy, R * 1.005, 0, TAU); ctx.stroke();
  }

  function drawCores(t, dt, front) {
    for (const c of cores) {
      if (!front) { c.a += c.sp * dt; }
      const ox = Math.cos(c.a) * c.rx, oz = Math.sin(c.a);
      const oy = oz * c.rx * c.flat;
      const x = cx + ox * Math.cos(c.tilt) - oy * Math.sin(c.tilt);
      const y = cy + ox * Math.sin(c.tilt) + oy * Math.cos(c.tilt);
      if (!front) {
        c.trail.push([x, y, oz]);
        if (c.trail.length > 28) c.trail.shift();
      }
      if ((oz > 0) !== front) continue; // за звездой — до неё, перед — после
      ctx.globalCompositeOperation = 'lighter';
      // шлейф
      for (let i = 1; i < c.trail.length; i++) {
        const [px, py, pz] = c.trail[i - 1], [qx, qy] = c.trail[i];
        if ((pz > 0) !== front) continue;
        ctx.strokeStyle = hexA(c.c, (i / c.trail.length) * 0.35);
        ctx.lineWidth = c.r * 0.9 * (i / c.trail.length);
        ctx.beginPath(); ctx.moveTo(px, py); ctx.lineTo(qx, qy); ctx.stroke();
      }
      const s = front ? 1 : 0.78;
      radial(x, y, c.r * 5 * s, [[0, hexA(c.c, 0.5)], [1, hexA(c.c, 0)]]);
      radial(x, y, c.r * 1.3 * s, [[0, '#ffffff'], [0.5, hexA(c.c, 0.95)], [1, hexA(c.c, 0)]]);
    }
  }

  function drawEmbers(t, dt) {
    const max = mobile ? 70 : 150;
    while (embers.length < max && Math.random() < 0.9) {
      const a = rnd(0, TAU);
      embers.push({ x: cx + Math.cos(a) * R, y: cy + Math.sin(a) * R, vx: Math.cos(a) * rnd(12, 55), vy: Math.sin(a) * rnd(12, 55),
        life: rnd(1.6, 4.5), age: 0, s: rnd(0.7, 2.2), curl: rnd(-0.9, 0.9) });
      if (embers.length >= max) break;
    }
    ctx.globalCompositeOperation = 'lighter';
    for (let i = embers.length - 1; i >= 0; i--) {
      const e = embers[i];
      e.age += dt;
      if (e.age > e.life) { embers.splice(i, 1); continue; }
      // лёгкий завиток и торможение
      const c = Math.cos(e.curl * dt), s = Math.sin(e.curl * dt);
      [e.vx, e.vy] = [(e.vx * c - e.vy * s) * (1 - 0.25 * dt), (e.vx * s + e.vy * c) * (1 - 0.25 * dt)];
      e.x += e.vx * dt; e.y += e.vy * dt;
      const k = 1 - e.age / e.life;
      const col = k > 0.6 ? '255,236,180' : k > 0.3 ? '255,170,70' : '240,90,50';
      ctx.fillStyle = `rgba(${col},${k * 0.9})`;
      ctx.beginPath(); ctx.arc(e.x, e.y, e.s * (0.6 + k * 0.6), 0, TAU); ctx.fill();
    }
  }

  // анаморфный блик: тонкая горизонтальная полоса света через звезду
  function drawFlare(t, breathe) {
    ctx.globalCompositeOperation = 'lighter';
    ctx.save();
    ctx.translate(cx, cy);
    ctx.scale(1, 0.035);
    const r = Math.min(W * 0.55, R * 9) * breathe;
    const g = ctx.createRadialGradient(0, 0, 0, 0, 0, r);
    g.addColorStop(0, 'rgba(255,230,180,0.55)'); g.addColorStop(0.3, 'rgba(255,190,110,0.18)'); g.addColorStop(1, 'rgba(255,170,90,0)');
    ctx.fillStyle = g;
    ctx.fillRect(-r, -r, r * 2, r * 2);
    ctx.restore();
    // кольцо-призрак блика
    ctx.strokeStyle = `rgba(160,180,255,${0.05 + 0.03 * Math.sin(t)})`;
    ctx.lineWidth = 2;
    ctx.beginPath(); ctx.arc(cx + R * 2.6, cy + R * 0.35, R * 0.55, 0, TAU); ctx.stroke();
  }

  /* ---------- цикл: только когда первый экран виден и вкладка активна ---------- */
  let visible = true, raf = 0;
  const loop = (now) => { raf = 0; frame(now); schedule(); };
  const schedule = () => { if (!raf && visible && !document.hidden && !reduce) raf = requestAnimationFrame(loop); };
  new IntersectionObserver(([e]) => { visible = e.isIntersecting; schedule(); }).observe(cv);
  document.addEventListener('visibilitychange', schedule);
  let rt = 0;
  addEventListener('resize', () => { clearTimeout(rt); rt = setTimeout(() => { resize(); if (reduce) frame(performance.now()); }, 120); });
  resize();
  if (reduce) {
    // без движения: один кадр с уже разгоревшимися эффектами
    for (let i = 0; i < 90; i++) frame(t0 + i * 33);
  } else schedule();
})();
