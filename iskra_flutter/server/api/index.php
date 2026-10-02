<?php
// «Искра» — API учётных записей и сохранений. Требуется PHP 8.0+ с расширением pdo_sqlite.
declare(strict_types=1);

$CFG = require __DIR__ . '/config.php';

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
header('X-Content-Type-Options: nosniff');

// Строки в UTF-8 (с запасным вариантом, если на хостинге нет mbstring)
function ulen(string $s): int { return function_exists('mb_strlen') ? mb_strlen($s, 'UTF-8') : (int)preg_match_all('/./us', $s); }
function ulow(string $s): string {
    if (function_exists('mb_strtolower')) return mb_strtolower($s, 'UTF-8');
    return strtolower(strtr($s, ['А'=>'а','Б'=>'б','В'=>'в','Г'=>'г','Д'=>'д','Е'=>'е','Ё'=>'ё','Ж'=>'ж','З'=>'з','И'=>'и','Й'=>'й','К'=>'к','Л'=>'л','М'=>'м','Н'=>'н','О'=>'о','П'=>'п','Р'=>'р','С'=>'с','Т'=>'т','У'=>'у','Ф'=>'ф','Х'=>'х','Ц'=>'ц','Ч'=>'ч','Ш'=>'ш','Щ'=>'щ','Ъ'=>'ъ','Ы'=>'ы','Ь'=>'ь','Э'=>'э','Ю'=>'ю','Я'=>'я']));
}

function out(int $code, array $data): void {
    http_response_code($code);
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}
function fail(int $code, string $msg, array $extra = []): void { out($code, ['error' => $msg] + $extra); }

function db(): PDO {
    static $pdo = null;
    global $CFG;
    if ($pdo) return $pdo;
    $dir = dirname($CFG['db_path']);
    if (!is_dir($dir) && !@mkdir($dir, 0700, true)) fail(500, 'Сервер не может создать папку для базы данных.');
    try {
        $pdo = new PDO('sqlite:' . $CFG['db_path'], null, null, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ]);
    } catch (Throwable $e) {
        fail(500, 'Сервер не может открыть базу данных.');
    }
    $pdo->exec('PRAGMA journal_mode = WAL; PRAGMA foreign_keys = ON; PRAGMA busy_timeout = 3000;');
    $pdo->exec('CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        login TEXT NOT NULL,
        lkey TEXT NOT NULL UNIQUE,
        pass TEXT NOT NULL,
        created INTEGER NOT NULL)');
    $pdo->exec('CREATE TABLE IF NOT EXISTS sessions (
        token TEXT PRIMARY KEY,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        expires INTEGER NOT NULL)');
    $pdo->exec('CREATE TABLE IF NOT EXISTS saves (
        user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
        data TEXT NOT NULL,
        saved INTEGER NOT NULL,
        updated INTEGER NOT NULL)');
    $pdo->exec('CREATE TABLE IF NOT EXISTS attempts (
        k TEXT NOT NULL,
        t INTEGER NOT NULL)');
    $pdo->exec('CREATE INDEX IF NOT EXISTS attempts_k ON attempts(k, t)');
    // Рейтинги: лучшие показатели игрока за всё время, пересчитываются при каждом сохранении
    $pdo->exec('CREATE TABLE IF NOT EXISTS stats (
        user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
        matter REAL NOT NULL DEFAULT 0,
        cells INTEGER NOT NULL DEFAULT 0,
        kills INTEGER NOT NULL DEFAULT 0,
        updated INTEGER NOT NULL)');
    foreach (['matter', 'cells', 'kills'] as $col) $pdo->exec("CREATE INDEX IF NOT EXISTS stats_$col ON stats($col DESC)");
    // Уборка: истёкшие сеансы и старые попытки входа
    if (random_int(1, 50) === 1) {
        $pdo->prepare('DELETE FROM sessions WHERE expires < ?')->execute([time()]);
        $pdo->prepare('DELETE FROM attempts WHERE t < ?')->execute([time() - 86400]);
    }
    return $pdo;
}

function body(): array {
    $raw = file_get_contents('php://input', false, null, 0, 4 * 1024 * 1024);
    $j = json_decode($raw ?: '', true);
    return is_array($j) ? $j : [];
}

function is_https(): bool {
    return (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off')
        || (($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') === 'https');
}

function cookie_path(): string {
    // Папка игры (на уровень выше /api/), чтобы cookie работала и в подпапке сайта
    $p = rtrim(str_replace('\\', '/', dirname(dirname($_SERVER['SCRIPT_NAME'] ?? '/api/index.php'))), '/');
    return $p . '/';
}

function set_session_cookie(string $value, int $expires): void {
    global $CFG;
    setcookie($CFG['cookie_name'], $value, [
        'expires' => $expires, 'path' => cookie_path(),
        'secure' => is_https(), 'httponly' => true, 'samesite' => 'Lax',
    ]);
}

function start_session(int $uid): void {
    global $CFG;
    $token = bin2hex(random_bytes(32));
    $exp = time() + $CFG['session_days'] * 86400;
    db()->prepare('INSERT INTO sessions (token, user_id, expires) VALUES (?, ?, ?)')
        ->execute([hash('sha256', $token), $uid, $exp]);
    set_session_cookie($token, $exp);
}

function current_user(): ?array {
    global $CFG;
    $t = $_COOKIE[$CFG['cookie_name']] ?? '';
    if (!is_string($t) || !preg_match('/^[0-9a-f]{64}$/', $t)) return null;
    $st = db()->prepare('SELECT u.id, u.login, u.pass, u.created FROM sessions s JOIN users u ON u.id = s.user_id
                         WHERE s.token = ? AND s.expires > ?');
    $st->execute([hash('sha256', $t), time()]);
    return $st->fetch() ?: null;
}

function require_user(): array {
    $u = current_user();
    if (!$u) fail(401, 'Войдите в учётную запись.');
    return $u;
}

function client_key(): string { return hash('sha256', 'ip:' . ($_SERVER['REMOTE_ADDR'] ?? '')); }

function too_many(string $k, int $limit, int $window): bool {
    $st = db()->prepare('SELECT COUNT(*) FROM attempts WHERE k = ? AND t > ?');
    $st->execute([$k, time() - $window]);
    return (int)$st->fetchColumn() >= $limit;
}
function note_attempt(string $k): void { db()->prepare('INSERT INTO attempts (k, t) VALUES (?, ?)')->execute([$k, time()]); }

function save_meta(int $uid): ?array {
    $st = db()->prepare('SELECT saved, updated FROM saves WHERE user_id = ?');
    $st->execute([$uid]);
    $r = $st->fetch();
    return $r ? ['saved' => (int)$r['saved'], 'updated' => (int)$r['updated']] : null;
}

// Очки за сущности: низшая 1, редкая 3, эпическая 10, легендарная 500
function kill_points($k): int {
    if (!is_array($k)) return 0;
    $w = ['low' => 1, 'rare' => 3, 'epic' => 10, 'legend' => 500];
    $p = 0;
    foreach ($w as $t => $v) $p += max(0, (int)($k[$t] ?? 0)) * $v;
    return $p;
}
function update_stats(int $uid, array $d): void {
    $matter = max(0.0, (float)($d['earned'] ?? 0));
    $cells = max(0, (int)($d['bestCells'] ?? 0));
    $kills = kill_points($d['kills'] ?? null);
    // Рейтинг хранит максимум: показатели не уменьшаются, даже если игрок загрузил старое сохранение
    db()->prepare('INSERT INTO stats (user_id, matter, cells, kills, updated) VALUES (?, CAST(? AS REAL), CAST(? AS INTEGER), CAST(? AS INTEGER), ?)
                   ON CONFLICT(user_id) DO UPDATE SET matter = MAX(matter, CAST(excluded.matter AS REAL)),
                   cells = MAX(cells, CAST(excluded.cells AS INTEGER)), kills = MAX(kills, CAST(excluded.kills AS INTEGER)),
                   updated = excluded.updated')
        ->execute([$uid, $matter, $cells, $kills, time()]);
}

function user_out(array $u): array { return ['login' => $u['login'], 'created' => (int)$u['created']]; }

// --- Маршрутизация ---
$a = $_GET['a'] ?? '';
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

// Изменяющие запросы принимаем только от самой игры (защита от подделки запросов с чужих сайтов)
if ($method === 'POST' && ($_SERVER['HTTP_X_ISKRA'] ?? '') !== '1') fail(403, 'Запрос отклонён.');

switch ("$method $a") {

case 'GET me': {
    $u = current_user();
    out(200, ['ok' => true, 'user' => $u ? user_out($u) : null, 'save' => $u ? save_meta((int)$u['id']) : null]);
}

case 'POST register': {
    $b = body();
    $login = trim((string)($b['login'] ?? ''));
    $pass = (string)($b['password'] ?? '');
    if (!preg_match('/^[\p{L}\p{N}_.\-]{3,24}$/u', $login))
        fail(422, 'Имя: от 3 до 24 символов — буквы, цифры, точка, дефис или подчёркивание.', ['field' => 'login']);
    if (ulen($pass) < $CFG['min_password'])
        fail(422, "Пароль должен быть не короче {$CFG['min_password']} символов.", ['field' => 'password']);
    if (ulen($pass) > 200) fail(422, 'Пароль слишком длинный.', ['field' => 'password']);
    $rk = 'reg:' . client_key();
    if (too_many($rk, $CFG['register_per_hour'], 3600)) fail(429, 'Слишком много регистраций с этого адреса. Попробуйте через час.');
    try {
        db()->prepare('INSERT INTO users (login, lkey, pass, created) VALUES (?, ?, ?, ?)')
            ->execute([$login, ulow($login), password_hash($pass, PASSWORD_DEFAULT), time()]);
    } catch (PDOException $e) {
        if ((string)$e->getCode() === '23000') fail(409, 'Это имя уже занято.', ['field' => 'login']);
        fail(500, 'Не удалось создать учётную запись.');
    }
    note_attempt($rk);
    $uid = (int)db()->lastInsertId();
    start_session($uid);
    out(200, ['ok' => true, 'user' => ['login' => $login, 'created' => time()], 'save' => null]);
}

case 'POST login': {
    $b = body();
    $login = trim((string)($b['login'] ?? ''));
    $pass = (string)($b['password'] ?? '');
    $k1 = 'login:' . client_key();
    $k2 = 'user:' . ulow($login);
    if (too_many($k1, $CFG['login_attempts'], $CFG['attempt_window']) || too_many($k2, $CFG['login_attempts'], $CFG['attempt_window']))
        fail(429, 'Слишком много неудачных попыток. Подождите 15 минут.');
    $st = db()->prepare('SELECT id, login, pass, created FROM users WHERE lkey = ?');
    $st->execute([ulow($login)]);
    $u = $st->fetch();
    if (!$u || !password_verify($pass, $u['pass'])) {
        note_attempt($k1); note_attempt($k2);
        fail(401, 'Неверное имя или пароль.');
    }
    if (password_needs_rehash($u['pass'], PASSWORD_DEFAULT))
        db()->prepare('UPDATE users SET pass = ? WHERE id = ?')->execute([password_hash($pass, PASSWORD_DEFAULT), $u['id']]);
    start_session((int)$u['id']);
    out(200, ['ok' => true, 'user' => user_out($u), 'save' => save_meta((int)$u['id'])]);
}

case 'POST logout': {
    $t = $_COOKIE[$CFG['cookie_name']] ?? '';
    if (is_string($t) && $t !== '') db()->prepare('DELETE FROM sessions WHERE token = ?')->execute([hash('sha256', $t)]);
    set_session_cookie('', time() - 3600);
    out(200, ['ok' => true]);
}

case 'GET save': {
    $u = require_user();
    $st = db()->prepare('SELECT data, saved, updated FROM saves WHERE user_id = ?');
    $st->execute([$u['id']]);
    $r = $st->fetch();
    out(200, ['ok' => true, 'save' => $r ? ['data' => $r['data'], 'saved' => (int)$r['saved'], 'updated' => (int)$r['updated']] : null]);
}

case 'POST save': {
    $u = require_user();
    $b = body();
    $data = $b['data'] ?? null;
    if (!is_string($data) || $data === '') fail(422, 'Нет данных для сохранения.');
    if (strlen($data) > $CFG['max_save_bytes']) fail(413, 'Сохранение слишком большое.');
    $parsed = json_decode($data, true);
    if (!is_array($parsed) || !is_array($parsed['cells'] ?? null) || !is_numeric($parsed['matter'] ?? null)) fail(422, 'Повреждённое сохранение.');
    $hasSpark = false;
    foreach ($parsed['cells'] as $c) if (is_array($c) && !empty($c['spark'])) { $hasSpark = true; break; }
    if (!$hasSpark) fail(422, 'Повреждённое сохранение.');
    $saved = (int)($b['saved'] ?? 0);
    $base = isset($b['base']) ? (int)$b['base'] : null;
    $meta = save_meta((int)$u['id']);
    // Если с момента последней синхронизации сервер получил сохранение с другого устройства — не затираем молча
    if ($meta && empty($b['force']) && $base !== null && $meta['updated'] > $base)
        fail(409, 'На сервере есть более новое сохранение с другого устройства.', ['save' => $meta]);
    $now = (int)round(microtime(true) * 1000);
    db()->prepare('INSERT INTO saves (user_id, data, saved, updated) VALUES (?, ?, ?, ?)
                   ON CONFLICT(user_id) DO UPDATE SET data = excluded.data, saved = excluded.saved, updated = excluded.updated')
        ->execute([$u['id'], $data, $saved, $now]);
    update_stats((int)$u['id'], $parsed);
    out(200, ['ok' => true, 'save' => ['saved' => $saved, 'updated' => $now]]);
}

case 'GET top': {
    $by = $_GET['by'] ?? 'matter';
    if (!in_array($by, ['matter', 'cells', 'kills'], true)) fail(422, 'Неизвестный рейтинг.');
    // limit: сколько мест отдать (по умолчанию 10, как ждёт веб-версия; приложение просит 100)
    $limit = max(1, min(100, (int)($_GET['limit'] ?? 10)));
    $st = db()->query("SELECT u.login, s.$by AS v FROM stats s JOIN users u ON u.id = s.user_id
                       WHERE s.$by > 0 ORDER BY s.$by DESC, s.updated ASC LIMIT $limit");
    $list = array_map(fn($r) => ['login' => $r['login'], 'value' => (float)$r['v']], $st->fetchAll());
    $total = (int)db()->query("SELECT COUNT(*) FROM stats WHERE $by > 0")->fetchColumn();
    $me = null;
    $u = current_user();
    if ($u) {
        $q = db()->prepare("SELECT $by FROM stats WHERE user_id = ?");
        $q->execute([$u['id']]);
        $v = $q->fetchColumn();
        if ($v !== false && (float)$v > 0) {
            $r = db()->prepare("SELECT COUNT(*) FROM stats WHERE $by > ?");
            $r->execute([$v]);
            $me = ['login' => $u['login'], 'value' => (float)$v, 'rank' => (int)$r->fetchColumn() + 1];
        }
    }
    header('Cache-Control: no-store');
    out(200, ['ok' => true, 'by' => $by, 'list' => $list, 'me' => $me, 'total' => $total]);
}

case 'POST password': {
    $u = require_user();
    $b = body();
    if (!password_verify((string)($b['old'] ?? ''), $u['pass'])) fail(401, 'Текущий пароль указан неверно.', ['field' => 'old']);
    $new = (string)($b['new'] ?? '');
    if (ulen($new) < $CFG['min_password']) fail(422, "Новый пароль должен быть не короче {$CFG['min_password']} символов.", ['field' => 'new']);
    db()->prepare('UPDATE users SET pass = ? WHERE id = ?')->execute([password_hash($new, PASSWORD_DEFAULT), $u['id']]);
    // Выходим на всех остальных устройствах
    db()->prepare('DELETE FROM sessions WHERE user_id = ?')->execute([$u['id']]);
    start_session((int)$u['id']);
    out(200, ['ok' => true]);
}

case 'POST delete': {
    $u = require_user();
    $b = body();
    if (!password_verify((string)($b['password'] ?? ''), $u['pass'])) fail(401, 'Пароль указан неверно.', ['field' => 'password']);
    db()->prepare('DELETE FROM users WHERE id = ?')->execute([$u['id']]); // сеансы и сохранение удалятся каскадно
    set_session_cookie('', time() - 3600);
    out(200, ['ok' => true]);
}

default:
    fail(404, 'Неизвестный запрос.');
}
