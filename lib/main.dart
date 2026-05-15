import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'models/app_config.dart';
import 'services/app_config_service.dart';
import 'services/auth_service.dart';
import 'services/bootstrap_service.dart';
import 'pages/auth/email_verification_page.dart';
import 'pages/auth/login_page.dart';
import 'pages/admin/admin_dashboard_screen.dart';
import 'pages/main_scaffold.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: "assets/env");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await BootstrapService.ensureSpecialAccounts();
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AuthService())],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppConfig>(
      stream: AppConfigService().watchConfig(),
      initialData: AppConfig.defaults(),
      builder: (context, snapshot) {
        final config = snapshot.data ?? AppConfig.defaults();
        return MaterialApp(
          title: config.brandName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: const AuthWrapper(),
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    if (authService.user == null) {
      return const LoginPage();
    } else if (authService.isAdmin) {
      return const AdminDashboardScreen();
    } else if (!authService.isEmailVerified) {
      return const EmailVerificationPage();
    } else {
      return const MainScaffold();
    }
  }
}
