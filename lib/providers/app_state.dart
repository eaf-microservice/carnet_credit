import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:async';
import '../models/models.dart';

class AppState extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  AppUser? _currentUser;
  List<AppUser> _allUsers = [];
  List<LedgerItem> _availableItems = [];
  List<LedgerTransaction> _transactions = [];

  StreamSubscription? _usersSub;
  StreamSubscription? _itemsSub;
  StreamSubscription? _txSub;

  AppState() {
    _init();
  }

  void _init() {
    _auth.authStateChanges().listen((User? user) async {
      if (user == null) {
        _currentUser = null;
        _cancelSubscriptions();
        notifyListeners();
      } else {
        await _fetchCurrentUser(user.uid);
        _startSubscriptions();
      }
    });
  }

  void _cancelSubscriptions() {
    _usersSub?.cancel();
    _itemsSub?.cancel();
    _txSub?.cancel();
  }

  void _startSubscriptions() {
    _cancelSubscriptions();

    // Sync Users
    _usersSub = _firestore.collection('users').snapshots().listen((snap) {
      _allUsers = snap.docs.map((doc) => AppUser.fromMap(doc.data())).toList();
      notifyListeners();
    });

    // Sync Items
    _itemsSub = _firestore.collection('items').snapshots().listen((snap) {
      _availableItems = snap.docs
          .map((doc) => LedgerItem.fromMap(doc.data()))
          .toList();
      notifyListeners();
    });

    // Sync Transactions
    _txSub = _firestore.collection('transactions').snapshots().listen((snap) {
      _transactions = snap.docs
          .map((doc) => LedgerTransaction.fromMap(doc.data()))
          .toList();
      notifyListeners();
    });
  }

  Future<void> _fetchCurrentUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      _currentUser = AppUser.fromMap(doc.data()!);
      notifyListeners();
    }
  }

  // Getters
  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  List<AppUser> getCustomersForShop(String shopId) {
    return _allUsers
        .where(
          (u) =>
              u.role == UserRole.customer && u.shopBalances.containsKey(shopId),
        )
        .toList();
  }

  List<LedgerItem> get availableItems => _availableItems;
  List<LedgerTransaction> get transactions => [..._transactions];

  AppUser? getCustomerById(String id) => _allUsers.cast<AppUser?>().firstWhere(
    (u) => u?.id == id,
    orElse: () => null,
  );

  AppUser? getShopById(String id) => _allUsers.cast<AppUser?>().firstWhere(
    (u) => u?.id == id && u?.role == UserRole.shopOwner,
    orElse: () => null,
  );

  List<LedgerTransaction> getTransactionsForCustomer(String customerId) {
    return _transactions.where((t) => t.customerId == customerId).toList();
  }

  // Actions
  Future<void> register(
    String email,
    String password,
    String name,
    UserRole role,
  ) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = AppUser(id: cred.user!.uid, name: name, role: role);
    await _firestore.collection('users').doc(user.id).set(user.toMap());
  }

  Future<void> login(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final cred = await _auth.signInWithCredential(credential);

    // Check if user exists in Firestore, if not create
    final doc = await _firestore.collection('users').doc(cred.user!.uid).get();
    if (!doc.exists) {
      final newUser = AppUser(
        id: cred.user!.uid,
        name: googleUser.displayName ?? 'مستخدم جوجل',
        role: UserRole.customer, // Default to customer
      );
      await _firestore.collection('users').doc(newUser.id).set(newUser.toMap());
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  Future<void> linkCustomerToShop(String customerId, String shopId) async {
    final customer = getCustomerById(customerId);
    if (customer != null && !customer.shopBalances.containsKey(shopId)) {
      customer.shopBalances[shopId] = 0.0;
      await _firestore.collection('users').doc(customerId).update({
        'shopBalances': customer.shopBalances,
      });
    }
  }

  Future<void> addPurchase(
    String customerId,
    String shopId,
    List<LedgerItem> items,
  ) async {
    if (items.isEmpty) return;
    final customer = getCustomerById(customerId);
    if (customer == null) return;

    double total = items.fold(0, (sum, item) => sum + item.price);
    final tx = LedgerTransaction(
      customerId: customerId,
      shopId: shopId,
      items: items,
      totalAmount: total,
      date: DateTime.now(),
    );

    await _firestore.collection('transactions').doc(tx.id).set(tx.toMap());

    // Update balance
    customer.shopBalances[shopId] =
        (customer.shopBalances[shopId] ?? 0) + total;
    await _firestore.collection('users').doc(customerId).update({
      'shopBalances': customer.shopBalances,
    });
  }

  Future<void> deleteTransaction(String transactionId) async {
    final txIndex = _transactions.indexWhere((t) => t.id == transactionId);
    if (txIndex == -1) return;

    final tx = _transactions[txIndex];
    final customer = getCustomerById(tx.customerId);

    if (customer != null) {
      customer.shopBalances[tx.shopId] =
          (customer.shopBalances[tx.shopId] ?? 0) - tx.totalAmount;
      if (customer.shopBalances[tx.shopId]! < 0)
        customer.shopBalances[tx.shopId] = 0;

      await _firestore.collection('users').doc(tx.customerId).update({
        'shopBalances': customer.shopBalances,
      });
    }

    await _firestore.collection('transactions').doc(transactionId).delete();
  }

  Future<void> updateTransactionItemTotalPrice(
    String transactionId,
    String itemId,
    double newPrice,
  ) async {
    // Re-implementing logic for Firestore
    final txIndex = _transactions.indexWhere((t) => t.id == transactionId);
    if (txIndex == -1) return;

    final tx = _transactions[txIndex];
    final itemIndex = tx.items.indexWhere((i) => i.id == itemId);
    if (itemIndex == -1) return;

    final oldItem = tx.items[itemIndex];
    final priceDiff = newPrice - oldItem.price;

    final newItem = LedgerItem(
      id: oldItem.id,
      name: oldItem.name,
      price: newPrice,
      iconName: oldItem.iconName,
    );

    tx.items[itemIndex] = newItem;
    final newTotal = tx.totalAmount + priceDiff;

    await _firestore.collection('transactions').doc(transactionId).update({
      'items': tx.items.map((i) => i.toMap()).toList(),
      'totalAmount': newTotal,
    });

    final customer = getCustomerById(tx.customerId);
    if (customer != null) {
      customer.shopBalances[tx.shopId] =
          (customer.shopBalances[tx.shopId] ?? 0) + priceDiff;
      await _firestore.collection('users').doc(tx.customerId).update({
        'shopBalances': customer.shopBalances,
      });
    }
  }
}
