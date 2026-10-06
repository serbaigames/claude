// Лендинг «Искры»: выпуски (releases.json собирается из lib/version.dart), ссылки на сборки GitHub,
// рейтинги с сервера учётных записей.
(() => {
  const API = 'https://api.iskraplay.ru/api/iskra/';
  const GH = 'https://github.com/serbaigames/claude/releases';
  const RUSTORE = 'https://www.rustore.ru/catalog/app/games.serbai.iskra';

  const $ = (s, el = document) => el.querySelector(s);
  const esc = (t) => String(t).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const newer = (a, b) => { // a >= b для версий вида 0.3.0
    const x = a.split('.').map(Number), y = b.split('.').map(Number);
    for (let i = 0; i < 3; i++) if ((x[i] || 0) !== (y[i] || 0)) return (x[i] || 0) > (y[i] || 0);
    return true;
  };
  // Файлы выпуска: Windows собирается начиная с 0.3.0; iOS на сайте не раздаётся (в разработке)
  const files = (v) => {
    const base = `${GH}/download/iskra-v${v}/`;
    const f = { apk: ['Android', `iskra-${v}.apk`] };
    if (newer(v, '0.3.0')) {
      f.win = ['Windows', `iskra-windows-${v}.zip`];
    }
    for (const k in f) f[k] = [f[k][0], base + f[k][1]];
    return f;
  };
  // Android с 0.6.0 — в RuStore (APK подписан ключом магазина), раньше — APK с GitHub
  const fileLinks = (v) => {
    const f = files(v);
    if (newer(v, '0.6.0')) f.apk = ['RuStore', RUSTORE];
    return `<div class="files">${['apk', 'win'].filter((k) => f[k])
      .map((k) => `<a href="${f[k][1]}">${f[k][0]}</a>`).join('')}<a href="${GH}/tag/iskra-v${v}">Страница выпуска</a></div>`;
  };

  async function releases() {
    let data;
    try {
      data = await (await fetch('releases.json', { cache: 'no-cache' })).json();
    } catch (_) {
      $('#release-current').innerHTML = `<p class="muted">Список выпусков — на <a href="${GH}">GitHub</a>.</p>`;
      return;
    }
    const cur = data.releases[0];
    document.querySelectorAll('[data-ver]').forEach((el) => (el.textContent = data.version));
    const f = files(data.version);
    document.querySelectorAll('[data-dl]').forEach((a) => {
      const x = f[a.dataset.dl];
      if (x) a.href = x[1];
      else a.setAttribute('aria-disabled', 'true');
    });
    const list = (r) => `<ul>${r.changes.map((c) => `<li>${esc(c)}</li>`).join('')}</ul>`;
    $('#release-current').innerHTML = `
      <article class="card rel cur">
        <div class="rel-head"><h3>Версия ${esc(cur.version)}</h3><span class="badge">текущая</span><span class="date">${esc(cur.date)}</span></div>
        ${list(cur)}${fileLinks(cur.version)}
      </article>`;
    $('#release-old').innerHTML = data.releases.slice(1).map((r) => `
      <details class="card rel">
        <summary><h3>Версия ${esc(r.version)}</h3><span class="date">${esc(r.date)}</span></summary>
        <div class="body">${list(r)}${fileLinks(r.version)}</div>
      </details>`).join('');
  }

  // числа как в игре: с 10 000 — в тысячах, с миллиона — в миллионах, запятая вместо точки
  const fmt = (n) => {
    const a = Math.abs(n), s = n < 0 ? '−' : '';
    if (a >= 1e6) return s + (a / 1e6).toFixed(2).replace('.', ',') + 'M';
    if (a >= 1e4) return s + (a / 1e3).toFixed(1).replace('.', ',') + 'k';
    return s + Math.floor(a);
  };
  const hints = {
    matter: 'Материя, добытая за всё время',
    cells: 'Больше всего клеток одновременно',
    kills: 'Очки за сущности: низшая 1, редкая 3, эпическая 10, легендарная 500',
  };
  let topReq = 0;
  async function top(by) {
    const req = ++topReq, box = $('#top-table');
    $('#top-hint').textContent = hints[by];
    box.innerHTML = '<p class="muted">Загрузка…</p>';
    try {
      const r = await fetch(`${API}top?by=${by}&limit=10`);
      const j = await r.json();
      if (req !== topReq) return;
      if (!j.ok) throw new Error(j.error || 'ошибка');
      box.innerHTML = j.list.length
        ? j.list.map((x, i) => `<div class="row"><span class="pl ${i < 3 ? 'm' + (i + 1) : ''}">${i < 3 ? ['🥇', '🥈', '🥉'][i] : i + 1}</span>
            <span class="nm">${esc(x.login)}</span><span class="vl">${fmt(x.value)}</span></div>`).join('')
          + (j.total > j.list.length ? `<p class="sub small" style="text-align:center">Всего в рейтинге: ${j.total}. Полный список — в игре.</p>` : '')
        : '<p class="muted">Пока никого нет — станьте первым!</p>';
    } catch (_) {
      if (req === topReq) box.innerHTML = '<p class="muted">Рейтинги сейчас недоступны. Загляните позже или откройте их в игре.</p>';
    }
  }
  document.querySelectorAll('.tabs button').forEach((b) => b.addEventListener('click', () => {
    document.querySelectorAll('.tabs button').forEach((x) => x.setAttribute('aria-selected', String(x === b)));
    top(b.dataset.by);
  }));

  $('#year').textContent = new Date().getFullYear();
  releases();
  top('matter');
})();
