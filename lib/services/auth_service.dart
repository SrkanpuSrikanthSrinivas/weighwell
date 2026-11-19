import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;

import '../config.dart';
import '../state/app_state.dart';
import 'auth_token.dart';
import 'cloud_sync.dart';

/// Sign-in with Google or an email link (Supabase Auth), and keeping the
/// signed-in person's data synced.
class AuthService extends ChangeNotifier {
  AuthService(this._state);

  final AppState _state;
  StreamSubscription<AuthState>? _sub;
  String? _attachedUser;
  bool _restoring = true;

  /// False when lib/config.dart has no Supabase settings: the app then runs
  /// on this device only (handy while setting things up).
  bool get enabled => AppConfig.hasAccounts;

  /// True until we know whether someone is signed in and their data is loaded.
  bool get restoring => enabled && _restoring;

  SupabaseClient get _db => Supabase.instance.client;

  User? get user => enabled ? _db.auth.currentUser : null;
  bool get signedIn => !enabled || user != null;

  String get displayName {
    final u = user;
    if (u == null) return '';
    final meta = u.userMetadata ?? const {};
    final name = (meta['full_name'] ?? meta['name']) as String?;
    return (name != null && name.trim().isNotEmpty) ? name.trim() : (u.email ?? '');
  }

  String get firstName => displayName.split(RegExp(r'[\s@]')).first;
  String get email => user?.email ?? '';

  void start() {
    if (!enabled) return;
    _sub = _db.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      if (session != null) {
        await _attach(session.user.id);
      } else {
        _attachedUser = null;
      }
      _restoring = false;
      notifyListeners();
    });
    // If there is no saved session at all, stop showing the spinner.
    if (_db.auth.currentSession == null) {
      _restoring = false;
    }
  }

  Future<void> _attach(String uid) async {
    if (_attachedUser == uid) return;
    _attachedUser = uid;
    _restoring = true;
    notifyListeners();
    await _state.attachCloud(SupabaseBackend(_db));
  }

  Future<void> signInWithGoogle() async {
    await _db.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : AppConfig.mobileRedirect,
      authScreenLaunchMode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    );
  }

  Future<void> sendEmailLink(String email) async {
    await _db.auth.signInWithOtp(
      email: email.trim(),
      emailRedirectTo: kIsWeb ? null : AppConfig.mobileRedirect,
    );
  }

  Future<void> signOut() async {
    await _state.detachCloud();
    _attachedUser = null;
    await _db.auth.signOut();
    notifyListeners();
  }

  /// Deletes all saved data and the account itself (App Store requirement).
  Future<void> deleteAccount() async {
    // 1. The account's data (allowed by row-level security).
    await _state.deleteCloudData();
    // 2. The login itself needs the server's admin key, so the backend does it.
    if (AppConfig.hasApi) {
      final res = await http.post(Uri.parse('${AppConfig.api}/delete-account'), headers: apiHeaders(), body: jsonEncode({}));
      if (res.statusCode != 200) {
        debugPrint('Delete account failed: ${res.statusCode} ${res.body}');
      }
    }
    _attachedUser = null;
    await _db.auth.signOut();
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
