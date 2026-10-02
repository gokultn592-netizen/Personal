import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../services/auth_service.dart';
import '../../widgets/nexora_logo.dart';

/// Nexora Login Screen: Exclusively Google Sign-In for academic institutional authentication.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();
  bool _googleBusy = false;
  String? _error;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _error = null;
      _googleBusy = true;
    });
    try {
      final error = await _auth.signInWithGoogle();
      if (!mounted) return;
      if (error != null) {
        setState(() => _error = error);
      }
      // AuthGate handles routing upon auth state change
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NexoraTheme.scaffold,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const NexoraLogo(
                    size: 84,
                    showWordmark: true,
                    showSubtitle: true,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'The verified academic student community. Sign in with your Google account to access your courses, shared notes, and peer matrix.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: NexoraTheme.textSecondary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),

                  if (_error != null) ...[
                    _errorBox(_error!),
                    const SizedBox(height: 20),
                  ],

                  // Exclusive Google Authentication Button
                  FilledButton(
                    onPressed: _googleBusy ? null : _signInWithGoogle,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1E2633),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(
                          color: Color(0xFF334155),
                          width: 1.3,
                        ),
                      ),
                      elevation: 0,
                    ),
                    child: _googleBusy
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _googleLogo(),
                              const SizedBox(width: 14),
                              Text(
                                'Continue with Google',
                                style: GoogleFonts.inter(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 20),

                  // Email/password onboarding. Without this the RegisterScreen
                  // (and the entire email/password auth path) is unreachable —
                  // '/register' was only ever pushed from a dead file.
                  TextButton(
                    onPressed: _googleBusy ? null : _openRegister,
                    style: TextButton.styleFrom(
                      foregroundColor: NexoraTheme.textSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Using a university email? Register instead',
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: NexoraTheme.textSecondary,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: alphaOf(NexoraTheme.primary, 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: alphaOf(NexoraTheme.primary, 0.2),
                      ),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 20,
                          color: NexoraTheme.primary,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Google sign-in guarantees authentic student identity within the community. Profiles must be verified by an admin.',
                            style: TextStyle(
                              color: NexoraTheme.textSecondary,
                              fontSize: 12.5,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openRegister() {
    Navigator.of(context).pushNamed('/register');
  }

  Widget _googleLogo() {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      alignment: Alignment.center,
      child: Text(
        'G',
        style: GoogleFonts.poppins(
          color: const Color(0xFF4285F4),
          fontWeight: FontWeight.w900,
          fontSize: 15.5,
          height: 1.1,
        ),
      ),
    );
  }


  Widget _errorBox(String message) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: alphaOf(NexoraTheme.error, 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: alphaOf(NexoraTheme.error, 0.4)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 18,
              color: NexoraTheme.error,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: NexoraTheme.error,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
}
