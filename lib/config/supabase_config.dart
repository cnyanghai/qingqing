/// Supabase configuration
class SupabaseConfig {
  SupabaseConfig._();

  static const String supabaseUrl = 'https://brilcoktloprynjbqdis.supabase.co';

  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJyaWxjb2t0bG9wcnluamJxZGlzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMxNzg4NDUsImV4cCI6MjA4ODc1NDg0NX0.CXwZe0th9ln30nuFwx5Dop8arcSzYHT06KYXWBaOnDw';

  /// Service role key for admin operations (bypasses RLS)
  /// Injected at build time via --dart-define=SUPABASE_SERVICE_KEY=...
  static const String supabaseServiceKey =
      String.fromEnvironment('SUPABASE_SERVICE_KEY');
}
