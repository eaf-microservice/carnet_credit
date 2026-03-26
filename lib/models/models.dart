import 'package:uuid/uuid.dart';

enum UserRole { shopOwner, customer }
enum CurrencyMode { dirham, rial }

class AppUser {
  final String id;
  final String name;
  final UserRole role;
  final String? shopId; // The shop they own or are connected to
  final String? profileImageUrl;
  final String? phone;
  final String? address;
  final bool isDeactivated;
  final CurrencyMode currencyMode;
  Map<String, double> shopBalances; // key: shopId, value: balance
  Map<String, String> shopNicknames; // key: shopId, value: nickname assigned by merchant

  AppUser({
    required this.id,
    required this.name,
    required this.role,
    this.shopId,
    this.profileImageUrl,
    this.phone,
    this.address,
    this.isDeactivated = false,
    this.currencyMode = CurrencyMode.dirham,
    Map<String, double>? shopBalances,
    Map<String, String>? shopNicknames,
  })  : shopBalances = shopBalances ?? {},
        shopNicknames = shopNicknames ?? {};

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'role': role.name,
      'shopId': shopId,
      'profileImageUrl': profileImageUrl,
      'phone': phone,
      'address': address,
      'isDeactivated': isDeactivated,
      'currencyMode': currencyMode.name,
      'shopBalances': shopBalances,
      'shopNicknames': shopNicknames,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    final role = UserRole.values.firstWhere(
      (e) => e.name == map['role'],
      orElse: () => UserRole.customer,
    );
    final id = map['id'] ?? '';
    return AppUser(
      id: id,
      name: map['name'] ?? '',
      role: role,
      shopId: map['shopId'] ?? (role == UserRole.shopOwner ? id : null),
      profileImageUrl: map['profileImageUrl'],
      phone: map['phone'],
      address: map['address'],
      isDeactivated: map['isDeactivated'] ?? false,
      currencyMode: CurrencyMode.values.firstWhere(
        (e) => e.name == map['currencyMode'],
        orElse: () => CurrencyMode.dirham,
      ),
      shopBalances: (map['shopBalances'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, (v as num).toDouble())),
      shopNicknames: (map['shopNicknames'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, v.toString())),
    );
  }
}

class LedgerItem {
  final String id;
  final String name;
  final double price;
  final double quantite;
  final String iconName;
  final String? shopId; // The shop this item belongs to

  LedgerItem({
    String? id,
    required this.name,
    required this.price,
    required this.quantite,
    required this.iconName,
    this.shopId,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'quantite': quantite,
      'iconName': iconName,
      'shopId': shopId,
    };
  }

  factory LedgerItem.fromMap(Map<String, dynamic> map) {
    return LedgerItem(
      id: map['id'],
      name: map['name'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      quantite: (map['quantite'] ?? 0.0).toDouble(),
      iconName: map['iconName'] ?? '',
      shopId: map['shopId'],
    );
  }
}

class LedgerTransaction {
  final String id;
  final String customerId;
  final String shopId;
  final String? merchantId; // The merchant who recorded this
  final List<LedgerItem> items;
  final double totalAmount;
  final DateTime date;
  final bool isPayment;

  LedgerTransaction({
    String? id,
    required this.customerId,
    required this.shopId,
    this.merchantId,
    required this.items,
    required this.totalAmount,
    required this.date,
    this.isPayment = false,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerId': customerId,
      'shopId': shopId,
      'merchantId': merchantId,
      'items': items.map((i) => i.toMap()).toList(),
      'totalAmount': totalAmount,
      'date': date.toIso8601String(),
      'isPayment': isPayment,
    };
  }

  factory LedgerTransaction.fromMap(Map<String, dynamic> map) {
    return LedgerTransaction(
      id: map['id'],
      customerId: map['customerId'] ?? '',
      shopId: map['shopId'] ?? '',
      merchantId: map['merchantId'],
      items: (map['items'] as List? ?? [])
          .map((i) => LedgerItem.fromMap(i))
          .toList(),
      totalAmount: (map['totalAmount'] ?? 0.0).toDouble(),
      date: DateTime.tryParse(map['date'] ?? '') ?? DateTime.now(),
      isPayment: map['isPayment'] ?? false,
    );
  }
}
