import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
// import 'firebase_options.dart'; // Uncomment after generating with flutterfire configure

import 'providers/app_state.dart';
import 'screens/auth_screens.dart';
import 'screens/owner_screens.dart';
import 'screens/customer_screens.dart';
import 'models/models.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    // options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AppState())],
      child: const CarnetApp(),
    ),
  );
}

class CarnetApp extends StatelessWidget {
  const CarnetApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Shared color scheme from the designs
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF001e40),
      primary: const Color(0xFF001e40),
      secondary: const Color(0xFF006c48),
      surface: const Color(0xFFf8fafb),
    );

    return MaterialApp.router(
      title: 'Carnet - كناش مول الحانوت',
      themeMode: ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        textTheme: GoogleFonts.cairoTextTheme(Theme.of(context).textTheme)
            .copyWith(
              displayLarge: GoogleFonts.cairo(
                fontWeight: FontWeight.w800,
                color: colorScheme.primary,
              ),
              titleLarge: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
      ),
      builder: (context, child) {
        // Enforce RTL direction for Arabic
        return Directionality(textDirection: TextDirection.rtl, child: child!);
      },
      routerConfig: _router,
    );
  }
}

// Global GoRouter instance
final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) {
        final appState = context.watch<AppState>();
        if (!appState.isLoggedIn) {
          return LoginScreen();
        }
        if (appState.currentUser?.role == UserRole.shopOwner) {
          return OwnerDashboard();
        } else {
          return CustomerDashboard();
        }
      },
    ),
    GoRoute(path: '/login', builder: (context, state) => LoginScreen()),
    GoRoute(path: '/register', builder: (context, state) => RegisterScreen()),

    // Owner Routes
    GoRoute(
      path: '/owner/customers',
      builder: (context, state) => CustomerList(),
    ),
    GoRoute(
      path: '/owner/customers/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return CustomerLedger(customerId: id);
      },
    ),
    GoRoute(path: '/owner/qr', builder: (context, state) => ShopQRCodeScreen()),

    // Customer Routes
    GoRoute(
      path: '/customer/scan',
      builder: (context, state) => ScanQRCodeScreen(),
    ),
    GoRoute(
      path: '/customer/add/:shopId',
      builder: (context, state) {
        final shopId = state.pathParameters['shopId']!;
        return AddPurchaseScreen(shopId: shopId);
      },
    ),
  ],
  redirect: (context, state) {
    // Optional: Add global auth redirect logic here.
    return null;
  },
);
