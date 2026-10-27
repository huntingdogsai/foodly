import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:huntingdogs/huntingdogs.dart';

import 'src/foodly_cubits.dart';
import 'src/foodly_domain.dart';

const String _foodlyApiBaseUrl = String.fromEnvironment(
  'FOODLY_API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8787',
);
const String _operatorEndpoint = String.fromEnvironment('OPERATOR_ENDPOINT');
const String _operatorSessionId = String.fromEnvironment(
  'OPERATOR_SESSION_ID',
  defaultValue: 'foodly-demo-session',
);
const String _operatorUserId = String.fromEnvironment(
  'OPERATOR_USER_ID',
  defaultValue: 'demo-user',
);
const String _operatorDeviceId = String.fromEnvironment(
  'OPERATOR_DEVICE_ID',
  defaultValue: 'flutter-foodly-demo',
);
const String _operatorSessionSecret =
    String.fromEnvironment('OPERATOR_SESSION_SECRET');
const String _operatorToken = String.fromEnvironment('OPERATOR_CONTROL_TOKEN');
const bool _operatorControlConsent = bool.fromEnvironment(
  'OPERATOR_CONTROL_CONSENT',
  defaultValue: true,
);
const int _operatorPollWaitMs = int.fromEnvironment(
  'OPERATOR_POLL_WAIT_MS',
  defaultValue: 1000,
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(OperatorAppHost(
    config: const OperatorFlutterConfig(
      appId: 'foodly-production-demo',
      name: 'Foodly Production Demo',
      environment: OperatorEnvironment.dev,
    ),
    production: _productionConfig,
    child: const FoodlyProductionApp(),
  ));
}

OperatorProductionSessionConfig? get _productionConfig {
  if (_operatorEndpoint.isEmpty) return null;
  return OperatorProductionSessionConfig(
    endpoint: Uri.parse(_operatorEndpoint),
    sessionId: _operatorSessionId,
    appId: 'foodly-production-demo',
    userId: _operatorUserId,
    deviceId: _operatorDeviceId,
    sessionSecret:
        _operatorSessionSecret.isEmpty ? null : _operatorSessionSecret,
    token: _operatorToken.isEmpty ? null : _operatorToken,
    operatorControlConsent: _operatorControlConsent,
    pollWait: Duration(milliseconds: _operatorPollWaitMs),
  );
}

class FoodlyProductionApp extends StatefulWidget {
  const FoodlyProductionApp({super.key, this.apiBaseUrl});

  final String? apiBaseUrl;

  @override
  State<FoodlyProductionApp> createState() => _FoodlyProductionAppState();
}

class _FoodlyProductionAppState extends State<FoodlyProductionApp> {
  late final FoodlyRepository _repository;
  late final AuthCubit _authCubit;
  late final ProductSearchCubit _searchCubit;
  late final CartCubit _cartCubit;
  late final CheckoutCubit _checkoutCubit;
  late final FavouritesCubit _favouritesCubit;
  late final FoodlyCoordinator _coordinator;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _repository = FoodlyRestRepository(
      baseUrl: Uri.parse(widget.apiBaseUrl ?? _foodlyApiBaseUrl),
    );
    _authCubit = AuthCubit(_repository);
    _searchCubit = ProductSearchCubit(_repository);
    _cartCubit = CartCubit(_repository);
    _checkoutCubit = CheckoutCubit(_repository);
    _favouritesCubit = FavouritesCubit(_repository);
    _coordinator = FoodlyCoordinator(
      auth: _authCubit,
      search: _searchCubit,
      cart: _cartCubit,
      checkout: _checkoutCubit,
    );
    _router = _createRouter();
    unawaited(_authCubit.restore());
    unawaited(_searchCubit.search(''));
  }

  @override
  void dispose() {
    _router.dispose();
    unawaited(_authCubit.close());
    unawaited(_searchCubit.close());
    unawaited(_cartCubit.close());
    unawaited(_checkoutCubit.close());
    unawaited(_favouritesCubit.close());
    super.dispose();
  }

  GoRouter _createRouter() {
    return GoRouter(
      initialLocation: '/sign-in',
      routes: <RouteBase>[
        GoRoute(
          path: '/sign-in',
          builder: (context, state) => const _SignInScreen(),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => _FoodlyScaffold(
            path: state.uri.path,
            child: const _HomeScreen(),
          ),
        ),
        GoRoute(
          path: '/search',
          builder: (context, state) => _FoodlyScaffold(
            path: state.uri.path,
            child: const _SearchScreen(),
          ),
        ),
        GoRoute(
          path: '/checkout',
          builder: (context, state) => _FoodlyScaffold(
            path: state.uri.path,
            child: const _CheckoutScreen(),
          ),
        ),
        GoRoute(
          path: '/account',
          builder: (context, state) => _FoodlyScaffold(
            path: state.uri.path,
            child: const _AccountScreen(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: <RepositoryProvider<dynamic>>[
        RepositoryProvider<FoodlyRepository>.value(value: _repository),
        RepositoryProvider<FoodlyCoordinator>.value(value: _coordinator),
      ],
      child: MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<AuthCubit>.value(value: _authCubit),
          BlocProvider<ProductSearchCubit>.value(value: _searchCubit),
          BlocProvider<CartCubit>.value(value: _cartCubit),
          BlocProvider<CheckoutCubit>.value(value: _checkoutCubit),
          BlocProvider<FavouritesCubit>.value(value: _favouritesCubit),
        ],
        child: BlocListener<AuthCubit, AuthState>(
          listenWhen: (previous, current) =>
              previous.session?.user.id != current.session?.user.id,
          listener: (context, state) => unawaited(
            _favouritesCubit.restore(state.session?.user.id),
          ),
          child: MaterialApp.router(
            title: 'Foodly',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xff12664f),
              ),
              useMaterial3: true,
            ),
            routerConfig: _router,
          ),
        ),
      ),
    );
  }
}

class _SignInScreen extends StatefulWidget {
  const _SignInScreen();

  @override
  State<_SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<_SignInScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Foodly')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text('Sign in', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            BlocConsumer<AuthCubit, AuthState>(
              listener: (context, state) {
                final session = state.session;
                if (session != null) {
                  context.read<CheckoutCubit>().applySessionDefaults(session);
                  context.go('/');
                }
              },
              builder: (context, state) {
                return FilledButton(
                  onPressed: state.submitting
                      ? null
                      : () => unawaited(context.read<AuthCubit>().signIn(
                            email: _emailController.text,
                            password: _passwordController.text,
                          )),
                  child: Text(state.submitting ? 'Signing in' : 'Sign in'),
                );
              },
            ),
            BlocBuilder<AuthCubit, AuthState>(
              builder: (context, state) {
                if (state.error == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    state.error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodlyScaffold extends StatelessWidget {
  const _FoodlyScaffold({
    required this.path,
    required this.child,
  });

  final String path;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Foodly'),
        actions: <Widget>[
          BlocBuilder<AuthCubit, AuthState>(
            builder: (context, state) {
              if (!state.authenticated) {
                return TextButton(
                  onPressed: () => context.go('/sign-in'),
                  child: const Text('Sign in'),
                );
              }
              return TextButton(
                onPressed: () => context.go('/account'),
                child: Text(state.session!.user.name),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            NavigationBar(
              selectedIndex: _selectedIndex(path),
              onDestinationSelected: (index) {
                context.go(
                    <String>['/', '/search', '/checkout', '/account'][index]);
              },
              destinations: const <NavigationDestination>[
                NavigationDestination(
                  icon: Icon(Icons.storefront_outlined),
                  selectedIcon: Icon(Icons.storefront),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.search),
                  label: 'Search',
                ),
                NavigationDestination(
                  icon: Icon(Icons.shopping_cart_outlined),
                  selectedIcon: Icon(Icons.shopping_cart),
                  label: 'Checkout',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Account',
                ),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

class _HomeScreen extends StatelessWidget {
  const _HomeScreen();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductSearchCubit, ProductSearchState>(
      builder: (context, products) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            BlocBuilder<AuthCubit, AuthState>(
              builder: (context, state) {
                final name = state.session?.user.name ?? 'Guest';
                final tier = state.session?.user.loyaltyTier ?? 'Visitor';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Welcome, $name'),
                  subtitle: Text('Loyalty tier: $tier'),
                  trailing: state.authenticated
                      ? null
                      : FilledButton(
                          onPressed: () => context.go('/sign-in'),
                          child: const Text('Sign in'),
                        ),
                );
              },
            ),
            const SizedBox(height: 12),
            const _FavouritesSection(),
            const SizedBox(height: 20),
            Text('Products', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (products.loading) const LinearProgressIndicator(),
            if (products.error != null)
              Text(
                products.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            for (final product in products.results)
              _ProductTile(product: product),
          ],
        );
      },
    );
  }
}

class _FavouritesSection extends StatelessWidget {
  const _FavouritesSection();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FavouritesCubit, FavouritesState>(
      builder: (context, favourites) {
        return BlocBuilder<ProductSearchCubit, ProductSearchState>(
          builder: (context, products) {
            // A favourite shows as the product is today when the list has it.
            final current = <String, FoodlyProduct>{
              for (final product in products.results) product.id: product,
            };
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Favourites',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (favourites.loading) const LinearProgressIndicator(),
                if (favourites.error != null)
                  Text(
                    favourites.error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                if (!favourites.signedIn)
                  const Text('Sign in to keep favourites.')
                else if (favourites.items.isEmpty)
                  const Text(
                      'No favourites yet: tap a heart to keep a product here.')
                else
                  for (final product in favourites.items)
                    _ProductTile(product: current[product.id] ?? product),
              ],
            );
          },
        );
      },
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product});

  final FoodlyProduct product;

  @override
  Widget build(BuildContext context) {
    final searchCubit = context.read<ProductSearchCubit>();
    return BlocBuilder<FavouritesCubit, FavouritesState>(
      builder: (context, favourites) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading:
              favourites.signedIn ? _FavouriteButton(product: product) : null,
          title: Text(product.name),
          subtitle: Text('${product.category} · NGN ${product.price}'),
          trailing: FilledButton(
            onPressed: product.inStock
                ? () {
                    context.go('/search');
                    unawaited(searchCubit.search(product.name));
                  }
                : null,
            child: Text(product.inStock ? 'Find' : 'Sold out'),
          ),
        );
      },
    );
  }
}

class _FavouriteButton extends StatelessWidget {
  const _FavouriteButton({required this.product});

  final FoodlyProduct product;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FavouritesCubit, FavouritesState>(
      builder: (context, favourites) {
        final favourite = favourites.contains(product.id);
        return IconButton(
          tooltip: favourite ? 'Remove from favourites' : 'Add to favourites',
          icon: Icon(favourite ? Icons.favorite : Icons.favorite_border),
          color: favourite ? Theme.of(context).colorScheme.primary : null,
          onPressed: () =>
              unawaited(context.read<FavouritesCubit>().toggle(product)),
        );
      },
    );
  }
}

class _SearchScreen extends StatefulWidget {
  const _SearchScreen();

  @override
  State<_SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<_SearchScreen> {
  late final TextEditingController _searchController;
  late final TextEditingController _quantityController;

  @override
  void initState() {
    super.initState();
    final state = context.read<ProductSearchCubit>().state;
    _searchController = TextEditingController(text: state.query);
    _quantityController = TextEditingController(text: '${state.quantity}');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProductSearchCubit, ProductSearchState>(
      listener: (context, state) {
        _replaceControllerText(_searchController, state.query);
        _replaceControllerText(_quantityController, '${state.quantity}');
      },
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Search', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search products',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => unawaited(
                context.read<ProductSearchCubit>().search(value),
              ),
            ),
            const SizedBox(height: 12),
            if (state.loading) const LinearProgressIndicator(),
            for (final product in state.results)
              ListTile(
                contentPadding: EdgeInsets.zero,
                selected: state.selected?.id == product.id,
                title: Text(product.name),
                subtitle: Text(
                  '${product.category} · ${product.inStock ? 'In stock' : 'Out of stock'}',
                ),
                trailing: Text('NGN ${product.price}'),
                onTap: product.inStock
                    ? () => context.read<ProductSearchCubit>().selectProduct(
                          product,
                        )
                    : null,
              ),
            if (state.selected != null) ...<Widget>[
              const SizedBox(height: 12),
              TextField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => context
                    .read<ProductSearchCubit>()
                    .setQuantity(int.tryParse(value) ?? 1),
              ),
              const SizedBox(height: 12),
              BlocBuilder<CartCubit, CartState>(
                builder: (context, cart) {
                  return FilledButton.icon(
                    onPressed: cart.submitting
                        ? null
                        : () => unawaited(
                              context
                                  .read<FoodlyCoordinator>()
                                  .addSelectedToCart(),
                            ),
                    icon: const Icon(Icons.add_shopping_cart),
                    label: Text(cart.submitting ? 'Adding' : 'Add to cart'),
                  );
                },
              ),
            ],
            const SizedBox(height: 20),
            const _CartSummary(),
          ],
        );
      },
    );
  }
}

class _CheckoutScreen extends StatelessWidget {
  const _CheckoutScreen();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, auth) {
        if (!auth.authenticated) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Checkout', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('Sign in to continue checkout.'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => context.go('/sign-in'),
                child: const Text('Sign in'),
              ),
            ],
          );
        }
        return const _CheckoutForm();
      },
    );
  }
}

class _CheckoutForm extends StatefulWidget {
  const _CheckoutForm();

  @override
  State<_CheckoutForm> createState() => _CheckoutFormState();
}

class _CheckoutFormState extends State<_CheckoutForm> {
  late final TextEditingController _fullNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _instructionsController;
  late final TextEditingController _promoController;

  @override
  void initState() {
    super.initState();
    final draft = context.read<CheckoutCubit>().state.draft;
    _fullNameController = TextEditingController(text: draft.fullName);
    _emailController = TextEditingController(text: draft.email);
    _phoneController = TextEditingController(text: draft.phone);
    _addressController = TextEditingController(text: draft.address);
    _instructionsController =
        TextEditingController(text: draft.deliveryInstructions);
    _promoController = TextEditingController(text: draft.promoCode);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _instructionsController.dispose();
    _promoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CheckoutCubit, CheckoutState>(
      listener: (context, state) {
        _replaceControllerText(_fullNameController, state.draft.fullName);
        _replaceControllerText(_emailController, state.draft.email);
        _replaceControllerText(_phoneController, state.draft.phone);
        _replaceControllerText(_addressController, state.draft.address);
        _replaceControllerText(
          _instructionsController,
          state.draft.deliveryInstructions,
        );
        _replaceControllerText(_promoController, state.draft.promoCode);
      },
      builder: (context, checkout) {
        return BlocBuilder<CartCubit, CartState>(
          builder: (context, cart) {
            final subtotal = cart.total;
            final total = checkout.totalFor(subtotal);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Checkout', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const _CartSummary(),
                const SizedBox(height: 16),
                Text('Delivery details',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: context.read<CheckoutCubit>().updateFullName,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Receipt email',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: context.read<CheckoutCubit>().updateEmail,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: context.read<CheckoutCubit>().updatePhone,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Delivery address',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: context.read<CheckoutCubit>().updateAddress,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _instructionsController,
                  decoration: const InputDecoration(
                    labelText: 'Delivery instructions',
                    border: OutlineInputBorder(),
                  ),
                  onChanged:
                      context.read<CheckoutCubit>().updateDeliveryInstructions,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: checkout.draft.deliveryWindow,
                  decoration: const InputDecoration(
                    labelText: 'Delivery window',
                    border: OutlineInputBorder(),
                  ),
                  items: const <String>[
                    'Today 6-8 PM',
                    'Tomorrow 9-11 AM',
                    'Tomorrow 2-4 PM',
                  ]
                      .map((value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      context.read<CheckoutCubit>().updateDeliveryWindow(value);
                    }
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: checkout.draft.paymentMethod,
                  decoration: const InputDecoration(
                    labelText: 'Payment method',
                    border: OutlineInputBorder(),
                  ),
                  items: const <String>[
                    'Card on delivery',
                    'Wallet balance',
                    'Bank transfer',
                  ]
                      .map((value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      context.read<CheckoutCubit>().updatePaymentMethod(value);
                    }
                  },
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Save address'),
                  value: checkout.draft.saveAddress,
                  onChanged: (value) => context
                      .read<CheckoutCubit>()
                      .updateSaveAddress(value ?? false),
                ),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _promoController,
                        decoration: const InputDecoration(
                          labelText: 'Promo code',
                          border: OutlineInputBorder(),
                        ),
                        onChanged:
                            context.read<CheckoutCubit>().updatePromoCode,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: checkout.applyingPromo
                          ? null
                          : () => unawaited(
                                context
                                    .read<CheckoutCubit>()
                                    .applyPromo(subtotal),
                              ),
                      child: Text(
                        checkout.applyingPromo ? 'Applying' : 'Apply promo',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _CheckoutTotals(
                  subtotal: subtotal,
                  discount: checkout.discount,
                  total: total,
                ),
                if (checkout.error != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    checkout.error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                if (checkout.order != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text('Order ${checkout.order!.id} confirmed'),
                ],
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: checkout.submitting || cart.items.isEmpty
                      ? null
                      : () => unawaited(
                            context.read<FoodlyCoordinator>().placeOrder(),
                          ),
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(
                    checkout.submitting ? 'Placing order' : 'Place order',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _CheckoutTotals extends StatelessWidget {
  const _CheckoutTotals({
    required this.subtotal,
    required this.discount,
    required this.total,
  });

  final int subtotal;
  final int discount;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Align(
          alignment: Alignment.centerRight,
          child: Text('Subtotal NGN $subtotal'),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Text('Discount NGN $discount'),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Total NGN $total',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ],
    );
  }
}

class _AccountScreen extends StatelessWidget {
  const _AccountScreen();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        if (!state.authenticated) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('No active session.'),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => context.go('/sign-in'),
                child: const Text('Sign in'),
              ),
            ],
          );
        }
        final user = state.session!.user;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Account', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(user.name),
              subtitle: Text('${user.email} · ${user.loyaltyTier}'),
            ),
            FilledButton(
              onPressed: () => unawaited(context.read<AuthCubit>().signOut()),
              child: const Text('Sign out'),
            ),
          ],
        );
      },
    );
  }
}

class _CartSummary extends StatelessWidget {
  const _CartSummary();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Cart', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (state.items.isEmpty)
              const Text('Cart is empty.')
            else
              for (final item in state.items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.name),
                  subtitle: Text('Quantity ${item.quantity}'),
                  trailing: Text('NGN ${item.price * item.quantity}'),
                ),
            const Divider(),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Cart total NGN ${state.total}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        );
      },
    );
  }
}

int _selectedIndex(String path) {
  return switch (path) {
    '/search' => 1,
    '/checkout' => 2,
    '/account' => 3,
    _ => 0,
  };
}

void _replaceControllerText(TextEditingController controller, String value) {
  if (controller.text == value) return;
  controller.value = TextEditingValue(
    text: value,
    selection: TextSelection.collapsed(offset: value.length),
  );
}
