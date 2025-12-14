import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api/auth_api_client.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  final _authApi = const AuthApiClient('http://127.0.0.1:3000');

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final pwd = _passwordController.text;
    final pwd2 = _confirmPasswordController.text;

    if (name.isEmpty || email.isEmpty || pwd.isEmpty || pwd2.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compila tutti i campi')),
      );
      return;
    }
    if (pwd != pwd2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le password non coincidono')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authApi.register(username: name, email: email, password: pwd);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registrazione completata. Controlla la mail.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRegisterWithGoogle() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Registrazione con Google sarà disponibile solo su iOS/Android in una prossima versione.'),
      ),
    );

    // In futuro, quando abilitiamo davvero il social su mobile:
    // final idToken = await _getGoogleIdToken(); // condiviso con LoginScreen
    // if (idToken == null) return;
    // await ref.read(authControllerProvider.notifier).loginWithGoogle(idToken);
    // if (!mounted) return;
    // context.go('/home');
  }

  Future<void> _handleRegisterWithApple() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Registrazione con Apple sarà disponibile solo su iOS/Android in una prossima versione.'),
      ),
    );

    // In futuro:
    // final idToken = await _getAppleIdToken();
    // if (idToken == null) return;
    // await ref.read(authControllerProvider.notifier).loginWithApple(idToken);
    // if (!mounted) return;
    // context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF071814),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text('Crea un account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Crea un account',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              const _FieldLabel('Nome'),
              const SizedBox(height: 8),
              _RegisterTextField(
                controller: _nameController,
                hintText: 'Inserisci il tuo nome',
              ),
              const SizedBox(height: 16),
              const _FieldLabel('Email'),
              const SizedBox(height: 8),
              _RegisterTextField(
                controller: _emailController,
                hintText: 'Inserisci la tua email',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              const _FieldLabel('Password'),
              const SizedBox(height: 8),
              _RegisterTextField(
                controller: _passwordController,
                hintText: 'Crea una password',
                obscureText: true,
              ),
              const SizedBox(height: 16),
              const _FieldLabel('Conferma Password'),
              const SizedBox(height: 8),
              _RegisterTextField(
                controller: _confirmPasswordController,
                hintText: 'Conferma la password',
                obscureText: true,
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  'Oppure registrati con',
                  style: TextStyle(
                    color: Color(0xFFe0e0e0),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _SocialButton(
                label: 'Registrati con Google',
                onPressed: _handleRegisterWithGoogle,
              ),
              const SizedBox(height: 10),
              _SocialButton(
                label: 'Registrati con Apple',
                onPressed: _handleRegisterWithApple,
              ),
              const SizedBox(height: 10),
              _SocialButton(
                label: 'Registrati con Facebook',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Registrazione con Facebook non ancora implementata'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1b7f6b),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  onPressed: _isLoading ? null : _handleRegister,
                  child: _isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Registrati'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _RegisterTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final bool obscureText;
  final TextInputType? keyboardType;

  const _RegisterTextField({
    this.controller,
    required this.hintText,
    this.obscureText = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textAlign: TextAlign.start,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          color: Color(0xFFd6f1e5),
          fontSize: 13,
        ),
        filled: true,
        fillColor: const Color(0xFF14513f),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: Color(0xFF1b7f6b)),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _SocialButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          side: BorderSide.none,
        ),
        onPressed: onPressed,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }
}
