import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  // Inizializza Firebase solo dove lo useremo davvero (mobile/web), non su macOS per ora.
  if (!Platform.isMacOS) {
    await Firebase.initializeApp();
  }

  // Prova a caricare .env ma non bloccare l'app se il file manca
  try {
    await dotenv.load(fileName: '.env');
  } catch (e, st) {
    debugPrint('WARNING: impossibile caricare .env: $e');
    debugPrintStack(stackTrace: st);
  }

  runApp(
    ProviderScope(
      child: ChangeNotifierProvider(
        create: (_) => FavoritesProvider(),
        child: const EasyCamperApp(),
      ),
    ),
  );
}

/// ────────────────────────── MODELS ──────────────────────────
class Camper {
  final String make;
  final String model;
  final double length;
  final double height;
  final double weight;
  final int year;
  const Camper({
    required this.make,
    required this.model,
    required this.length,
    required this.height,
    required this.weight,
    required this.year,
  });
}

class UserProfile {
  final String firstName;
  final String lastName;
  const UserProfile({required this.firstName, required this.lastName});
}

/// ────────────────────────── PROVIDERS (NUOVO MODELLO) ──────────────────────────
class CamperNotifier extends Notifier<Camper?> {
  @override
  Camper? build() => null;

  void setCamper(Camper camper) {
    state = camper;
  }
}

final camperProvider = NotifierProvider<CamperNotifier, Camper?>(CamperNotifier.new);

class UserProfileNotifier extends Notifier<UserProfile?> {
  @override
  UserProfile? build() => null;

  void setProfile(UserProfile profile) {
    state = profile;
  }
}

final userProfileProvider = NotifierProvider<UserProfileNotifier, UserProfile?>(UserProfileNotifier.new);

class IsLoggedInNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setLoggedIn(bool value) {
    state = value;
  }
}

final isLoggedInProvider = NotifierProvider<IsLoggedInNotifier, bool>(IsLoggedInNotifier.new);

/// ────────────────────────── APP & ROUTER ──────────────────────────
class EasyCamperApp extends ConsumerWidget {
  const EasyCamperApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'EasyCamper',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF4CAF50),
      ),
      routerConfig: _router(ref),
    );
  }
}

GoRouter _router(WidgetRef ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const _RootDecider(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/password-reset',
        builder: (context, state) => const PasswordResetScreen(),
      ),
      GoRoute(
        path: '/password-reset-sent',
        builder: (context, state) => const PasswordResetSentScreen(),
      ),
      GoRoute(
        path: '/onboarding/profile',
        builder: (context, state) => const ProfileOnboardingScreen(),
      ),
      GoRoute(
        path: '/onboarding/vehicle',
        builder: (context, state) => const VehicleOnboardingScreen(),
      ),
      GoRoute(
        path: '/onboarding/manual',
        builder: (context, state) => ManualFormScreen(
          custom: state.uri.queryParameters['custom'] == 'true',
        ),
      ),
      GoRoute(
        path: '/onboarding/post',
        builder: (context, state) => const OnboardingPostRegistrationScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => MapScreen(),
      ),
    ],
  );
}

/// Decide cosa mostrare come prima schermata:
/// - se non loggato: login
/// - se loggato ma senza profilo: onboarding profilo
/// - se loggato con profilo ma senza veicolo: onboarding veicolo
/// - se tutto completo: mappa principale
class _RootDecider extends ConsumerWidget {
  const _RootDecider();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authControllerProvider);

    if (authAsync.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (authAsync.hasError) {
      final auth = authAsync.asData?.value;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (auth == null || auth.status == AuthStatus.loggedOut) {
          context.go('/login');
        } else {
          context.go('/home');
        }
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final auth = authAsync.value!;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      switch (auth.status) {
        case AuthStatus.loggedOut:
          context.go('/login');
          break;
        case AuthStatus.loggedIn:
          // Mostra SEMPRE l’onboarding post-registrazione dopo ogni login
          context.go('/onboarding/post');
          break;
        case AuthStatus.unknown:
          break;
      }
    });

    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

/// ────────────────────────── PROFILE ONBOARDING ──────────────────────────
class ProfileOnboardingScreen extends ConsumerStatefulWidget {
  const ProfileOnboardingScreen({super.key});
  @override
  ConsumerState<ProfileOnboardingScreen> createState() => _ProfileOnboardingState();
}

class _ProfileOnboardingState extends ConsumerState<ProfileOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('I tuoi dati')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: _firstNameCtrl,
              decoration: const InputDecoration(labelText: 'Nome'),
              validator: (v) => v == null || v.isEmpty ? 'Campo obbligatorio' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _lastNameCtrl,
              decoration: const InputDecoration(labelText: 'Cognome'),
              validator: (v) => v == null || v.isEmpty ? 'Campo obbligatorio' : null,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                child: const Text('Continua'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final profile = UserProfile(
      firstName: _firstNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
    );
    ref.read(userProfileProvider.notifier).setProfile(profile);
    context.go('/onboarding/vehicle');
  }
}

/// ────────────────────────── VEHICLE ONBOARDING WRAPPER ──────────────────────────
class VehicleOnboardingScreen extends StatelessWidget {
  const VehicleOnboardingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configura il veicolo')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            OutlinedButton.icon(
              onPressed: () => context.push('/onboarding/manual'),
              icon: const Icon(Icons.format_list_bulleted),
              label: const Text('Seleziona da libreria modelli'),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => context.push('/onboarding/manual?custom=true'),
              icon: const Icon(Icons.edit_note_outlined),
              label: const Text('Inserisci dati manualmente'),
            ),
          ],
        ),
      ),
    );
  }
}

/// ────────────────────────── MANUAL FORM (SEMPLIFICATA) ──────────────────────────
class ManualFormScreen extends ConsumerStatefulWidget {
  final bool custom;
  const ManualFormScreen({super.key, required this.custom});
  @override
  ConsumerState<ManualFormScreen> createState() => _ManualFormScreenState();
}

class _ManualFormScreenState extends ConsumerState<ManualFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _makeCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _lengthCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();

  @override
  void dispose() {
    _makeCtrl.dispose();
    _modelCtrl.dispose();
    _lengthCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Per ora implemento solo la versione manuale; la libreria modelli
    // la ricolleghiamo dopo quando portiamo dentro anche il catalogo.
    return Scaffold(
      appBar: AppBar(title: const Text('Dati veicolo')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _text(_makeCtrl, 'Marca'),
            const SizedBox(height: 12),
            _text(_modelCtrl, 'Modello'),
            const SizedBox(height: 12),
            _num(_yearCtrl, 'Anno (YYYY)'),
            const SizedBox(height: 12),
            _num(_lengthCtrl, 'Lunghezza (m)'),
            const SizedBox(height: 12),
            _num(_heightCtrl, 'Altezza (m)'),
            const SizedBox(height: 12),
            _num(_weightCtrl, 'Peso (kg)'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submit,
              child: const Text('Salva e vai alla mappa'),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final camper = Camper(
      make: _makeCtrl.text.trim(),
      model: _modelCtrl.text.trim(),
      year: int.tryParse(_yearCtrl.text) ?? 2000,
      length: double.tryParse(_lengthCtrl.text) ?? 0,
      height: double.tryParse(_heightCtrl.text) ?? 0,
      weight: double.tryParse(_weightCtrl.text) ?? 0,
    );
    ref.read(camperProvider.notifier).setCamper(camper);
    context.go('/home');
  }

  TextFormField _text(TextEditingController c, String label) => TextFormField(
        controller: c,
        decoration: InputDecoration(labelText: label),
        validator: (v) => v == null || v.isEmpty ? 'Campo obbligatorio' : null,
      );

  TextFormField _num(TextEditingController c, String label) => TextFormField(
        controller: c,
        decoration: InputDecoration(labelText: label),
        keyboardType: TextInputType.number,
        validator: (v) => v == null || v.isEmpty ? 'Campo obbligatorio' : null,
      );
}