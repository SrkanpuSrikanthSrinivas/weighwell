import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';

/// Headers for calls to our own backend: the signed-in user's token, so the
/// server can refuse strangers (it pays for the AI calls).
Map<String, String> apiHeaders() {
  final h = {'Content-Type': 'application/json'};
  if (!AppConfig.hasAccounts) return h;
  try {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token != null) h['Authorization'] = 'Bearer $token';
  } catch (_) {
    // Supabase not initialised (accounts switched off).
  }
  return h;
}
