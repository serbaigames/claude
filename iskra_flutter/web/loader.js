// Экран загрузки «Искры»: убирается, когда Flutter нарисовал игру,
// а если запуск сорвался — показывает причину и подсказку для настройки хостинга.
(function () {
  var box = document.getElementById('loading');
  if (!box) return;
  var errors = [];

  function started() {
    return document.querySelector('flutter-view, flt-glass-pane');
  }

  function hint(text) {
    if (/wasm-unsafe-eval|unsafe-eval|Content Security Policy/i.test(text)) {
      return 'Сервер запрещает WebAssembly заголовком Content-Security-Policy. ' +
        'Добавьте в script-src значение \'wasm-unsafe-eval\' (готовые настройки — в .htaccess и server/iskra-security.conf).';
    }
    if (/MIME type|application\/wasm/i.test(text)) {
      return 'Сервер отдаёт файлы .wasm с неверным типом. Нужен тип application/wasm ' +
        '(в .htaccess: AddType application/wasm .wasm; в nginx: types { application/wasm wasm; }).';
    }
    if (/404|Failed to fetch|NetworkError|Load failed/i.test(text)) {
      return 'Часть файлов игры не загрузилась. Проверьте, что на сервер выложено всё содержимое архива, включая папки canvaskit и assets.';
    }
    return '';
  }

  function fail(text) {
    if (started()) return;
    errors.push(String(text));
    var h = hint(errors.join(' '));
    box.innerHTML = '';
    var m = document.createElement('div');
    m.className = 'err';
    m.textContent = 'Игра не запустилась. ' + (h || 'Откройте консоль браузера (F12), там будет причина.');
    var d = document.createElement('div');
    d.style.cssText = 'font-size:12px;opacity:.7;max-width:560px;word-break:break-word';
    d.textContent = errors[0].slice(0, 300);
    box.appendChild(m);
    box.appendChild(d);
  }

  window.addEventListener('error', function (e) { fail(e.message || e.error || 'ошибка'); });
  window.addEventListener('unhandledrejection', function (e) { fail((e.reason && (e.reason.message || e.reason)) || 'ошибка'); });
  document.addEventListener('securitypolicyviolation', function (e) {
    fail('Content Security Policy: ' + e.violatedDirective + ' ' + (e.blockedURI || ''));
  });

  var obs = new MutationObserver(function () {
    if (started()) { obs.disconnect(); box.remove(); }
  });
  obs.observe(document.documentElement, { childList: true, subtree: true });

  setTimeout(function () {
    if (!started() && !errors.length) {
      box.querySelector('.msg').textContent = 'Загрузка идёт дольше обычного… Если экран не сменится, обновите страницу.';
    }
  }, 20000);
})();
