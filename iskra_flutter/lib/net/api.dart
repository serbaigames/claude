// Клиент сервера учётных записей веб-версии (api/index.php): вход, сохранения в облаке, рейтинги.
// Сервер не меняется. Сеанс держится в cookie iskra_sid; все POST-запросы несут заголовок X-Iskra: 1,
// иначе сервер их отклоняет (защита от подделки запросов с чужих сайтов).
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiError implements Exception {
  final int status;
  final String message;
  final Map<String, dynamic>? data;

  /// true — ответ не от сервера «Искры» (нет PHP, нет сети): учётные записи просто недоступны
  final bool noApi;
  ApiError(this.status, this.message, {this.data, this.noApi = false});

  /// Поле формы, к которому относится ошибка (login, password, old, new)
  String? get field => data?['field'] as String?;

  @override
  String toString() => message;
}

class AccountUser {
  final String login;
  final int created;
  const AccountUser(this.login, this.created);
  factory AccountUser.fromJson(Map<String, dynamic> j) => AccountUser('${j['login']}', (j['created'] as num?)?.toInt() ?? 0);
}

/// Метка сохранения на сервере: saved — время сохранения в игре, updated — время записи на сервере (мс)
class SaveMeta {
  final int saved, updated;
  const SaveMeta(this.saved, this.updated);
  static SaveMeta? fromJson(Object? j) =>
      j is Map ? SaveMeta((j['saved'] as num?)?.toInt() ?? 0, (j['updated'] as num?)?.toInt() ?? 0) : null;
}

class ServerSave extends SaveMeta {
  final String data;
  const ServerSave(this.data, super.saved, super.updated);
}

class TopEntry {
  final String login;
  final double value;
  final int? rank;
  const TopEntry(this.login, this.value, [this.rank]);
}

class TopTable {
  final String by;
  final List<TopEntry> list;
  final TopEntry? me;
  final int total;
  const TopTable(this.by, this.list, this.me, this.total);
}

class IskraApi {
  /// [base] — адрес сайта с игрой, например https://example.com/iskra/ (рядом лежит папка api/).
  /// [manageCookies] — хранить cookie сеанса самим (Android, iOS). В браузере cookie держит сам браузер.
  IskraApi(Uri base, {http.Client? client, this.manageCookies = true, this.session, this.onSession})
    : endpoint = base.resolve('api/index.php'),
      _client = client ?? http.Client();

  final Uri endpoint;
  final http.Client _client;
  final bool manageCookies;

  /// Значение cookie iskra_sid; сохраняйте его между запусками через [onSession]
  String? session;
  void Function(String? session)? onSession;

  static const cookieName = 'iskra_sid';

  Future<Map<String, dynamic>> _call(String a, {Map<String, dynamic>? body, Map<String, String>? query}) async {
    final uri = endpoint.replace(queryParameters: {'a': a, ...?query});
    final headers = <String, String>{};
    if (body != null) {
      headers['Content-Type'] = 'application/json';
      headers['X-Iskra'] = '1';
    }
    if (manageCookies && session != null) headers['Cookie'] = '$cookieName=$session';
    http.Response r;
    try {
      r = body == null
          ? await _client.get(uri, headers: headers)
          : await _client.post(uri, headers: headers, body: jsonEncode(body));
    } catch (e) {
      throw ApiError(0, 'Сервер недоступен', noApi: true);
    }
    if (manageCookies) _readCookie(r.headers['set-cookie']);
    Object? j;
    try {
      j = jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {}
    if (j is! Map<String, dynamic>) throw ApiError(r.statusCode, 'Сервер недоступен', noApi: true);
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw ApiError(r.statusCode, '${j['error'] ?? 'Ошибка сервера'}', data: j);
    }
    return j;
  }

  void _readCookie(String? header) {
    if (header == null) return;
    final m = RegExp('$cookieName=([^;,]*)').firstMatch(header);
    if (m == null) return;
    final v = m.group(1)!;
    // сервер стирает cookie пустым значением при выходе и удалении
    final next = v.isEmpty || v == 'deleted' ? null : v;
    if (next != session) {
      session = next;
      onSession?.call(session);
    }
  }

  /// Кто вошёл и метка его сохранения; ApiError(noApi) — сервера нет, играем без учётной записи
  Future<({AccountUser? user, SaveMeta? save})> me() async {
    final j = await _call('me');
    final u = j['user'];
    return (user: u is Map<String, dynamic> ? AccountUser.fromJson(u) : null, save: SaveMeta.fromJson(j['save']));
  }

  Future<AccountUser> register(String login, String password) async {
    final j = await _call('register', body: {'login': login, 'password': password});
    return AccountUser.fromJson(j['user'] as Map<String, dynamic>);
  }

  Future<({AccountUser user, SaveMeta? save})> login(String login, String password) async {
    final j = await _call('login', body: {'login': login, 'password': password});
    return (user: AccountUser.fromJson(j['user'] as Map<String, dynamic>), save: SaveMeta.fromJson(j['save']));
  }

  Future<void> logout() async {
    await _call('logout', body: {});
    if (session != null) {
      session = null;
      onSession?.call(null);
    }
  }

  Future<ServerSave?> loadSave() async {
    final j = await _call('save');
    final s = j['save'];
    if (s is! Map) return null;
    return ServerSave('${s['data']}', (s['saved'] as num).toInt(), (s['updated'] as num).toInt());
  }

  /// Отправить сохранение. [base] — updated последней синхронизации этого устройства;
  /// если на сервере новее (с другого устройства), сервер ответит 409, пока не передан [force].
  Future<SaveMeta> save(String data, {required int saved, int? base, bool force = false}) async {
    final j = await _call('save', body: {'data': data, 'saved': saved, 'base': base, 'force': force});
    return SaveMeta.fromJson(j['save'])!;
  }

  /// Рейтинг: matter — материя за всё время, cells — больше всего клеток, kills — очки за сущности
  Future<TopTable> top(String by, {int limit = 100}) async {
    final j = await _call('top', query: {'by': by, 'limit': '$limit'});
    TopEntry e(Map m) => TopEntry('${m['login']}', (m['value'] as num).toDouble(), (m['rank'] as num?)?.toInt());
    return TopTable(
      '${j['by']}',
      [for (final x in j['list'] as List) e(x as Map)],
      j['me'] is Map ? e(j['me'] as Map) : null,
      (j['total'] as num?)?.toInt() ?? 0,
    );
  }

  /// Смена пароля: остальные устройства выйдут
  Future<void> changePassword(String oldPassword, String newPassword) =>
      _call('password', body: {'old': oldPassword, 'new': newPassword});

  Future<void> deleteAccount(String password) async {
    await _call('delete', body: {'password': password});
    session = null;
    onSession?.call(null);
  }

  void close() => _client.close();
}
