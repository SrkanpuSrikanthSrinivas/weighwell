import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  bool _busy = false;
  bool _showEmail = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _google() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthService>().signInWithGoogle();
    } catch (e) {
      _error = 'Google sign-in did not work. Please try again.';
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _sendLink() async {
    final email = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthService>().sendEmailLink(email);
      _sent = true;
    } catch (e) {
      _error = 'Could not send the email. Please try again in a minute.';
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(22)),
                      child: const Icon(Icons.monitor_weight_outlined, color: Colors.white, size: 40),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text('WeighWell', textAlign: TextAlign.center, style: TextStyle(fontSize: 32, fontWeight: w800)),
                  const SizedBox(height: 6),
                  const Text('Eat right. Move more. See your progress.',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 17, color: AppColors.muted)),
                  const SizedBox(height: 28),
                  const _Point(Icons.restaurant, 'Weigh or scan food to see calories and protein'),
                  const _Point(Icons.fitness_center, 'Plan and log your weekly exercise'),
                  const _Point(Icons.insights, 'Clear daily goals and an AI coach'),
                  const _Point(Icons.cloud_done_outlined, 'Your data is backed up and works on phone and web'),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: _busy ? null : _google,
                    icon: const Icon(Icons.login),
                    label: const Text('Continue with Google'),
                  ),
                  const SizedBox(height: 12),
                  if (!_showEmail)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                      onPressed: _busy ? null : () => setState(() => _showEmail = true),
                      icon: const Icon(Icons.mail_outline),
                      label: const Text('Continue with email'),
                    )
                  else if (_sent)
                    AppCard(
                      color: AppColors.greenSoft,
                      child: Text(
                        'Check your email. We sent a sign-in link to ${_email.text.trim()}. Open it on this device.',
                        style: const TextStyle(fontSize: 16, fontWeight: w700, color: AppColors.greenDark),
                      ),
                    )
                  else ...[
                    TextField(
                      controller: _email,
                      autofocus: true,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      style: const TextStyle(fontSize: 18),
                      decoration: const InputDecoration(labelText: 'Email address'),
                      onSubmitted: (_) => _sendLink(),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                      onPressed: _busy ? null : _sendLink,
                      child: const Text('Email me a sign-in link'),
                    ),
                  ],
                  if (_busy) ...[
                    const SizedBox(height: 16),
                    const Center(child: CircularProgressIndicator()),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 15, color: Color(0xFF8A3A0B), fontWeight: w700)),
                  ],
                  const SizedBox(height: 24),
                  const Text(
                    'No password needed. Your data is private to your account and you can delete it any time in Settings.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: AppColors.greenSoft, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: AppColors.green, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: w700))),
          ],
        ),
      );
}
