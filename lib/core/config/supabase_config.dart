/// Configuração Supabase build-time (doc 00 §3.4). Defaults apontam para o
/// ambiente local; produção via --dart-define. A anon key é pública por
/// design — a proteção é RLS (doc 02).
const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'http://127.0.0.1:54321',
);
const supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH',
);
