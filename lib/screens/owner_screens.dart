import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_state.dart';

class OwnerDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final shopId = appState.currentUser?.shopId ?? 'shop_1';
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
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await appState.logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
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
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${totalDebt.toStringAsFixed(2)} درهم',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Actions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/owner/customers'),
                    icon: const Icon(Icons.people),
                    label: const Text('الكليان'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/owner/qr'),
                    icon: const Icon(Icons.qr_code),
                    label: const Text('كود المحل'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),

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
                        customer.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: Text(
                        '${(customer.shopBalances[appState.currentUser?.shopId ?? 'shop_1'] ?? 0).toStringAsFixed(2)} درهم',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
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
  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final shopId = appState.currentUser?.shopId ?? 'shop_1';
    final customers = appState.getCustomersForShop(shopId);

    return Scaffold(
      appBar: AppBar(title: const Text('قائمة الكليان')),
      body: ListView.builder(
        itemCount: customers.length,
        itemBuilder: (context, index) {
          final customer = customers[index];
          return ListTile(
            leading: CircleAvatar(child: Text(customer.name[0])),
            title: Text(customer.name),
            subtitle: Text(
              'الرصيد: ${(customer.shopBalances[context.read<AppState>().currentUser?.shopId ?? 'shop_1'] ?? 0).toStringAsFixed(2)} درهم',
            ),
            onTap: () => context.push('/owner/customers/${customer.id}'),
          );
        },
      ),
    );
  }
}

class CustomerLedger extends StatelessWidget {
  final String customerId;
  const CustomerLedger({super.key, required this.customerId});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final customer = appState.getCustomerById(customerId);
    final transactions = appState.getTransactionsForCustomer(customerId);

    if (customer == null)
      return const Scaffold(body: Center(child: Text('غير موجود')));

    return Scaffold(
      appBar: AppBar(title: Text('حساب ${customer.name}')),
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
                  '${(customer.shopBalances[appState.currentUser?.shopId ?? 'shop_1'] ?? 0).toStringAsFixed(2)} درهم',
                  style: Theme.of(context).textTheme.displayLarge,
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
                      return ExpansionTile(
                        title: Text(
                          'تقييد سلعة - ${tx.totalAmount.toStringAsFixed(2)} درهم',
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
                                title: Text(item.name),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${item.price.toStringAsFixed(2)} درهم',
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
                                            title: const Text('تعديل الثمن'),
                                            content: TextField(
                                              controller: controller,
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: const InputDecoration(
                                                labelText:
                                                    'الثمن الجديد (درهم)',
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
        onPressed: () => context.push('/customer/add/$customerId'),
        label: const Text('إضافة للكريدي'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class ShopQRCodeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('كود المحل')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 200,
              height: 200,
              color: Colors.black12,
              child: const Center(child: Icon(Icons.qr_code_2, size: 150)),
            ),
            const SizedBox(height: 24),
            const Text(
              'اجعل زبائنك يمسحون الكود لفتح الكارني مباشرة',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
