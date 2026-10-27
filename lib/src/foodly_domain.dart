import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

typedef FoodlyJson = Map<String, Object?>;

class FoodlyProduct {
  const FoodlyProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.inStock,
    required this.category,
  });

  factory FoodlyProduct.fromJson(FoodlyJson json) => FoodlyProduct(
        id: json['id'].toString(),
        name: json['name'].toString(),
        price: (json['price'] as num).toInt(),
        inStock: json['inStock'] == true,
        category: json['category'].toString(),
      );

  final String id;
  final String name;
  final int price;
  final bool inStock;
  final String category;

  FoodlyJson toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'price': price,
        'inStock': inStock,
        'category': category,
      };
}

class FoodlyCartItem {
  const FoodlyCartItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
  });

  factory FoodlyCartItem.fromJson(FoodlyJson json) => FoodlyCartItem(
        productId: json['productId'].toString(),
        name: json['name'].toString(),
        price: (json['price'] as num).toInt(),
        quantity: (json['quantity'] as num).toInt(),
      );

  final String productId;
  final String name;
  final int price;
  final int quantity;

  FoodlyJson toJson() => <String, Object?>{
        'productId': productId,
        'name': name,
        'price': price,
        'quantity': quantity,
      };
}

class FoodlyUser {
  const FoodlyUser({
    required this.id,
    required this.name,
    required this.email,
    required this.loyaltyTier,
  });

  factory FoodlyUser.fromJson(FoodlyJson json) => FoodlyUser(
        id: json['id'].toString(),
        name: json['name'].toString(),
        email: json['email'].toString(),
        loyaltyTier: json['loyaltyTier'].toString(),
      );

  final String id;
  final String name;
  final String email;
  final String loyaltyTier;

  FoodlyJson toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'email': email,
        'loyaltyTier': loyaltyTier,
      };
}

class FoodlySession {
  const FoodlySession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  factory FoodlySession.fromJson(FoodlyJson json) => FoodlySession(
        user: FoodlyUser.fromJson(_jsonMap(json['user'])),
        accessToken: json['accessToken']?.toString() ?? '',
        refreshToken: json['refreshToken']?.toString() ?? '',
      );

  final FoodlyUser user;
  final String accessToken;
  final String refreshToken;

  FoodlyJson toJson({bool includeTokens = false}) => <String, Object?>{
        'user': user.toJson(),
        'authenticated': true,
        'tokenStored': accessToken.isNotEmpty,
        if (includeTokens) 'accessToken': accessToken,
        if (includeTokens) 'refreshToken': refreshToken,
      };
}

class FoodlyCheckoutDraft {
  const FoodlyCheckoutDraft({
    this.fullName = '',
    this.email = '',
    this.phone = '',
    this.address = '',
    this.deliveryInstructions = '',
    this.deliveryWindow = 'Today 6-8 PM',
    this.paymentMethod = 'Card on delivery',
    this.promoCode = '',
    this.saveAddress = true,
  });

  factory FoodlyCheckoutDraft.fromJson(FoodlyJson json) => FoodlyCheckoutDraft(
        fullName: json['fullName']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        phone: json['phone']?.toString() ?? '',
        address: json['address']?.toString() ?? '',
        deliveryInstructions: json['deliveryInstructions']?.toString() ?? '',
        deliveryWindow: json['deliveryWindow']?.toString() ?? 'Today 6-8 PM',
        paymentMethod: json['paymentMethod']?.toString() ?? 'Card on delivery',
        promoCode: json['promoCode']?.toString() ?? '',
        saveAddress: json['saveAddress'] != false,
      );

  final String fullName;
  final String email;
  final String phone;
  final String address;
  final String deliveryInstructions;
  final String deliveryWindow;
  final String paymentMethod;
  final String promoCode;
  final bool saveAddress;

  FoodlyCheckoutDraft copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? address,
    String? deliveryInstructions,
    String? deliveryWindow,
    String? paymentMethod,
    String? promoCode,
    bool? saveAddress,
  }) {
    return FoodlyCheckoutDraft(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      deliveryInstructions: deliveryInstructions ?? this.deliveryInstructions,
      deliveryWindow: deliveryWindow ?? this.deliveryWindow,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      promoCode: promoCode ?? this.promoCode,
      saveAddress: saveAddress ?? this.saveAddress,
    );
  }

  FoodlyJson toJson() => <String, Object?>{
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'address': address,
        'deliveryInstructions': deliveryInstructions,
        'deliveryWindow': deliveryWindow,
        'paymentMethod': paymentMethod,
        'promoCode': promoCode,
        'saveAddress': saveAddress,
      };
}

class FoodlyOrder {
  const FoodlyOrder({
    required this.id,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.draft,
    required this.status,
  });

  factory FoodlyOrder.fromJson(FoodlyJson json) => FoodlyOrder(
        id: json['id'].toString(),
        items: _jsonList(json['items'])
            .map((item) => FoodlyCartItem.fromJson(_jsonMap(item)))
            .toList(growable: false),
        subtotal: (json['subtotal'] as num).toInt(),
        discount: (json['discount'] as num).toInt(),
        total: (json['total'] as num).toInt(),
        draft: FoodlyCheckoutDraft.fromJson(_jsonMap(json['delivery'])),
        status: json['status'].toString(),
      );

  final String id;
  final List<FoodlyCartItem> items;
  final int subtotal;
  final int discount;
  final int total;
  final FoodlyCheckoutDraft draft;
  final String status;

  FoodlyJson toJson() => <String, Object?>{
        'id': id,
        'items': items.map((item) => item.toJson()).toList(),
        'subtotal': subtotal,
        'discount': discount,
        'total': total,
        'delivery': draft.toJson(),
        'status': status,
      };
}

abstract class FoodlyRepository {
  Future<FoodlySession?> restoreSession();

  Future<FoodlySession> signIn({
    required String email,
    required String password,
  });

  Future<void> signOut();

  Future<List<FoodlyProduct>> searchProducts(String query);

  Future<List<FoodlyCartItem>> addToCart({
    required FoodlyProduct product,
    required int quantity,
  });

  Future<FoodlyCheckoutDraft> saveCheckoutDraft(FoodlyCheckoutDraft draft);

  Future<int> applyPromoCode({
    required String code,
    required int subtotal,
  });

  Future<FoodlyOrder> submitOrder({
    required FoodlySession session,
    required List<FoodlyCartItem> items,
    required FoodlyCheckoutDraft draft,
    required int discount,
  });
}

class FoodlyRestRepository implements FoodlyRepository {
  FoodlyRestRepository({
    required Uri baseUrl,
    FoodlyLocalStore? store,
    HttpClient? client,
  })  : _client = FoodlyApiClient(baseUrl: baseUrl, client: client),
        _store = store ?? FoodlyLocalStore();

  final FoodlyApiClient _client;
  final FoodlyLocalStore _store;
  FoodlySession? _session;

  @override
  Future<FoodlySession?> restoreSession() async {
    final stored = await _store.readSession();
    final response = await _client.get(
      '/auth/session',
      token: stored?.accessToken,
    );
    if (response == null) {
      await _store.clearSession();
      return null;
    }
    final session = FoodlySession.fromJson(response);
    await _store.writeSession(session);
    _session = session;
    return session;
  }

  @override
  Future<FoodlySession> signIn({
    required String email,
    required String password,
  }) async {
    final response =
        await _client.post('/auth/sign-in', body: <String, Object?>{
      'email': email,
      'password': password,
    });
    final session = FoodlySession.fromJson(response);
    await _store.writeSession(session);
    _session = session;
    return session;
  }

  @override
  Future<void> signOut() async {
    final session = await _currentSession();
    await _client.post('/auth/sign-out', token: session?.accessToken);
    _session = null;
    await _store.clearSession();
  }

  @override
  Future<List<FoodlyProduct>> searchProducts(String query) async {
    final response = await _client.get(
      '/products/search',
      query: <String, String>{'q': query},
    );
    await _store.writeString('foodly.lastSearch', query);
    return _jsonList(response?['products'])
        .map((item) => FoodlyProduct.fromJson(_jsonMap(item)))
        .toList(growable: false);
  }

  @override
  Future<List<FoodlyCartItem>> addToCart({
    required FoodlyProduct product,
    required int quantity,
  }) async {
    final session = await _currentSession();
    final response = await _client.post(
      '/cart/items',
      token: session?.accessToken,
      body: <String, Object?>{
        'productId': product.id,
        'quantity': quantity,
      },
    );
    final items = _jsonList(response['items'])
        .map((item) => FoodlyCartItem.fromJson(_jsonMap(item)))
        .toList(growable: false);
    await _store.writeJson('foodly.cartSummary', <String, Object?>{
      'items': items.map((item) => item.toJson()).toList(),
      'total': response['total'],
    });
    return items;
  }

  @override
  Future<FoodlyCheckoutDraft> saveCheckoutDraft(
    FoodlyCheckoutDraft draft,
  ) async {
    final session = await _currentSession();
    final response = await _client.patch(
      '/checkout/draft',
      token: session?.accessToken,
      body: draft.toJson(),
    );
    final saved = FoodlyCheckoutDraft.fromJson(_jsonMap(response['draft']));
    await _store.writeCheckoutDraft(saved);
    return saved;
  }

  @override
  Future<int> applyPromoCode({
    required String code,
    required int subtotal,
  }) async {
    final session = await _currentSession();
    final response = await _client.post(
      '/promotions/validate',
      token: session?.accessToken,
      body: <String, Object?>{'code': code, 'subtotal': subtotal},
    );
    return (response['discount'] as num).toInt();
  }

  @override
  Future<FoodlyOrder> submitOrder({
    required FoodlySession session,
    required List<FoodlyCartItem> items,
    required FoodlyCheckoutDraft draft,
    required int discount,
  }) async {
    final response = await _client.post(
      '/orders',
      token: session.accessToken,
      body: <String, Object?>{
        'items': items.map((item) => item.toJson()).toList(),
        'draft': draft.toJson(),
        'discount': discount,
      },
    );
    final order = FoodlyOrder.fromJson(response);
    await _store.writeString('foodly.lastOrderId', order.id);
    if (draft.saveAddress) {
      await _store.writeJson('foodly.savedAddress', <String, Object?>{
        'address': draft.address,
        'phone': draft.phone,
        'deliveryWindow': draft.deliveryWindow,
      });
    }
    return order;
  }

  Future<FoodlySession?> _currentSession() async {
    final cached = _session;
    if (cached != null) return cached;
    _session = await _store.readSession();
    return _session;
  }
}

class FoodlyApiClient {
  FoodlyApiClient({required Uri baseUrl, HttpClient? client})
      : _baseUrl = baseUrl,
        _providedClient = client;

  final Uri _baseUrl;
  final HttpClient? _providedClient;

  Future<FoodlyJson?> get(
    String path, {
    Map<String, String> query = const <String, String>{},
    String? token,
  }) {
    return _send('GET', path, query: query, token: token);
  }

  Future<FoodlyJson> post(
    String path, {
    FoodlyJson body = const <String, Object?>{},
    String? token,
  }) async {
    return (await _send('POST', path, body: body, token: token)) ??
        <String, Object?>{};
  }

  Future<FoodlyJson> patch(
    String path, {
    FoodlyJson body = const <String, Object?>{},
    String? token,
  }) async {
    return (await _send('PATCH', path, body: body, token: token)) ??
        <String, Object?>{};
  }

  Future<FoodlyJson?> _send(
    String method,
    String path, {
    Map<String, String> query = const <String, String>{},
    FoodlyJson? body,
    String? token,
  }) async {
    final client = _providedClient ?? HttpClient();
    final uri = _baseUrl.replace(
      path: path,
      queryParameters: query.isEmpty ? null : query,
    );
    try {
      final request = await client.openUrl(method, uri);
      request.persistentConnection = false;
      request.headers
        ..set(HttpHeaders.acceptHeader, 'application/json')
        ..set(HttpHeaders.contentTypeHeader, 'application/json');
      if (token != null && token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (body != null) request.write(jsonEncode(body));

      final response = await request.close();
      final text = await utf8.decoder.bind(response).join();
      final decoded = text.trim().isEmpty ? null : jsonDecode(text);
      final json = decoded == null ? null : _jsonMap(decoded);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json;
      }
      final message = json?['error']?.toString() ??
          json?['message']?.toString() ??
          'Request failed with ${response.statusCode}';
      throw FoodlyApiException(
        statusCode: response.statusCode,
        message: message,
        path: path,
      );
    } finally {
      if (_providedClient == null) {
        client.close(force: true);
      }
    }
  }
}

class FoodlyLocalStore {
  FoodlyLocalStore({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  Future<FoodlySession?> readSession() async {
    final userText = await _preferences.getString('foodly.sessionUser');
    final accessToken = await _preferences.getString('foodly.sessionToken');
    final refreshToken = await _preferences.getString('foodly.refreshToken');
    if (userText == null || accessToken == null || refreshToken == null) {
      return null;
    }
    return FoodlySession(
      user: FoodlyUser.fromJson(_jsonMap(jsonDecode(userText))),
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  Future<void> writeSession(FoodlySession session) async {
    await _preferences.setString(
      'foodly.sessionUser',
      jsonEncode(session.user.toJson()),
    );
    await _preferences.setString('foodly.sessionToken', session.accessToken);
    await _preferences.setString('foodly.refreshToken', session.refreshToken);
    await _preferences.setString('foodly.lastEmail', session.user.email);
  }

  Future<void> clearSession() async {
    await _preferences.remove('foodly.sessionUser');
    await _preferences.remove('foodly.sessionToken');
    await _preferences.remove('foodly.refreshToken');
  }

  Future<FoodlyCheckoutDraft> readCheckoutDraft() async {
    final text = await _preferences.getString('foodly.checkoutDraft');
    if (text == null || text.trim().isEmpty) {
      return const FoodlyCheckoutDraft();
    }
    return FoodlyCheckoutDraft.fromJson(_jsonMap(jsonDecode(text)));
  }

  Future<void> writeCheckoutDraft(FoodlyCheckoutDraft draft) {
    return writeJson('foodly.checkoutDraft', draft.toJson());
  }

  Future<void> writeJson(String key, FoodlyJson value) {
    return _preferences.setString(key, jsonEncode(value));
  }

  Future<void> writeString(String key, String value) {
    return _preferences.setString(key, value);
  }
}

class FoodlyApiException implements Exception {
  FoodlyApiException({
    required this.statusCode,
    required this.message,
    required this.path,
  });

  final int statusCode;
  final String message;
  final String path;

  @override
  String toString() => message;
}

FoodlyJson _jsonMap(Object? value) {
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

const List<FoodlyProduct> defaultFoodlyProducts = <FoodlyProduct>[
  FoodlyProduct(
    id: 'p_chicken',
    name: 'Chicken Pot',
    price: 4000,
    inStock: true,
    category: 'Meals',
  ),
  FoodlyProduct(
    id: 'p_coke',
    name: 'Coke',
    price: 500,
    inStock: true,
    category: 'Drinks',
  ),
  FoodlyProduct(
    id: 'p_water',
    name: 'Water',
    price: 300,
    inStock: true,
    category: 'Drinks',
  ),
  FoodlyProduct(
    id: 'p_chocolate',
    name: 'Chocolate Cake',
    price: 2500,
    inStock: false,
    category: 'Desserts',
  ),
];
