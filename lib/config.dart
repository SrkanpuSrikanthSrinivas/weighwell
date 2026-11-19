/// App settings. Fill these in once and push — no Codemagic variables needed.
///
/// These values are safe to commit: the Supabase "anon" key is public by
/// design (your data is protected by row-level security), and the API URL
/// is just your Vercel address. NEVER put the Anthropic key or the Supabase
/// service-role key here — those live only in Vercel.
///
/// You can still override any of them at build time, e.g.
///   flutter run --dart-define=API_BASE=https://other.vercel.app/api
class AppConfig {
  // 1. Your Vercel backend, ending in /api
  //    e.g. 'https://weighwell-backend.vercel.app/api'
  static const String _apiBase = '';

  // 2. Supabase project: Project Settings → API
  //    e.g. 'https://abcdefgh.supabase.co'
  static const String _supabaseUrl = '';
  static const String _supabaseAnonKey = '';

  // ---------------------------------------------------------------------

  static const String apiBase = String.fromEnvironment('API_BASE', defaultValue: _apiBase);
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: _supabaseUrl);
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: _supabaseAnonKey);

  /// Older builds used RECOGNIZE_URL; still honoured.
  static const String _legacyRecognize = String.fromEnvironment('RECOGNIZE_URL');

  static String get api {
    if (apiBase.isNotEmpty) return apiBase.replaceAll(RegExp(r'/+$'), '');
    if (_legacyRecognize.isNotEmpty) return _legacyRecognize.replaceAll(RegExp(r'/recognize/?$'), '');
    return '';
  }

  static bool get hasApi => api.isNotEmpty;
  static bool get hasAccounts => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Where Google / email sign-in returns to on phones. Must also be listed
  /// in Supabase → Authentication → URL Configuration → Redirect URLs.
  static const String mobileRedirect = 'com.aiqeacademy.weighwell://login-callback/';
}
