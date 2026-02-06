import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'firebase_options.dart';
import 'themes/dark_theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/event_screen.dart';  // Import the renamed EventScreen
import 'screens/dashboard_screen.dart';
import 'screens/qr_scanner_screen.dart';

final FirebaseAnalytics analytics = FirebaseAnalytics.instance;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Enable analytics collection
  await analytics.setAnalyticsCollectionEnabled(true);
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clockin Admin',
      theme: darkTheme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/login':
            return MaterialPageRoute(builder: (_) => LoginScreen());
          case '/home':
            return MaterialPageRoute(builder: (_) => const HomeScreen());
          case '/eventScreen':
            final eventName = settings.arguments as String;
            return MaterialPageRoute(
              builder: (_) => EventScreen(eventName: eventName),  // Navigate to EventScreen directly
            );
          case '/dashboard':
            final eventName = settings.arguments as String;
            return MaterialPageRoute(
              builder: (_) => DashboardScreen(eventName: eventName),
            );
          case '/scanner':
            return MaterialPageRoute(
              builder: (_) => const QRScannerScreen(eventName: ''),
            );
          default:
            return MaterialPageRoute(
              builder: (_) => Scaffold(
                body: Center(child: Text('No route defined for ${settings.name}')),
              ),
            );
        }
      },
    );
  }
}
