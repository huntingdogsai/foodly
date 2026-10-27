import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'foodly_domain.dart';

class AuthState {
  const AuthState({
    this.restoring = false,
    this.submitting = false,
    this.session,
    this.error,
  });

  final bool restoring;
  final bool submitting;
  final FoodlySession? session;
  final String? error;

  bool get authenticated => session != null;

  AuthState copyWith({
    bool? restoring,
    bool? submitting,
    FoodlySession? session,
    bool clearSession = false,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      restoring: restoring ?? this.restoring,
      submitting: submitting ?? this.submitting,
      session: clearSession ? null : session ?? this.session,
      error: clearError ? null : error ?? this.error,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'restoring': restoring,
        'submitting': submitting,
        'authenticated': authenticated,
        'user': session?.user.toJson(),
        'tokenStored': session != null,
        'error': error,
      };
}

class ProductSearchState {
  const ProductSearchState({
    this.query = '',
    this.loading = false,
    this.results = const <FoodlyProduct>[],
    this.selected,
    this.quantity = 1,
    this.error,
  });

  final String query;
  final bool loading;
  final List<FoodlyProduct> results;
  final FoodlyProduct? selected;
  final int quantity;
  final String? error;

  ProductSearchState copyWith({
    String? query,
    bool? loading,
    List<FoodlyProduct>? results,
    FoodlyProduct? selected,
    bool clearSelected = false,
    int? quantity,
    String? error,
    bool clearError = false,
  }) {
    return ProductSearchState(
      query: query ?? this.query,
      loading: loading ?? this.loading,
      results: results ?? this.results,
      selected: clearSelected ? null : selected ?? this.selected,
      quantity: quantity ?? this.quantity,
      error: clearError ? null : error ?? this.error,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'query': query,
        'loading': loading,
        'results': results.map((product) => product.toJson()).toList(),
        'selected': selected?.toJson(),
        'quantity': quantity,
        'error': error,
      };
}

class CartState {
  const CartState({
    this.items = const <FoodlyCartItem>[],
    this.submitting = false,
    this.error,
  });

  final List<FoodlyCartItem> items;
  final bool submitting;
  final String? error;

  int get total =>
      items.fold<int>(0, (sum, item) => sum + item.price * item.quantity);

  CartState copyWith({
    List<FoodlyCartItem>? items,
    bool? submitting,
    String? error,
    bool clearError = false,
  }) {
    return CartState(
      items: items ?? this.items,
      submitting: submitting ?? this.submitting,
      error: clearError ? null : error ?? this.error,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'items': items.map((item) => item.toJson()).toList(),
        'total': total,
        'submitting': submitting,
        'error': error,
      };
}

class CheckoutState {
  const CheckoutState({
    this.draft = const FoodlyCheckoutDraft(),
    this.discount = 0,
    this.savingDraft = false,
    this.applyingPromo = false,
    this.submitting = false,
    this.order,
    this.error,
  });

  final FoodlyCheckoutDraft draft;
  final int discount;
  final bool savingDraft;
  final bool applyingPromo;
  final bool submitting;
  final FoodlyOrder? order;
  final String? error;

  int totalFor(int subtotal) => subtotal - discount;

  CheckoutState copyWith({
    FoodlyCheckoutDraft? draft,
    int? discount,
    bool? savingDraft,
    bool? applyingPromo,
    bool? submitting,
    FoodlyOrder? order,
    bool clearOrder = false,
    String? error,
    bool clearError = false,
  }) {
    return CheckoutState(
      draft: draft ?? this.draft,
      discount: discount ?? this.discount,
      savingDraft: savingDraft ?? this.savingDraft,
      applyingPromo: applyingPromo ?? this.applyingPromo,
      submitting: submitting ?? this.submitting,
      order: clearOrder ? null : order ?? this.order,
      error: clearError ? null : error ?? this.error,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'draft': draft.toJson(),
        'discount': discount,
        'savingDraft': savingDraft,
        'applyingPromo': applyingPromo,
        'submitting': submitting,
        'order': order?.toJson(),
        'error': error,
      };
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this.repository) : super(const AuthState());

  final FoodlyRepository repository;

  Future<void> restore() async {
    emit(state.copyWith(restoring: true, clearError: true));
    try {
      final session = await repository.restoreSession();
      if (isClosed) return;
      emit(state.copyWith(
        restoring: false,
        session: session,
        clearSession: session == null,
        clearError: true,
      ));
    } catch (error) {
      if (isClosed) return;
      emit(state.copyWith(
        restoring: false,
        clearSession: true,
        error: error.toString(),
      ));
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    emit(state.copyWith(submitting: true, clearError: true));
    try {
      final session = await repository.signIn(email: email, password: password);
      if (isClosed) return;
      emit(state.copyWith(
        submitting: false,
        session: session,
        clearError: true,
      ));
    } catch (error) {
      if (isClosed) return;
      emit(state.copyWith(
        submitting: false,
        clearSession: true,
        error: error.toString(),
      ));
    }
  }

  Future<void> signOut() async {
    emit(state.copyWith(submitting: true, clearError: true));
    await repository.signOut();
    emit(const AuthState());
  }
}

class ProductSearchCubit extends Cubit<ProductSearchState> {
  ProductSearchCubit(this.repository) : super(const ProductSearchState());

  final FoodlyRepository repository;

  Future<void> search(String query) async {
    emit(state.copyWith(
      query: query,
      loading: true,
      clearSelected: true,
      quantity: 1,
      clearError: true,
    ));
    try {
      final results = await repository.searchProducts(query);
      if (isClosed) return;
      emit(state.copyWith(
        loading: false,
        results: results,
        clearSelected: true,
        clearError: true,
      ));
    } catch (error) {
      if (isClosed) return;
      emit(state.copyWith(
        loading: false,
        results: const <FoodlyProduct>[],
        error: error.toString(),
      ));
    }
  }

  void selectProduct(FoodlyProduct product) {
    if (!product.inStock) return;
    emit(state.copyWith(selected: product, quantity: 1, clearError: true));
  }

  bool selectByName(String name) {
    final match = state.results
        .where((product) => product.name.toLowerCase() == name.toLowerCase())
        .firstOrNull;
    if (match == null || !match.inStock) return false;
    selectProduct(match);
    return true;
  }

  void setQuantity(int quantity) {
    emit(state.copyWith(quantity: quantity < 1 ? 1 : quantity));
  }
}

class CartCubit extends Cubit<CartState> {
  CartCubit(this.repository) : super(const CartState());

  final FoodlyRepository repository;

  Future<void> addProduct({
    required FoodlyProduct product,
    required int quantity,
  }) async {
    emit(state.copyWith(submitting: true, clearError: true));
    try {
      final items = await repository.addToCart(
        product: product,
        quantity: quantity,
      );
      if (isClosed) return;
      emit(state.copyWith(
        items: items,
        submitting: false,
        clearError: true,
      ));
    } catch (error) {
      if (isClosed) return;
      emit(state.copyWith(submitting: false, error: error.toString()));
    }
  }
}

class CheckoutCubit extends Cubit<CheckoutState> {
  CheckoutCubit(this.repository) : super(const CheckoutState());

  final FoodlyRepository repository;

  void updateFullName(String value) =>
      _updateDraft(state.draft.copyWith(fullName: value));

  void updateEmail(String value) =>
      _updateDraft(state.draft.copyWith(email: value));

  void updatePhone(String value) =>
      _updateDraft(state.draft.copyWith(phone: value));

  void updateAddress(String value) =>
      _updateDraft(state.draft.copyWith(address: value));

  void updateDeliveryInstructions(String value) =>
      _updateDraft(state.draft.copyWith(deliveryInstructions: value));

  void updateDeliveryWindow(String value) =>
      _updateDraft(state.draft.copyWith(deliveryWindow: value));

  void updatePaymentMethod(String value) =>
      _updateDraft(state.draft.copyWith(paymentMethod: value));

  void updatePromoCode(String value) =>
      _updateDraft(state.draft.copyWith(promoCode: value));

  void updateSaveAddress(bool value) =>
      _updateDraft(state.draft.copyWith(saveAddress: value));

  void applySessionDefaults(FoodlySession session) {
    final draft = state.draft.copyWith(
      fullName: state.draft.fullName.trim().isEmpty
          ? session.user.name
          : state.draft.fullName,
      email: state.draft.email.trim().isEmpty
          ? session.user.email
          : state.draft.email,
    );
    _updateDraft(draft);
  }

  Future<void> applyPromo(int subtotal) async {
    emit(state.copyWith(applyingPromo: true, clearError: true));
    try {
      final discount = await repository.applyPromoCode(
        code: state.draft.promoCode,
        subtotal: subtotal,
      );
      if (isClosed) return;
      emit(state.copyWith(
        discount: discount,
        applyingPromo: false,
        clearError: true,
      ));
    } catch (error) {
      if (isClosed) return;
      emit(state.copyWith(applyingPromo: false, error: error.toString()));
    }
  }

  Future<void> submitOrder({
    required FoodlySession session,
    required List<FoodlyCartItem> items,
  }) async {
    emit(state.copyWith(submitting: true, clearError: true, clearOrder: true));
    try {
      final order = await repository.submitOrder(
        session: session,
        items: items,
        draft: state.draft,
        discount: state.discount,
      );
      if (isClosed) return;
      emit(state.copyWith(
        submitting: false,
        order: order,
        clearError: true,
      ));
    } catch (error) {
      if (isClosed) return;
      emit(state.copyWith(submitting: false, error: error.toString()));
    }
  }

  void _updateDraft(FoodlyCheckoutDraft draft) {
    emit(state.copyWith(draft: draft, savingDraft: true, clearError: true));
    unawaited(_persistDraft(draft));
  }

  Future<void> _persistDraft(FoodlyCheckoutDraft draft) async {
    try {
      await repository.saveCheckoutDraft(draft);
      if (!isClosed) emit(state.copyWith(savingDraft: false));
    } catch (error) {
      if (!isClosed) {
        emit(state.copyWith(savingDraft: false, error: error.toString()));
      }
    }
  }
}

class FoodlyCoordinator {
  FoodlyCoordinator({
    required this.auth,
    required this.search,
    required this.cart,
    required this.checkout,
  });

  final AuthCubit auth;
  final ProductSearchCubit search;
  final CartCubit cart;
  final CheckoutCubit checkout;

  Future<bool> addSelectedToCart() async {
    final product = search.state.selected;
    if (product == null) return false;
    await cart.addProduct(
      product: product,
      quantity: search.state.quantity,
    );
    return cart.state.error == null;
  }

  Future<bool> placeOrder() async {
    final session = auth.state.session;
    if (session == null) return false;
    await checkout.submitOrder(session: session, items: cart.state.items);
    return checkout.state.order != null;
  }
}
