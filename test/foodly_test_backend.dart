import 'dart:convert';
import 'dart:io';

import 'package:flutter_foodly_operator_demo/src/foodly_domain.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

void installFoodlyTestPreferences() {
  SharedPreferencesAsyncPlatform.instance = FoodlyMemoryPreferences();
}

class FoodlyRealHttpOverrides extends HttpOverrides {}

base class FoodlyMemoryPreferences extends SharedPreferencesAsyncPlatform {
  final Map<String, Object> _values = <String, Object>{};

  @override
  Future<void> setString(
    String key,
    String value,
    SharedPreferencesOptions options,
  ) async {
    _values[key] = value;
  }

  @override
  Future<void> setBool(
    String key,
    bool value,
    SharedPreferencesOptions options,
  ) async {
    _values[key] = value;
  }

  @override
  Future<void> setDouble(
    String key,
    double value,
    SharedPreferencesOptions options,
  ) async {
    _values[key] = value;
  }

  @override
  Future<void> setInt(
    String key,
    int value,
    SharedPreferencesOptions options,
  ) async {
    _values[key] = value;
  }

  @override
  Future<void> setStringList(
    String key,
    List<String> value,
    SharedPreferencesOptions options,
  ) async {
    _values[key] = List<String>.unmodifiable(value);
  }

  @override
  Future<String?> getString(
      String key, SharedPreferencesOptions options) async {
    return _values[key] as String?;
  }

  @override
  Future<bool?> getBool(String key, SharedPreferencesOptions options) async {
    return _values[key] as bool?;
  }

  @override
  Future<double?> getDouble(
      String key, SharedPreferencesOptions options) async {
    return _values[key] as double?;
  }

  @override
  Future<int?> getInt(String key, SharedPreferencesOptions options) async {
    return _values[key] as int?;
  }

  @override
  Future<List<String>?> getStringList(
    String key,
    SharedPreferencesOptions options,
  ) async {
    return (_values[key] as List<String>?)?.toList(growable: false);
  }

  @override
  Future<void> clear(
    ClearPreferencesParameters parameters,
    SharedPreferencesOptions options,
  ) async {
    final allowList = parameters.filter.allowList;
    if (allowList == null) {
      _values.clear();
      return;
    }
    for (final key in allowList) {
      _values.remove(key);
    }
  }

  @override
  Future<Map<String, Object>> getPreferences(
    GetPreferencesParameters parameters,
    SharedPreferencesOptions options,
  ) async {
    final allowList = parameters.filter.allowList;
    return Map<String, Object>.unmodifiable(
      Map<String, Object>.fromEntries(
        _values.entries.where(
          (entry) => allowList == null || allowList.contains(entry.key),
        ),
      ),
    );
  }

  @override
  Future<Set<String>> getKeys(
    GetPreferencesParameters parameters,
    SharedPreferencesOptions options,
  ) async {
    final allowList = parameters.filter.allowList;
    return _values.keys
        .where((key) => allowList == null || allowList.contains(key))
        .toSet();
  }
}

class FoodlyTestBackend {
  FoodlyTestBackend._(this._server);

  final HttpServer _server;
  final Map<String, _SessionState> _sessions = <String, _SessionState>{};
  int _orderCounter = 1000;

  Uri get url => Uri.parse('http://127.0.0.1:${_server.port}');

  static Future<FoodlyTestBackend> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final backend = FoodlyTestBackend._(server);
    backend._serve();
    return backend;
  }

  Future<void> close() => _server.close(force: true);

  void _serve() {
    _server.listen((request) async {
      try {
        await _handle(request);
      } catch (error) {
        _writeJson(
          request.response,
          HttpStatus.internalServerError,
          <String, Object?>{'error': error.toString()},
        );
      }
    });
  }

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    if (request.method == 'GET' && path == '/healthz') {
      _writeJson(request.response, HttpStatus.ok, <String, Object?>{
        'ok': true,
      });
      return;
    }
    if (request.method == 'GET' && path == '/auth/session') {
      final session = _sessionFromRequest(request);
      if (session == null) {
        _writeJson(request.response, HttpStatus.noContent);
        return;
      }
      _writeJson(request.response, HttpStatus.ok, session.toJson());
      return;
    }
    if (request.method == 'POST' && path == '/auth/sign-in') {
      final body = await _readJson(request);
      final email = body['email']?.toString().trim().toLowerCase() ?? '';
      final password = body['password']?.toString() ?? '';
      if (!email.contains('@') || password.length < 4) {
        _writeJson(request.response, HttpStatus.unauthorized, <String, Object?>{
          'error': 'Invalid credentials',
        });
        return;
      }
      final session = _SessionState.forEmail(email);
      _sessions[session.accessToken] = session;
      _writeJson(request.response, HttpStatus.ok, session.toJson());
      return;
    }
    if (request.method == 'POST' && path == '/auth/sign-out') {
      final session = _sessionFromRequest(request);
      if (session != null) _sessions.remove(session.accessToken);
      _writeJson(request.response, HttpStatus.ok, <String, Object?>{
        'ok': true,
      });
      return;
    }
    if (request.method == 'GET' && path == '/products/search') {
      final query =
          request.uri.queryParameters['q']?.trim().toLowerCase() ?? '';
      final products = query.isEmpty
          ? defaultFoodlyProducts
          : defaultFoodlyProducts
              .where((product) => product.name.toLowerCase().contains(query))
              .toList(growable: false);
      _writeJson(request.response, HttpStatus.ok, <String, Object?>{
        'products': products.map((product) => product.toJson()).toList(),
      });
      return;
    }
    if (request.method == 'POST' && path == '/cart/items') {
      final session = _requireSession(request);
      final body = await _readJson(request);
      final product = defaultFoodlyProducts
          .where((item) => item.id == body['productId'])
          .firstOrNull;
      if (product == null) {
        _writeJson(request.response, HttpStatus.notFound, <String, Object?>{
          'error': 'Product was not found',
        });
        return;
      }
      if (!product.inStock) {
        _writeJson(request.response, HttpStatus.conflict, <String, Object?>{
          'error': 'Product is out of stock',
        });
        return;
      }
      final quantity = ((body['quantity'] as num?)?.toInt() ?? 1).clamp(1, 999);
      session.cart
        ..removeWhere((item) => item.productId == product.id)
        ..add(FoodlyCartItem(
          productId: product.id,
          name: product.name,
          price: product.price,
          quantity: quantity,
        ));
      _writeJson(request.response, HttpStatus.ok, <String, Object?>{
        'items': session.cart.map((item) => item.toJson()).toList(),
        'total': session.cartTotal,
      });
      return;
    }
    if (request.method == 'PATCH' && path == '/checkout/draft') {
      final session = _requireSession(request);
      final body = await _readJson(request);
      session.draft = FoodlyCheckoutDraft.fromJson(<String, Object?>{
        ...session.draft.toJson(),
        ...body,
      });
      _writeJson(request.response, HttpStatus.ok, <String, Object?>{
        'draft': session.draft.toJson(),
      });
      return;
    }
    if (request.method == 'POST' && path == '/promotions/validate') {
      _requireSession(request);
      final body = await _readJson(request);
      final code = body['code']?.toString().trim().toUpperCase() ?? '';
      final subtotal = (body['subtotal'] as num?)?.toInt() ?? 0;
      final discount = code == 'SAVE10' ? (subtotal * 0.1).round() : 0;
      if (discount <= 0) {
        _writeJson(request.response, HttpStatus.notFound, <String, Object?>{
          'code': code,
          'discount': 0,
          'valid': false,
          'error': 'Promo code is not valid',
        });
        return;
      }
      _writeJson(request.response, HttpStatus.ok, <String, Object?>{
        'code': code,
        'discount': discount,
        'valid': true,
      });
      return;
    }
    if (request.method == 'POST' && path == '/orders') {
      _requireSession(request);
      final body = await _readJson(request);
      final items = _jsonList(body['items'])
          .map((item) => FoodlyCartItem.fromJson(_jsonMap(item)))
          .toList(growable: false);
      final draft = FoodlyCheckoutDraft.fromJson(_jsonMap(body['draft']));
      if (items.isEmpty) {
        _writeJson(request.response, HttpStatus.conflict, <String, Object?>{
          'error': 'Cart is empty',
        });
        return;
      }
      if (draft.phone.trim().length < 6 || draft.address.trim().length < 6) {
        _writeJson(
          request.response,
          HttpStatus.unprocessableEntity,
          <String, Object?>{'error': 'Delivery details are incomplete'},
        );
        return;
      }
      final subtotal = items.fold<int>(
        0,
        (sum, item) => sum + item.price * item.quantity,
      );
      final discount = (body['discount'] as num?)?.toInt() ?? 0;
      final order = FoodlyOrder(
        id: 'ord_${++_orderCounter}',
        items: items,
        subtotal: subtotal,
        discount: discount,
        total: subtotal - discount,
        draft: draft,
        status: 'confirmed',
      );
      _writeJson(request.response, HttpStatus.created, order.toJson());
      return;
    }

    _writeJson(request.response, HttpStatus.notFound, <String, Object?>{
      'error': 'Not found',
    });
  }

  _SessionState? _sessionFromRequest(HttpRequest request) {
    final authorization =
        request.headers.value(HttpHeaders.authorizationHeader);
    final token = authorization?.startsWith('Bearer ') == true
        ? authorization!.substring('Bearer '.length)
        : null;
    return token == null ? null : _sessions[token];
  }

  _SessionState _requireSession(HttpRequest request) {
    final session = _sessionFromRequest(request);
    if (session == null) throw const HttpException('Sign in is required');
    return session;
  }
}

class _SessionState {
  _SessionState({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
    required this.draft,
  });

  factory _SessionState.forEmail(String email) {
    final name = email
        .split('@')
        .first
        .replaceAll(RegExp(r'[^a-zA-Z]+'), ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
    final user = FoodlyUser(
      id: 'usr_${email.replaceAll(RegExp(r'[^a-z0-9]+'), '_')}',
      name: name.isEmpty ? 'Demo User' : name,
      email: email,
      loyaltyTier: 'Gold',
    );
    return _SessionState(
      user: user,
      accessToken: 'foodly-access-${DateTime.now().microsecondsSinceEpoch}',
      refreshToken: 'foodly-refresh-${DateTime.now().microsecondsSinceEpoch}',
      draft: FoodlyCheckoutDraft(fullName: user.name, email: user.email),
    );
  }

  final FoodlyUser user;
  final String accessToken;
  final String refreshToken;
  FoodlyCheckoutDraft draft;
  final List<FoodlyCartItem> cart = <FoodlyCartItem>[];

  int get cartTotal => cart.fold<int>(
        0,
        (sum, item) => sum + item.price * item.quantity,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'user': user.toJson(),
        'authenticated': true,
        'tokenStored': true,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
      };
}

Future<Map<String, Object?>> _readJson(HttpRequest request) async {
  final text = await utf8.decoder.bind(request).join();
  if (text.trim().isEmpty) return <String, Object?>{};
  return jsonDecode(text) as Map<String, Object?>;
}

void _writeJson(
  HttpResponse response,
  int status, [
  Map<String, Object?>? body,
]) {
  response.statusCode = status;
  response.headers.contentType = ContentType.json;
  if (body == null) {
    response.close();
    return;
  }
  response.write(jsonEncode(body));
  response.close();
}

Map<String, Object?> _jsonMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map((key, child) => MapEntry(key.toString(), child));
  }
  return <String, Object?>{};
}

List<Object?> _jsonList(Object? value) {
  if (value is List<Object?>) return value;
  if (value is List) return value.cast<Object?>();
  return const <Object?>[];
}
