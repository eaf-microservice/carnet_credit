import 'package:uuid/uuid.dart';

enum UserRole { shopOwner, customer }

class AppUser {
  final String id;
  final String name;
  final UserRole role;
  final String? shopId; // The shop they own or are connected to
  final String? profileImageUrl;
  Map<String, double> shopBalances; // key: shopId, value: balance

  AppUser({
    required this.id,
    required this.name,
    required this.role,
    this.shopId,
    this.profileImageUrl,
    Map<String, double>? shopBalances,
  }) : this.shopBalances = shopBalances ?? {};

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'role': role.name,
      'shopId': shopId,
      'profileImageUrl': profileImageUrl,
      'shopBalances': shopBalances,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () => UserRole.customer,
      ),
      shopId: map['shopId'],
      profileImageUrl: map['profileImageUrl'],
      shopBalances: Map<String, double>.from(map['shopBalances'] ?? {}),
    );
  }
}

class LedgerItem {
  final String id;
  final String name;
  final double price;
  final String iconName;

  LedgerItem({
    String? id,
    required this.name,
    required this.price,
    required this.iconName,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'price': price, 'iconName': iconName};
  }

  factory LedgerItem.fromMap(Map<String, dynamic> map) {
    return LedgerItem(
      id: map['id'],
      name: map['name'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      iconName: map['iconName'] ?? '',
    );
  }
}

class LedgerTransaction {
  final String id;
  final String customerId;
  final String shopId;
  final List<LedgerItem> items;
  final double totalAmount;
  final DateTime date;

  LedgerTransaction({
    String? id,
    required this.customerId,
    required this.shopId,
    required this.items,
    required this.totalAmount,
    required this.date,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerId': customerId,
      'shopId': shopId,
      'items': items.map((i) => i.toMap()).toList(),
      'totalAmount': totalAmount,
      'date': date.toIso8601String(),
    };
  }

  factory LedgerTransaction.fromMap(Map<String, dynamic> map) {
    return LedgerTransaction(
      id: map['id'],
      customerId: map['customerId'] ?? '',
      shopId: map['shopId'] ?? '',
      items: (map['items'] as List? ?? [])
          .map((i) => LedgerItem.fromMap(i))
          .toList(),
      totalAmount: (map['totalAmount'] ?? 0.0).toDouble(),
      date: DateTime.tryParse(map['date'] ?? '') ?? DateTime.now(),
    );
  }
}
