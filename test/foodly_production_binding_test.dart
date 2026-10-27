import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_foodly_operator_demo/main.dart' as foodly;
import 'package:huntingdogs/huntingdogs.dart';

import 'foodly_test_backend.dart';

void main() {
  test('Foodly business code does not import or call the Operator SDK', () {
    for (final path in <String>[
      'lib/src/foodly_domain.dart',
      'lib/src/foodly_cubits.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('huntingdogs')), reason: path);
      expect(source, isNot(contains('Operator')), reason: path);
      expect(source, isNot(contains('networkAdapter')), reason: path);
      expect(source, isNot(contains('storageAdapters')), reason: path);
    }
  });

  testWidgets(
    'production session drives auth, network, storage, forms, and checkout state',
    (tester) async {
      await HttpOverrides.runWithHttpOverrides(() async {
        installFoodlyTestPreferences();
        final foodlyBackend = await _realAsync(tester, FoodlyTestBackend.start);
        final backend = await _realAsync(tester, _FakeProductionBackend.start);
        late OperatorApp operatorApp;
        var operatorReady = false;

        await tester.pumpWidget(
          OperatorAppHost(
            config: const OperatorFlutterConfig(
              appId: 'foodly-production-demo',
              name: 'Foodly Production Demo',
              environment: OperatorEnvironment.dev,
            ),
            onReady: (readyOperatorApp) {
              operatorApp = readyOperatorApp;
              operatorReady = true;
            },
            child: foodly.FoodlyProductionApp(
              apiBaseUrl: foodlyBackend.url.toString(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 250));
        expect(operatorReady, isTrue);

        final session = OperatorFlutterProductionSession(
          adapter: operatorApp.binding.adapter,
          config: OperatorProductionSessionConfig(
            endpoint: backend.url,
            sessionId: 'foodly-complex-user-session',
            appId: 'foodly-production-demo',
            userId: 'demo-user',
            deviceId: 'flutter-test-device',
            sessionSecret: _FakeProductionBackend.sessionSecret,
            operatorControlConsent: true,
            appMapManifest: const OperatorAppMapManifest(
              appId: 'foodly-production-demo',
              appVersion: '1.0.0-test',
              gitSha: 'flutter-foodly-test-sha',
              appMapHash: 'sha256:flutter-foodly-test-hash',
              platform: 'flutter',
              formatVersion: 'operator-appmap/v1',
            ),
            bundledAppMap: const <String, Object?>{
              'appId': 'foodly-production-demo',
              'routes': <Object?>[
                <String, Object?>{'path': '/sign-in', 'screen': 'Sign in'},
                <String, Object?>{'path': '/', 'screen': 'Home'},
                <String, Object?>{'path': '/search', 'screen': 'Search'},
                <String, Object?>{'path': '/checkout', 'screen': 'Checkout'},
                <String, Object?>{'path': '/account', 'screen': 'Account'},
              ],
              'stateStores': <Object?>[
                <String, Object?>{'name': 'AuthState', 'source': 'bloc'},
                <String, Object?>{
                  'name': 'ProductSearchState',
                  'source': 'bloc'
                },
                <String, Object?>{'name': 'CartState', 'source': 'bloc'},
                <String, Object?>{'name': 'CheckoutState', 'source': 'bloc'},
              ],
            },
          ),
          client: backend.client,
        );

        try {
          await _realAsync(tester, session.connect);
          expect(backend.connectedAppId, 'foodly-production-demo');
          expect(backend.connectedDeviceId, 'flutter-test-device');
          expect(backend.controlConsent, isTrue);
          expect(backend.uploadedAppMap?['appId'], 'foodly-production-demo');

          await _runAction(tester, backend, session, <String, Object?>{
            'type': 'type',
            'target': const <String, Object?>{'label': 'Email'},
            'text': 'ada@example.com',
            'clearFirst': true,
            'purpose': 'test_enter_email',
          });
          await _runAction(tester, backend, session, <String, Object?>{
            'type': 'type',
            'target': const <String, Object?>{'label': 'Password'},
            'text': 'demo1234',
            'clearFirst': true,
            'purpose': 'test_enter_password',
          });
          await _runAction(tester, backend, session, <String, Object?>{
            'type': 'tap',
            'target': const <String, Object?>{'label': 'Sign in'},
            'purpose': 'test_sign_in',
          });
          await _waitForSnapshot(
            tester,
            backend,
            session,
            description: 'authenticated home route',
            matches: () {
              final auth = backend.stateStore('AuthState')?['state'];
              return backend.routePath == '/' &&
                  auth is Map<String, Object?> &&
                  auth['authenticated'] == true;
            },
          );
          final authAfterSignIn = backend.stateStore('AuthState')?['state'];
          expect(
            authAfterSignIn,
            containsPair('authenticated', true),
            reason: jsonEncode(<String, Object?>{
              'route': backend.routePath,
              'auth': authAfterSignIn,
              'network': backend.networkPaths,
            }),
          );
          expect(
            backend.routePath,
            '/',
            reason: jsonEncode(<String, Object?>{
              'auth': authAfterSignIn,
              'network': backend.networkPaths,
            }),
          );

          await _runAction(tester, backend, session, <String, Object?>{
            'type': 'navigate',
            'path': '/search',
            'purpose': 'test_open_search',
          });
          await _runAction(tester, backend, session, <String, Object?>{
            'type': 'type',
            'target': const <String, Object?>{'label': 'Search products'},
            'text': 'Coke',
            'clearFirst': true,
            'purpose': 'test_search_coke',
          });
          await _waitForSnapshot(
            tester,
            backend,
            session,
            description: 'Coke search results loaded',
            matches: () => _searchReady(backend, 'Coke', 'p_coke'),
          );
          await _runAction(tester, backend, session, <String, Object?>{
            'type': 'tap',
            'target': const <String, Object?>{'text': 'Coke'},
            'purpose': 'test_choose_coke',
          });
          await _waitForSnapshot(
            tester,
            backend,
            session,
            description: 'Coke selected',
            matches: () => _selectedProduct(backend) == 'p_coke',
          );
          await _runAction(tester, backend, session, <String, Object?>{
            'type': 'type',
            'target': const <String, Object?>{'label': 'Quantity'},
            'text': '3',
            'clearFirst': true,
            'purpose': 'test_quantity_coke',
          });
          await _waitForSnapshot(
            tester,
            backend,
            session,
            description: 'Coke quantity set',
            matches: () =>
                _selectedProduct(backend) == 'p_coke' &&
                _selectedQuantity(backend) == 3,
          );
          await _runAction(tester, backend, session, <String, Object?>{
            'type': 'tap',
            'target': const <String, Object?>{'label': 'Add to cart'},
            'purpose': 'test_add_coke',
          });
          await _waitForSnapshot(
            tester,
            backend,
            session,
            description: 'cart contains Coke x3',
            matches: () => _cartContains(backend, 'p_coke', 3),
          );

          await _runAction(tester, backend, session, <String, Object?>{
            'type': 'type',
            'target': const <String, Object?>{'label': 'Search products'},
            'text': 'Water',
            'clearFirst': true,
            'purpose': 'test_search_water',
          });
          await _waitForSnapshot(
            tester,
            backend,
            session,
            description: 'Water search results loaded',
            matches: () => _searchReady(backend, 'Water', 'p_water'),
          );
          await _runAction(tester, backend, session, <String, Object?>{
            'type': 'tap',
            'target': const <String, Object?>{'text': 'Water'},
            'purpose': 'test_choose_water',
          });
          await _waitForSnapshot(
            tester,
            backend,
            session,
            description: 'Water selected',
            matches: () => _selectedProduct(backend) == 'p_water',
          );
          await _runAction(tester, backend, session, <String, Object?>{
            'type': 'tap',
            'target': const <String, Object?>{'label': 'Add to cart'},
            'purpose': 'test_add_water',
          });
          await _waitForSnapshot(
            tester,
            backend,
            session,
            description: 'cart contains Water x1',
            matches: () => _cartContains(backend, 'p_water', 1),
          );

          await _runAction(tester, backend, session, <String, Object?>{
            'type': 'navigate',
            'path': '/checkout',
            'purpose': 'test_open_checkout',
          });
          await _waitForSnapshot(
            tester,
            backend,
            session,
            description: 'checkout form visible',
            matches: () =>
                backend.routePath == '/checkout' &&
                backend.formLabels.contains('Full name'),
          );
          await _runAction(tester, backend, session, <String, Object?>{
            'type': 'type',
            'target': const <String, Object?>{'label': 'Full name'},
            'text': 'Ada Lovelace',
            'clearFirst': true,
            'purpose': 'test_full_name',
          });
          await _waitForSnapshot(
            tester,
            backend,
            session,
            description: 'full name draft saved',
            matches: () =>
                _checkoutDraftValue(
                      backend,
                      'fullName',
                    ) ==
                    'Ada Lovelace' &&
                !_checkoutSavingDraft(backend),
          );
          await _runAction(tester, backend, session, <String, Object?>{
            'type': 'type',
            'target': const <String, Object?>{'label': 'Phone number'},
            'text': '08055550123',
            'clearFirst': true,
            'purpose': 'test_phone',
          });
          await _waitForSnapshot(
            tester,
            backend,
            session,
            description: 'phone draft saved',
            matches: () =>
                _checkoutDraftValue(backend, 'phone') == '08055550123' &&
                !_checkoutSavingDraft(backend),
          );
          await _runAction(tester, backend, session, <String, Object?>{
            'type': 'type',
            'target': const <String, Object?>{'label': 'Delivery address'},
            'text': '12 Bourdillon Road Ikoyi Lagos',
            'clearFirst': true,
            'purpose': 'test_address',
          });
          await _waitForSnapshot(
            tester,
            backend,
            session,
            description: 'address draft saved',
            matches: () =>
                _checkoutDraftValue(
                      backend,
                      'address',
                    ) ==
                    '12 Bourdillon Road Ikoyi Lagos' &&
                !_checkoutSavingDraft(backend),
          );
          await _runAction(tester, backend, session, <String, Object?>{
            'type': 'type',
            'target': const <String, Object?>{'label': 'Delivery instructions'},
            'text': 'Call when outside',
            'clearFirst': true,
            'purpose': 'test_instructions',
          });
          await _waitForSnapshot(
            tester,
            backend,
            session,
            description: 'instructions draft saved',
            matches: () =>
                _checkoutDraftValue(
                      backend,
                      'deliveryInstructions',
                    ) ==
                    'Call when outside' &&
                !_checkoutSavingDraft(backend),
          );
          await _runAction(tester, backend, session, <String, Object?>{
            'type': 'scroll',
            'direction': 'up',
            'target': const <String, Object?>{'label': 'Checkout'},
            'purpose': 'test_reveal_checkout_payment_controls',
          });
          await _runAction(tester, backend, session, <String, Object?>{
            'type': 'type',
            'target': const <String, Object?>{'label': 'Promo code'},
            'text': 'SAVE10',
            'clearFirst': true,
            'purpose': 'test_promo',
          });
          await _waitForSnapshot(
            tester,
            backend,
            session,
            description: 'promo draft saved',
            matches: () =>
                _checkoutDraftValue(backend, 'promoCode') == 'SAVE10' &&
                !_checkoutSavingDraft(backend),
          );
          await _runAction(tester, backend, session, <String, Object?>{
            'type': 'tap',
            'target': const <String, Object?>{'label': 'Apply promo'},
            'purpose': 'test_apply_promo',
          });
          await _waitForSnapshot(
            tester,
            backend,
            session,
            description: 'SAVE10 promo applied',
            matches: () {
              final checkout = backend.stateStore('CheckoutState')?['state'];
              return checkout is Map<String, Object?> &&
                  checkout['discount'] == 180;
            },
          );
          await _runAction(tester, backend, session, <String, Object?>{
            'type': 'scroll',
            'direction': 'up',
            'target': const <String, Object?>{'label': 'Checkout'},
            'purpose': 'test_reveal_place_order',
          });
          await _runAction(tester, backend, session, <String, Object?>{
            'type': 'tap',
            'target': const <String, Object?>{'label': 'Place order'},
            'purpose': 'test_place_order',
          });
          await _waitForSnapshot(
            tester,
            backend,
            session,
            description: 'confirmed order',
            matches: () {
              final checkout = backend.stateStore('CheckoutState')?['state']
                  as Map<String, Object?>?;
              final order = checkout?['order'] as Map<String, Object?>?;
              return order?['status'] == 'confirmed';
            },
          );

          final cartState = backend.stateStore('CartState')?['state']
              as Map<String, Object?>?;
          final items = (cartState?['items'] as List<Object?>?)
                  ?.cast<Map<String, Object?>>() ??
              const <Map<String, Object?>>[];
          expect(
            items,
            contains(predicate<Map<String, Object?>>(
              (item) => item['productId'] == 'p_coke' && item['quantity'] == 3,
            )),
          );
          expect(
            items,
            contains(predicate<Map<String, Object?>>(
              (item) => item['productId'] == 'p_water' && item['quantity'] == 1,
            )),
          );

          final checkoutState = backend.stateStore('CheckoutState')?['state']
              as Map<String, Object?>?;
          expect(checkoutState?['discount'], 180);
          final order = checkoutState?['order'] as Map<String, Object?>?;
          expect(order?['status'], 'confirmed');
          expect(order?['total'], 1620);
          expect(
            (checkoutState?['draft'] as Map<String, Object?>?)?['address'],
            '12 Bourdillon Road Ikoyi Lagos',
          );
          expect(
            (checkoutState?['draft'] as Map<String, Object?>?)?['email'],
            'ada@example.com',
          );

          expect(backend.networkPaths, contains('/auth/sign-in'));
          expect(backend.networkPaths, contains('/products/search'));
          expect(backend.networkPaths, contains('/cart/items'));
          expect(backend.networkPaths, contains('/checkout/draft'));
          expect(backend.networkPaths, contains('/promotions/validate'));
          expect(backend.networkPaths, contains('/orders'));

          await tester.pump(const Duration(milliseconds: 350));
          await _realAsync(tester, session.publishSnapshot);
          expect(backend.storageKeys, contains('foodly.sessionToken'));
          expect(backend.storageKeys, contains('foodly.checkoutDraft'));
          expect(backend.storageKeys, contains('foodly.cartSummary'));
          expect(backend.storageKeys, contains('foodly.lastOrderId'));

          expect(backend.formLabels.join('\n'), contains('Full name'));
          expect(backend.formLabels.join('\n'), contains('Delivery address'));
          expect(backend.formLabels.join('\n'), contains('Promo code'));
        } finally {
          await _realAsync(tester, session.close);
          await tester.pumpWidget(const SizedBox());
          await _realAsync(tester, backend.close);
          await _realAsync(tester, foodlyBackend.close);
        }
      }, _OperatorCaptureTestHttpOverrides());
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

class _OperatorCaptureTestHttpOverrides extends FoodlyRealHttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return OperatorHttpCapture.wrapActive(super.createHttpClient(context));
  }
}

Future<void> _runAction(
  WidgetTester tester,
  _FakeProductionBackend backend,
  OperatorFlutterProductionSession session,
  Map<String, Object?> action,
) async {
  final result = await _realAsync(
    tester,
    () => backend.executeAndWait(session, action),
  );
  final actionResult = result?['result'] as Map<String, Object?>?;
  expect(actionResult?['ok'], isTrue, reason: jsonEncode(actionResult));
  await tester.pump(const Duration(milliseconds: 16));
}

Future<void> _waitForSnapshot(
  WidgetTester tester,
  _FakeProductionBackend backend,
  OperatorFlutterProductionSession session, {
  required String description,
  required bool Function() matches,
  int attempts = 120,
}) async {
  for (var attempt = 0; attempt < attempts; attempt += 1) {
    await _realAsync(
      tester,
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump(const Duration(milliseconds: 16));
    await _realAsync(tester, session.publishSnapshot);
    if (matches()) return;
  }
  fail(
    'Timed out waiting for $description: ${jsonEncode(<String, Object?>{
          'route': backend.routePath,
          'network': backend.networkPaths,
          'states': backend.latestSnapshot?['state'],
          'storage': backend.storageKeys,
        })}',
  );
}

bool _cartContains(
    _FakeProductionBackend backend, String productId, int quantity) {
  final cartState =
      backend.stateStore('CartState')?['state'] as Map<String, Object?>?;
  final items =
      (cartState?['items'] as List<Object?>?)?.cast<Map<String, Object?>>() ??
          const <Map<String, Object?>>[];
  return items.any(
    (item) => item['productId'] == productId && item['quantity'] == quantity,
  );
}

bool _searchReady(
  _FakeProductionBackend backend,
  String query,
  String productId,
) {
  final search = backend.stateStore('ProductSearchState')?['state']
      as Map<String, Object?>?;
  final results =
      (search?['results'] as List<Object?>?)?.cast<Map<String, Object?>>() ??
          const <Map<String, Object?>>[];
  return search?['query'] == query &&
      search?['loading'] == false &&
      results.any((item) => item['id'] == productId);
}

String? _selectedProduct(_FakeProductionBackend backend) {
  final search = backend.stateStore('ProductSearchState')?['state']
      as Map<String, Object?>?;
  final selected = search?['selected'] as Map<String, Object?>?;
  return selected?['id'] as String?;
}

int? _selectedQuantity(_FakeProductionBackend backend) {
  final search = backend.stateStore('ProductSearchState')?['state']
      as Map<String, Object?>?;
  return (search?['quantity'] as num?)?.toInt();
}

Object? _checkoutDraftValue(_FakeProductionBackend backend, String key) {
  final checkout =
      backend.stateStore('CheckoutState')?['state'] as Map<String, Object?>?;
  final draft = checkout?['draft'] as Map<String, Object?>?;
  return draft?[key];
}

bool _checkoutSavingDraft(_FakeProductionBackend backend) {
  final checkout =
      backend.stateStore('CheckoutState')?['state'] as Map<String, Object?>?;
  return checkout?['savingDraft'] == true;
}

class _FakeProductionBackend {
  _FakeProductionBackend._(this.url) : client = _FakeProductionHttpClient();

  static const String sessionSecret = 'foodly-session-secret';

  final Uri url;
  final _FakeProductionHttpClient client;
  final List<Map<String, Object?>> _commands = <Map<String, Object?>>[];
  final List<Map<String, Object?>> results = <Map<String, Object?>>[];
  Map<String, Object?>? latestSnapshot;
  String? connectedAppId;
  String? connectedDeviceId;
  Map<String, Object?>? connectedAppMapManifest;
  Map<String, Object?>? uploadedAppMap;
  bool controlConsent = false;
  int _counter = 0;

  static Future<_FakeProductionBackend> start() async {
    final backend = _FakeProductionBackend._(
      Uri.parse('https://operator.test'),
    );
    backend.client.backend = backend;
    return backend;
  }

  Future<void> close() async {
    client.close(force: true);
  }

  Future<Map<String, Object?>?> executeAndWait(
    OperatorFlutterProductionSession session,
    Map<String, Object?> action,
  ) async {
    final commandId = 'cmd_${++_counter}';
    _commands.add(<String, Object?>{
      'commandId': commandId,
      'action': action,
      'issuedAt': DateTime.now().toIso8601String(),
    });
    await session.pumpOnce().timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw TimeoutException(
            'Timed out waiting for operator command result: ${jsonEncode(action)}',
            const Duration(seconds: 30),
          ),
        );
    return results.lastWhere(
      (result) => result['commandId'] == commandId,
      orElse: () => throw StateError(
        'Operator command did not post a result: ${jsonEncode(action)}',
      ),
    );
  }

  String? get routePath {
    final route = latestSnapshot?['route'] as Map<String, Object?>?;
    final current = route?['current'] as Map<String, Object?>?;
    return current?['path'] as String?;
  }

  List<String> get networkPaths {
    final network = latestSnapshot?['network'] as Map<String, Object?>?;
    final events = network?['events'] as List<Object?>? ?? const <Object?>[];
    return events
        .cast<Map<String, Object?>>()
        .map((event) => event['request'] as Map<String, Object?>?)
        .whereType<Map<String, Object?>>()
        .map((request) => request['path'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
  }

  List<String> get storageKeys {
    final storage = latestSnapshot?['storage'] as Map<String, Object?>?;
    final entries = storage?['entries'] as List<Object?>? ?? const <Object?>[];
    return entries
        .cast<Map<String, Object?>>()
        .map((entry) => entry['key'] as String?)
        .whereType<String>()
        .toList();
  }

  List<String> get formLabels {
    final forms =
        latestSnapshot?['forms'] as List<Object?>? ?? const <Object?>[];
    return forms
        .cast<Map<String, Object?>>()
        .expand((form) => form['fields'] as List<Object?>? ?? const <Object?>[])
        .cast<Map<String, Object?>>()
        .map((field) => field['label'] as String?)
        .whereType<String>()
        .toList();
  }

  Map<String, Object?>? stateStore(String name) {
    final state = latestSnapshot?['state'] as List<Object?>?;
    final store = state
        ?.cast<Map<String, Object?>>()
        .where((item) => item['name'] == name)
        .firstOrNull;
    return store?['value'] as Map<String, Object?>?;
  }

  _FakeHttpResponse handle(
    String method,
    Uri uri,
    Map<String, String> headers,
    String text,
  ) {
    final path = uri.path;
    if (headers['x-operator-session-secret'] != sessionSecret) {
      return const _FakeHttpResponse(
        HttpStatus.unauthorized,
        <String, Object?>{},
      );
    }
    if (method == 'POST' && path.endsWith('/connect')) {
      final body = _readJson(text);
      connectedAppId = body['appId']?.toString();
      connectedDeviceId = body['deviceId']?.toString();
      connectedAppMapManifest = _asJsonMap(body['appMapManifest']);
      final consent = body['consent'] as Map<String, Object?>?;
      controlConsent = consent?['operatorControl'] == true;
      return _FakeHttpResponse(HttpStatus.ok, <String, Object?>{
        'ok': true,
        'session': <String, Object?>{
          'sessionId': 'foodly-complex-user-session',
          'appId': connectedAppId,
          'appMap': connectedAppMapManifest == null
              ? const <String, Object?>{'status': 'not_reported'}
              : <String, Object?>{
                  'status': 'missing',
                  'manifest': connectedAppMapManifest,
                },
        },
      });
    }
    if (method == 'POST' && path.endsWith('/appmap')) {
      final body = _readJson(text);
      uploadedAppMap = _asJsonMap(body['appMap']);
      return _FakeHttpResponse(HttpStatus.ok, <String, Object?>{
        'ok': true,
        'appMap': <String, Object?>{
          'status': 'available',
          'manifest': body['manifest'],
          'source': 'runtime_bundle',
        },
      });
    }
    if (method == 'POST' && path.endsWith('/snapshot')) {
      final body = _readJson(text);
      latestSnapshot = body['snapshot'] as Map<String, Object?>?;
      return const _FakeHttpResponse(HttpStatus.ok, <String, Object?>{
        'ok': true,
      });
    }
    if (method == 'GET' && path.endsWith('/commands')) {
      final commands = List<Map<String, Object?>>.from(_commands);
      _commands.clear();
      return _FakeHttpResponse(HttpStatus.ok, <String, Object?>{
        'commands': commands,
      });
    }
    if (method == 'POST' && path.endsWith('/results')) {
      final body = _readJson(text);
      results.add(body);
      latestSnapshot = body['snapshot'] as Map<String, Object?>?;
      return const _FakeHttpResponse(HttpStatus.ok, <String, Object?>{
        'ok': true,
      });
    }
    return const _FakeHttpResponse(HttpStatus.notFound, <String, Object?>{});
  }

  Map<String, Object?> _readJson(String text) {
    if (text.trim().isEmpty) return <String, Object?>{};
    return jsonDecode(text) as Map<String, Object?>;
  }

  Map<String, Object?>? _asJsonMap(Object? value) {
    if (value is! Map) return null;
    return value
        .map((key, child) => MapEntry(key.toString(), child as Object?));
  }
}

class _FakeHttpResponse {
  const _FakeHttpResponse(this.statusCode, this.body);

  final int statusCode;
  final Map<String, Object?> body;
}

class _FakeProductionHttpClient implements HttpClient {
  _FakeProductionBackend? backend;
  var closed = false;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final backend = this.backend;
    if (backend == null || closed) {
      throw StateError('Fake production backend is not running');
    }
    return _FakeHttpClientRequest(backend, method, url);
  }

  @override
  void close({bool force = false}) {
    closed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest(this.backend, this.method, this.uri);

  final _FakeProductionBackend backend;
  @override
  final String method;
  @override
  final Uri uri;
  final _FakeHttpHeaders _headers = _FakeHttpHeaders();
  final StringBuffer _body = StringBuffer();

  @override
  HttpHeaders get headers => _headers;

  @override
  void add(List<int> data) {
    _body.write(utf8.decode(data));
  }

  @override
  void write(Object? object) {
    _body.write(object);
  }

  @override
  Future<HttpClientResponse> close() async {
    final response = backend.handle(
      method,
      uri,
      _headers.values,
      _body.toString(),
    );
    return _FakeHttpClientResponse(
      response.statusCode,
      jsonEncode(response.body),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpHeaders implements HttpHeaders {
  final values = <String, String>{};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    values[name.toLowerCase()] = value.toString();
  }

  @override
  String? value(String name) => values[name.toLowerCase()];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _FakeHttpClientResponse(this.statusCode, String body)
      : _bytes = utf8.encode(body);

  @override
  final int statusCode;
  final List<int> _bytes;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable(<List<int>>[_bytes]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<T> _realAsync<T>(
  WidgetTester tester,
  Future<T> Function() callback,
) async {
  final result = await tester.runAsync(callback);
  return result as T;
}
