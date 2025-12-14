import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as rp;
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'api/favorites_provider.dart';

import 'login_screen.dart';
import 'register_screen.dart';
import 'password_reset_screen.dart';
import 'password_reset_sent_screen.dart';
import 'map_screen.dart';
import 'api/auth_state.dart';
import 'onboarding_post_registration.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!Platform.isMacOS) {
    await Firebase.initializeApp();
  }

  try {
    await dotenv.load(fileName: '.env');
  } catch (e, st) {
    debugPrint('WARNING: impossibile caricare .env: $e');
    debugPrintStack(stackTrace: st);
  }

  runApp(
    rp.ProviderScope(
      child: ChangeNotifierProvider(
        create: (_) => FavoritesProvider(),
        child: const EasyCamperApp(),
      ),
    ),
  );
}

class EasyCamperApp extends rp.ConsumerWidget {
  const EasyCamperApp({super.key});

  @override
  Widget build(BuildContext context, rp.WidgetRef ref) {
    return MaterialApp.router(
      title: 'EasyCamper',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF4CAF50),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF4CAF50),
      ),
      routerConfig: _router(ref),
    );
  }
}

GoRouter _router(rp.WidgetRef ref) {
  return GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, __) => const _RootDecider()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/password-reset', builder: (_, __) => const PasswordResetScreen()),
      GoRoute(path: '/password-reset-sent', builder: (_, __) => const PasswordResetSentScreen()),
      GoRoute(path: '/onboarding/post', builder: (_, __) => const OnboardingPostRegistrationScreen()),
      GoRoute(path: '/home', builder: (_, __) => const MapScreen()),
    ],
  );
}

class _RootDecider extends rp.ConsumerWidget {
  const _RootDecider({super.key});

  @override
  Widget build(BuildContext context, rp.WidgetRef ref) {
    final authAsync = ref.watch(authControllerProvider);

    if (authAsync.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (authAsync.hasError) {
      return const LoginScreen();
    }

    final authState = authAsync.value!;

    if (authState.session == null) {
      return const LoginScreen();
    }

    // Se l'utente è loggato, mostriamo l'onboarding post-registrazione
    // In un'app reale controlleremmo una flag nelle SharedPreferences,
    // ma per questa demo lo mostriamo sempre come richiesto.
    return const OnboardingPostRegistrationScreen();
  }
}