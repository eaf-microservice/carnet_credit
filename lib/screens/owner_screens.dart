import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../widgets/app_drawer.dart';

class OwnerDashboard extends StatelessWidget {
  const OwnerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final shopId =
        appState.currentUser?.shopId ?? appState.currentUser?.id ?? 'shop_1';
    final customers = appState.getCustomersForShop(shopId);
    final totalDebt = customers.fold(
      0.0,
      (sum, c) => sum + (c.shopBalances[shopId] ?? 0),
    );

    // Sort customers by highest debt
    final topDebtors = List.of(customers)
      ..sort(
        (a, b) => (b.shopBalances[shopId] ?? 0).compareTo(
          a.shopBalances[shopId] ?? 0,
        ),
      );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'لوحة تحكم مول الحانوت',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Total Debt Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    const Color(0xFF003366),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'مجموع الكريدي',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    appState.formatCurrency(totalDebt),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const SizedBox(height: 24),
            // Removed Wrap of buttons since they are now in the Drawer


            const SizedBox(height: 32),
            Text(
              'كليان بكريدي طالع',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...topDebtors
                .take(3)
                .map(
                  (customer) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(child: Text(customer.name[0])),
                      title: Text(
                        customer.shopNicknames[shopId] != null && customer.shopNicknames[shopId] != customer.name
                            ? '${customer.shopNicknames[shopId]} (${customer.name})'
                            : (customer.shopNicknames[shopId] ?? customer.name),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: customer.phone != null
                          ? Text('${customer.phone!} • ${appState.formatCurrency(customer.shopBalances[shopId] ?? 0)}')
                          : Text(appState.formatCurrency(customer.shopBalances[shopId] ?? 0)),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () =>
                          context.push('/owner/customers/${customer.id}'),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class CustomerList extends StatelessWidget {
  const CustomerList({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final shopId = appState.currentUser?.shopId ?? appState.currentUser?.id ?? 'shop_1';
    final customers = appState.getCustomersForShop(shopId);

    return Scaffold(
      appBar: AppBar(title: const Text('قائمة الكليان')),
      body: ListView.builder(
        itemCount: customers.length,
        itemBuilder: (context, index) {
          final customer = customers[index];
          return ListTile(
            leading: CircleAvatar(child: Text(customer.name[0])),
            title: Text(
              customer.shopNicknames[shopId] != null && customer.shopNicknames[shopId] != customer.name
                  ? '${customer.shopNicknames[shopId]} (${customer.name})'
                  : (customer.shopNicknames[shopId] ?? customer.name),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (customer.phone != null)
                  Text('الهاتف: ${customer.phone}', style: const TextStyle(fontSize: 12)),
                Text(
                  'الرصيد: ${(customer.shopBalances[shopId] ?? 0).toStringAsFixed(2)} درهم',
                ),
              ],
            ),
            onTap: () => context.push('/owner/customers/${customer.id}'),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final nameController = TextEditingController();
          final phoneController = TextEditingController();
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('إضافة زبون جديد'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'اللقب (الاسم الذي تعرفه به)',
                      border: OutlineInputBorder(),
                      helperText: 'مثال: با لعروبي، الحسين الحلاق...',
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'رقم الهاتف (اختياري)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final nickname = nameController.text.trim();
                    final phone = phoneController.text.trim();
                    if (nickname.isNotEmpty) {
                      context.read<AppState>().addManualCustomer(
                        nickname, // Using nickname as the initial name
                        shopId,
                        nickname: nickname, // Also store it as a shop nickname
                        phone: phone.isNotEmpty ? phone : null,
                      );
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('إضافة'),
                ),
              ],
            ),
          );
        },
        label: const Text('إضافة زبون'),
        icon: const Icon(Icons.person_add),
      ),
    );
  }
}

class CustomerLedger extends StatelessWidget {
  final String customerId;
  const CustomerLedger({super.key, required this.customerId});

  void _showEditNicknameDialog(BuildContext context, AppUser customer, String shopId) {
    final appState = context.read<AppState>();
    final controller = TextEditingController(text: customer.shopNicknames[shopId]);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل لقب الزبون'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'اللقب المفضل',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              appState.setCustomerNickname(customer.id, shopId, controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  void _showRecordPaymentDialog(BuildContext context, String customerId, String shopId) {
    final appState = context.read<AppState>();
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسديد مبلغ (خلاص)'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'المبلغ المسدد (درهم)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.money_off, color: Colors.green),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(controller.text);
              if (amount != null && amount > 0) {
                appState.addPayment(customerId, shopId, amount);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('تسجيل الخلاص'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final customer = appState.getCustomerById(customerId);
    final transactions = appState.getTransactionsForCustomer(customerId);

    if (customer == null) {
      return const Scaffold(body: Center(child: Text('غير موجود')));
    }

    final shopId = appState.currentUser?.shopId ?? appState.currentUser?.id ?? 'shop_1';
    final nickname = customer.shopNicknames[shopId];
    final displayName = nickname != null && nickname != customer.name
        ? '$nickname (${customer.name})'
        : (nickname ?? customer.name);

    return Scaffold(
      appBar: AppBar(
        title: Text(displayName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note),
            onPressed: () => _showEditNicknameDialog(context, customer, shopId),
            tooltip: 'تعديل اللقب',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            width: double.infinity,
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                Text(
                  'قيمة الدين الإجمالية',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${(customer.shopBalances[appState.currentUser?.shopId ?? appState.currentUser?.id ?? 'shop_1'] ?? 0).toStringAsFixed(2)} درهم',
                  style: Theme.of(context).textTheme.displayLarge,
                ),
                if (customer.id.startsWith('manual_')) ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      final shopId = appState.currentUser?.shopId ?? appState.currentUser?.id ?? 'shop_1';
                      final linkData = 'link:$shopId:${customer.id}';
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('ربط حساب الزبون'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'اجعل الزبون يمسح هذا الكود من تطبيقه لربط حسابه بهذا الكارني:',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: 200,
                                height: 200,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: QrImageView(
                                    data: linkData,
                                    version: QrVersions.auto,
                                    size: 200.0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('إغلاق'),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.link),
                    label: const Text('ربط مع حساب الزبون'),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showRecordPaymentDialog(context, customerId, shopId),
                      icon: const Icon(Icons.payments),
                      label: const Text('تسديد خلاص'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: transactions.isEmpty
                ? const Center(child: Text('لا توجد عمليات'))
                : ListView.builder(
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final tx =
                          transactions[transactions.length -
                              1 -
                              index]; // latest first
                      
                      if (tx.isPayment) {
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.green,
                            child: Icon(Icons.money_off, color: Colors.white),
                          ),
                          title: const Text(
                            'تسديد مبلغ (خلاص)',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(tx.date.toString().substring(0, 16)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '- ${appState.formatCurrency(tx.totalAmount)}',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('حذف عملية التسديد'),
                                      content: const Text(
                                        'هل أنت متأكد من حذف هذه العملية؟ سيعود الدين كما كان.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('إلغاء'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            appState.deleteTransaction(tx.id);
                                            Navigator.pop(context);
                                          },
                                          child: const Text(
                                            'حذف',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      }

                      return ExpansionTile(
                        title: Text(
                          'تقييد سلعة - ${appState.formatCurrency(tx.totalAmount)}',
                        ),
                        subtitle: Text(tx.date.toString().substring(0, 16)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('حذف العملية'),
                                    content: const Text(
                                      'هل أنت متأكد من حذف هذه العملية بالكامل؟',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('إلغاء'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          appState.deleteTransaction(tx.id);
                                          Navigator.pop(context);
                                        },
                                        child: const Text(
                                          'حذف',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const Icon(Icons.expand_more),
                          ],
                        ),
                        children: tx.items
                            .map(
                              (item) => ListTile(
                                title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                  '${item.quantite.toStringAsFixed(0)} وحدة × ${appState.formatCurrency(item.price)}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${(item.price * item.quantite).toStringAsFixed(2)} درهم',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 20),
                                      onPressed: () {
                                        final controller =
                                            TextEditingController(
                                              text: item.price.toString(),
                                            );
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('تعديل الثمن للقطعة'),
                                            content: TextField(
                                              controller: controller,
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: const InputDecoration(
                                                labelText:
                                                    'الثمن الجديد للقطعة (درهم)',
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: const Text('إلغاء'),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  final newPrice =
                                                      double.tryParse(
                                                        controller.text,
                                                      );
                                                  if (newPrice != null) {
                                                    appState
                                                        .updateTransactionItemTotalPrice(
                                                          tx.id,
                                                          item.id,
                                                          newPrice,
                                                        );
                                                  }
                                                  Navigator.pop(context);
                                                },
                                                child: const Text('حفظ'),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final shopId = appState.currentUser?.shopId ?? appState.currentUser?.id ?? 'shop_1';
          context.push('/customer/add/$shopId/$customerId');
        },
        label: const Text('إضافة للكريدي'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class ShopQRCodeScreen extends StatelessWidget {
  const ShopQRCodeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final shopId = appState.currentUser?.shopId ?? appState.currentUser?.id ?? 'shop_1';

    return Scaffold(
      appBar: AppBar(title: const Text('كود المحل')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: QrImageView(
                data: shopId,
                version: QrVersions.auto,
                size: 250.0,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'الرمز الخاص بمحلك: $shopId',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'اجعل زبائنك يمسحون هذا الكود لفتح الكارني والارتباط بمحلك مباشرة',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ManageShelvesScreen extends StatelessWidget {
  const ManageShelvesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final shopId = appState.currentUser?.shopId ?? '';
    final items = appState.getItemsForShop(shopId);

    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الرفوف (السلع)')),
      body: items.isEmpty
          ? const Center(
              child: Text('الرفوف خاوية. ضيف السلعة اللي كتبيع بزاف.'),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  child: ListTile(
                    leading: Icon(
                      _getIconData(item.iconName),
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${item.price.toStringAsFixed(2)} درهم'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => appState.removeItemFromShop(item.id),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddItemDialog(context),
        label: const Text('إضافة سلعة'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  IconData _getIconData(String name) {
    switch (name) {
      case 'bakery_dining':
        return Icons.bakery_dining;
      case 'emoji_food_beverage':
        return Icons.emoji_food_beverage;
      case 'opacity':
        return Icons.opacity;
      case 'grid_view':
        return Icons.grid_view;
      case 'grain':
        return Icons.grain;
      case 'water_drop':
        return Icons.water_drop;
      default:
        return Icons.shopping_cart;
    }
  }

  void _showAddItemDialog(BuildContext context) {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    String selectedIcon = 'shopping_cart';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إضافة سلعة جديدة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'اسم المنتج'),
                ),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'الثمن (درهم)'),
                ),
                const SizedBox(height: 16),
                const Text('اختيار أيقونة:'),
                Wrap(
                  spacing: 8,
                  children: [
                    'bakery_dining',
                    'emoji_food_beverage',
                    'opacity',
                    'grain',
                    'water_drop',
                    'shopping_cart'
                  ].map((iconName) {
                    return IconButton(
                      icon: Icon(_getIconData(iconName)),
                      color: selectedIcon == iconName
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                      onPressed: () => setDialogState(() => selectedIcon = iconName),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final price = double.tryParse(priceController.text);
                if (name.isNotEmpty && price != null) {
                  context.read<AppState>().addItemToShop(
                        LedgerItem(
                          name: name,
                          price: price,
                          quantite: 1.0,
                          iconName: selectedIcon,
                        ),
                      );
                  Navigator.pop(context);
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}

class MerchantQRCodeScreen extends StatelessWidget {
  const MerchantQRCodeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final shopId = appState.currentUser?.shopId ?? appState.currentUser?.id ?? '';
    final merchantLinkData = 'merchant-link:$shopId';

    return Scaffold(
      appBar: AppBar(title: const Text('دعوة تاجر مساعد')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: QrImageView(
                data: merchantLinkData,
                version: QrVersions.auto,
                size: 250.0,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'اجعل التاجر المساعد يمسح هذا الرمز من تطبيقه للانضمام ومشاركة نفس المحل.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Flexible(child: Text('شارك هذا الرمز فقط مع من تثق به.', style: TextStyle(fontSize: 12))),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () => context.push('/owner/merchants'),
              icon: const Icon(Icons.manage_accounts),
              label: const Text('إدارة التجار المساعدين'),
            ),
          ],
        ),
      ),
    );
  }
}

class ManageMerchantsScreen extends StatelessWidget {
  const ManageMerchantsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final currentUser = appState.currentUser!;
    final shopId = currentUser.shopId ?? currentUser.id;
    final merchants = appState.getMerchantsForShop(shopId, currentUser.id);

    return Scaffold(
      appBar: AppBar(title: const Text('إدارة التجار المساعدين')),
      body: merchants.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('لا يوجد تجار مساعدون حتى الآن.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: merchants.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final merchant = merchants[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueGrey.shade100,
                    child: Text(merchant.name.isNotEmpty ? merchant.name[0] : '?'),
                  ),
                  title: Text(merchant.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('تاجر مساعد'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'تحويل المحل له',
                        icon: const Icon(Icons.swap_horiz, color: Colors.blue),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('تحويل المحل'),
                              content: Text('هل تريد أن تمرر المحل كاملاً لـ "${merchant.name}"؟ ستفقد صلاحياتك.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                                  child: const Text('تأكيد', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true && context.mounted) {
                            await appState.transferShopOwnership(merchant.id, shopId);
                            if (context.mounted) context.go('/login');
                          }
                        },
                      ),
                      IconButton(
                        tooltip: 'إلغاء الصلاحيات',
                        icon: const Icon(Icons.person_remove, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('إلغاء الصلاحيات'),
                              content: Text('سيتم حذف "${merchant.name}" من فريق المحل. لن يتمكن من الدخول بعد الآن.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                  child: const Text('حذف', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true && context.mounted) {
                            await appState.revokeMerchantFromShop(merchant.id);
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class JoinShopScreen extends StatefulWidget {
  const JoinShopScreen({super.key});

  @override
  State<JoinShopScreen> createState() => _JoinShopScreenState();
}

class _JoinShopScreenState extends State<JoinShopScreen> {
  final _codeController = TextEditingController();
  bool _scanning = false;
  bool _loading = false;
  bool _scannerReady = false;
  final MobileScannerController _scannerController = MobileScannerController();

  @override
  void dispose() {
    _codeController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _joinShop(String shopId) async {
    final id = shopId.replaceFirst('merchant-link:', '').trim();
    if (id.isEmpty) return;
    setState(() => _loading = true);
    final appState = context.read<AppState>();
    final userId = appState.currentUser?.id;
    if (userId == null) return;
    try {
      await appState.linkMerchantToShop(userId, id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم الانضمام للمحل بنجاح!')),
        );
        context.go('/owner');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الانضمام لمحل')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'اطلب من صاحب المحل رمز QR الخاص بدعوة التجار، أو أدخل كود المحل يدوياً.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // QR Scanner toggle
            OutlinedButton.icon(
              onPressed: () => setState(() => _scanning = !_scanning),
              icon: Icon(_scanning ? Icons.close : Icons.qr_code_scanner),
              label: Text(_scanning ? 'إخفاء الماسح' : 'مسح رمز QR'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),

            if (_scanning) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 220,
                  child: MobileScanner(
                    controller: _scannerController,
                    onDetect: (capture) {
                      if (!_scannerReady) {
                        setState(() => _scannerReady = true);
                        return;
                      }
                      final code = capture.barcodes.firstOrNull?.rawValue;
                      if (code != null && code.startsWith('merchant-link:')) {
                        setState(() => _scanning = false);
                        _joinShop(code);
                      } else if (code != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('هذا الرمز ليس خاصاً بدعوة التجار.')),
                        );
                      }
                    },
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),

            // Manual entry
            const Text('أو أدخل كود المحل يدوياً:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _codeController,
              decoration: InputDecoration(
                hintText: 'مثال: abc123...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.store),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loading
                  ? null
                  : () => _joinShop(_codeController.text.trim()),
              icon: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.login),
              label: const Text('انضمام'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
