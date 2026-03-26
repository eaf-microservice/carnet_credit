import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import '../models/models.dart';

class AppState extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '1062617118772-hs0bu2lnt6s7t33to3og2lbivc38juru.apps.googleusercontent.com',
  );

  AppUser? _currentUser;
  bool _needsRoleSelection = false;
  List<AppUser> _allUsers = [];
  List<LedgerItem> _availableItems = [];
  List<LedgerTransaction> _transactions = [];
  CurrencyMode _currencyMode = CurrencyMode.dirham;

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

    // Sync Users — also keep _currentUser fresh in real-time
    _usersSub = _firestore.collection('users').snapshots().listen((snap) {
      _allUsers = snap.docs.map((doc) => AppUser.fromMap(doc.data())).toList();
      // Keep _currentUser in sync with its Firestore document
      if (_currentUser != null) {
        final updated = _allUsers.cast<AppUser?>().firstWhere(
          (u) => u?.id == _currentUser!.id,
          orElse: () => null,
        );
        if (updated != null) _currentUser = updated;
      }
      notifyListeners();
    }, onError: (e) => debugPrint('Error fetching users: $e'));

    // Sync Items
    _itemsSub = _firestore.collection('items').snapshots().listen((snap) {
      _availableItems = snap.docs
          .map((doc) => LedgerItem.fromMap(doc.data()))
          .toList();
      notifyListeners();
    }, onError: (e) => debugPrint('Error fetching items: $e'));

    // Sync Transactions
    _txSub = _firestore.collection('transactions').snapshots().listen((snap) {
      _transactions = snap.docs
          .map((doc) => LedgerTransaction.fromMap(doc.data()))
          .toList();
      notifyListeners();
    }, onError: (e) => debugPrint('Error fetching transactions: $e'));
  }

  Future<void> _fetchCurrentUser(String uid) async {
    try {
      debugPrint('Fetching user data for: $uid');
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        debugPrint('User data found: $data');
        _currentUser = AppUser.fromMap(data);
        debugPrint('AppUser object created for: ${_currentUser?.name}');
        notifyListeners();
      } else {
        debugPrint('User document does not exist in Firestore for: $uid');
      }
    } catch (e, stack) {
      debugPrint('CRITICAL ERROR fetching current user: $e');
      debugPrint(stack.toString());
    }
  }

  // Getters
  AppUser? get currentUser => _currentUser;
  bool get needsRoleSelection => _needsRoleSelection;

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
  bool get isLoggedIn => _auth.currentUser != null;
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;
  CurrencyMode get currencyMode => _currentUser?.currencyMode ?? _currencyMode;

  Future<void> setCurrencyMode(CurrencyMode mode) async {
    _currencyMode = mode;
    if (_currentUser != null) {
      await _firestore.collection('users').doc(_currentUser!.id).update({
        'currencyMode': mode.name,
      });
    }
    notifyListeners();
  }

  String formatCurrency(double amount) {
    if (currencyMode == CurrencyMode.rial) {
      return '${(amount * 20).toStringAsFixed(0)} ريال';
    }
    return '${amount.toStringAsFixed(2)} درهم';
  }

  double convertToDirham(double value) {
    if (currencyMode == CurrencyMode.rial) {
      return value / 20.0;
    }
    return value;
  }

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
    UserRole role, {
    String? phone,
    String? address,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    
    // Send verification email
    await cred.user!.sendEmailVerification();

    final user = AppUser(
      id: cred.user!.uid,
      name: name,
      role: role,
      phone: phone,
      address: address,
      shopId: role == UserRole.shopOwner ? cred.user!.uid : null,
    );
    await _firestore.collection('users').doc(user.id).set(user.toMap());
  }

  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
    notifyListeners();
  }

  Future<void> resendVerificationEmail() async {
    await _auth.currentUser?.sendEmailVerification();
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
    final userUid = cred.user!.uid;

    // Check if user exists in Firestore
    final doc = await _firestore.collection('users').doc(userUid).get();
    if (!doc.exists) {
      _needsRoleSelection = true;
      notifyListeners();
    } else {
      _needsRoleSelection = false;
      await _fetchCurrentUser(userUid);
    }
  }

  Future<void> completeGoogleSignIn(UserRole role) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final newUser = AppUser(
      id: user.uid,
      name: user.displayName ?? 'مستخدم جوجل',
      role: role,
      phone: user.phoneNumber, // Capture phone from Google/Firebase if available
      shopId: role == UserRole.shopOwner ? user.uid : null,
      profileImageUrl: user.photoURL,
    );

    await _firestore.collection('users').doc(user.uid).set(newUser.toMap());
    _needsRoleSelection = false;
    await _fetchCurrentUser(user.uid);
  }

  Future<void> updateProfile({
    String? name,
    String? phone,
    String? address,
    String? profileImageUrl,
  }) async {
    if (_currentUser == null) return;

    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (phone != null) updates['phone'] = phone;
    if (address != null) updates['address'] = address;
    if (profileImageUrl != null) updates['profileImageUrl'] = profileImageUrl;

    if (updates.isEmpty) return;

    await _firestore.collection('users').doc(_currentUser!.id).update(updates);
    // Real-time listener will pick up the change and update _currentUser
  }

  Future<void> deactivateAccount() async {
    if (_currentUser == null) return;

    await _firestore.collection('users').doc(_currentUser!.id).update({
      'isDeactivated': true,
    });
    await logout();
  }

  Future<void> logout() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  Future<void> addManualCustomer(String name, String shopId, {String? nickname, String? phone}) async {
    // Generate a unique ID for the manual customer
    final customerId = 'manual_${const Uuid().v4()}';
    final customer = AppUser(
      id: customerId,
      name: name,
      role: UserRole.customer,
      phone: phone,
      shopBalances: {shopId: 0.0},
      shopNicknames: nickname != null ? {shopId: nickname} : {},
    );
    
    await _firestore.collection('users').doc(customerId).set(customer.toMap());
  }

  Future<void> setCustomerNickname(String customerId, String shopId, String nickname) async {
    final customer = getCustomerById(customerId);
    if (customer == null) return;

    customer.shopNicknames[shopId] = nickname;
    await _firestore.collection('users').doc(customerId).update({
      'shopNicknames': customer.shopNicknames,
    });
  }

  Future<void> linkManualCustomerToReal(
    String manualId,
    String realId,
    String shopId,
  ) async {
    final manualUser = getCustomerById(manualId);
    final realUser = getCustomerById(realId);

    if (manualUser == null || realUser == null) return;

    final batch = _firestore.batch();

    // 1. Move balance
    final manualBalance = manualUser.shopBalances[shopId] ?? 0.0;
    realUser.shopBalances[shopId] =
        (realUser.shopBalances[shopId] ?? 0.0) + manualBalance;

    // 2. Set the manual name as nickname for the real user
    realUser.shopNicknames[shopId] = manualUser.name;

    batch.update(_firestore.collection('users').doc(realId), {
      'shopBalances': realUser.shopBalances,
      'shopNicknames': realUser.shopNicknames,
    });

    // 3. Update all transactions from manualId to realId for this shop
    final txDocs = await _firestore
        .collection('transactions')
        .where('customerId', isEqualTo: manualId)
        .where('shopId', isEqualTo: shopId)
        .get();

    for (final doc in txDocs.docs) {
      batch.update(doc.reference, {'customerId': realId});
    }

    // 4. Delete manual user
    batch.delete(_firestore.collection('users').doc(manualId));

    await batch.commit();
    // No need to manually refresh, snapshots will handle it.
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

    // ignore: avoid_types_as_parameter_names
    double total = items.fold(0.0, (sum, item) => sum + (item.price * item.quantite));
    
    debugPrint('Saving purchase for $customerId in shop $shopId. Total: $total');
    
    try {
      final tx = LedgerTransaction(
        customerId: customerId,
        shopId: shopId,
        merchantId: _currentUser?.id,
        items: items,
        totalAmount: total,
        date: DateTime.now(),
      );

      await _firestore.collection('transactions').doc(tx.id).set(tx.toMap());
      debugPrint('Transaction saved: ${tx.id}');

      // Update balance
      customer.shopBalances[shopId] = (customer.shopBalances[shopId] ?? 0) + total;
      await _firestore.collection('users').doc(customerId).update({
        'shopBalances': customer.shopBalances,
      });
      debugPrint('Balance updated in Firestore for $customerId');
    } catch (e, stack) {
      debugPrint('ERROR in addPurchase saving to Firestore: $e');
      debugPrint(stack.toString());
    }
  }

  Future<void> addPayment(
    String customerId,
    String shopId,
    double amount,
  ) async {
    if (amount <= 0) return;
    final customer = getCustomerById(customerId);
    if (customer == null) return;

    debugPrint('Recording payment for $customerId in shop $shopId. Amount: $amount');

    try {
      final tx = LedgerTransaction(
        customerId: customerId,
        shopId: shopId,
        merchantId: _currentUser?.id,
        items: [],
        totalAmount: amount,
        date: DateTime.now(),
        isPayment: true,
      );

      await _firestore.collection('transactions').doc(tx.id).set(tx.toMap());
      debugPrint('Payment transaction saved: ${tx.id}');

      // Update balance: Subtract payment from debt
      customer.shopBalances[shopId] = (customer.shopBalances[shopId] ?? 0) - amount;
      await _firestore.collection('users').doc(customerId).update({
        'shopBalances': customer.shopBalances,
      });
      debugPrint('Balance updated (payment): $amount subtracted from $customerId debt');
    } catch (e, stack) {
      debugPrint('ERROR in addPayment: $e');
      debugPrint(stack.toString());
    }
  }

  Future<void> addItemToShop(LedgerItem item) async {
    final ownerShopId = _currentUser?.shopId;
    if (ownerShopId == null) {
      debugPrint('ERROR: addItemToShop failed because ownerShopId is null. CurrentUser: ${_currentUser?.id}, Role: ${_currentUser?.role}');
      return;
    }

    final newItem = LedgerItem(
      id: item.id,
      name: item.name,
      price: item.price,
      quantite: item.quantite,
      iconName: item.iconName,
      shopId: ownerShopId,
    );

    debugPrint('Adding item to shop shelf: ${newItem.name}');
    try {
      await _firestore.collection('items').doc(newItem.id).set(newItem.toMap());
      debugPrint('Item saved successfully: ${newItem.id}');
    } catch (e) {
      debugPrint('Error saving item: $e');
    }
  }

  Future<void> removeItemFromShop(String itemId) async {
    await _firestore.collection('items').doc(itemId).delete();
  }

  List<LedgerItem> getItemsForShop(String shopId) {
    return _availableItems.where((i) => i.shopId == shopId || i.shopId == null).toList();
  }

  Future<void> deleteTransaction(String transactionId) async {
    final txIndex = _transactions.indexWhere((t) => t.id == transactionId);
    if (txIndex == -1) return;

    final tx = _transactions[txIndex];
    final customer = getCustomerById(tx.customerId);

    if (customer != null) {
      // If it was a purchase, deleting it reduces debt.
      // If it was a payment, deleting it INCREASES debt.
      final effect = tx.isPayment ? -tx.totalAmount : tx.totalAmount;
      
      customer.shopBalances[tx.shopId] =
          (customer.shopBalances[tx.shopId] ?? 0) - effect;
          
      if (customer.shopBalances[tx.shopId]! < 0) {
        customer.shopBalances[tx.shopId] = 0;
      }

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

    final newItem = LedgerItem(
      id: oldItem.id,
      name: oldItem.name,
      price: newPrice,
      quantite: oldItem.quantite,
      iconName: oldItem.iconName,
    );

    // Update local copy
    tx.items[itemIndex] = newItem;
    
    // Recalculate total from scratch for safety
    final newTotal = tx.items.fold(0.0, (sum, item) => sum + (item.price * item.quantite));
    final totalDiff = newTotal - tx.totalAmount;

    await _firestore.collection('transactions').doc(transactionId).update({
      'items': tx.items.map((i) => i.toMap()).toList(),
      'totalAmount': newTotal,
    });

    final customer = getCustomerById(tx.customerId);
    if (customer != null) {
      customer.shopBalances[tx.shopId] = (customer.shopBalances[tx.shopId] ?? 0) + totalDiff;
      await _firestore.collection('users').doc(tx.customerId).update({
        'shopBalances': customer.shopBalances,
      });
    }
  }

  Future<void> linkMerchantToShop(String userId, String shopId) async {
    final userRef = _firestore.collection('users').doc(userId);
    await userRef.update({
      'shopId': shopId,
      'role': UserRole.shopOwner.name,
    });
  }

  /// Returns all users who are co-merchants of a given shop (excluding the original owner).
  List<AppUser> getMerchantsForShop(String shopId, String ownerId) {
    return _allUsers
        .where((u) =>
            u.shopId == shopId &&
            u.role == UserRole.shopOwner &&
            u.id != ownerId)
        .toList();
  }

  /// Revokes a merchant's access to the shop.
  Future<void> revokeMerchantFromShop(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'shopId': null,
      'role': UserRole.customer.name,
    });
  }

  /// Transfers full shop ownership to another user.
  /// The new owner gets the shopId; the old owner loses it.
  Future<void> transferShopOwnership(String newOwnerId, String shopId) async {
    final batch = _firestore.batch();
    // New owner gets the shop
    batch.update(_firestore.collection('users').doc(newOwnerId), {
      'shopId': shopId,
      'role': UserRole.shopOwner.name,
    });
    // Old owner is demoted (keep as customer)
    if (_currentUser != null && _currentUser!.id != newOwnerId) {
      batch.update(_firestore.collection('users').doc(_currentUser!.id), {
        'shopId': null,
        'role': UserRole.customer.name,
      });
    }
    await batch.commit();
  }
}
