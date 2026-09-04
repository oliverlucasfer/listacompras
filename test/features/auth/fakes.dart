import 'package:lista_compras/features/auth/data/supabase_auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

var _inicializado = false;

Future<void> inicializarSupabaseTeste() async {
  SharedPreferences.setMockInitialValues({});
  if (!_inicializado) {
    await Supabase.initialize(
      url: 'http://127.0.0.1:54321',
      publishableKey: 'test-key',
    );
    _inicializado = true;
  }
}

class FakeAuthRepository extends SupabaseAuthRepository {
  FakeAuthRepository() : super(Supabase.instance.client);

  bool entrarChamado = false;
  bool registrarChamado = false;
  bool recuperacaoChamada = false;
  bool reenvioChamado = false;

  Future<AuthResponse> Function(String email, String senha)? onEntrar;
  Future<AuthResponse> Function(String email, String senha)? onRegistrar;
  Future<void> Function(String email)? onEnviarRecuperacao;
  Future<void> Function(String email)? onReenviar;

  @override
  Future<AuthResponse> entrar({
    required String email,
    required String senha,
  }) async {
    entrarChamado = true;
    final fn = onEntrar;
    if (fn == null) throw StateError('onEntrar nao configurado');
    return fn(email, senha);
  }

  @override
  Future<AuthResponse> registrar({
    required String email,
    required String senha,
  }) async {
    registrarChamado = true;
    final fn = onRegistrar;
    if (fn == null) throw StateError('onRegistrar nao configurado');
    return fn(email, senha);
  }

  @override
  Future<void> enviarRecuperacaoSenha(String email) async {
    recuperacaoChamada = true;
    final fn = onEnviarRecuperacao;
    if (fn == null) throw StateError('onEnviarRecuperacao nao configurado');
    return fn(email);
  }

  @override
  Future<void> reenviarVerificacao(String email) async {
    reenvioChamado = true;
    final fn = onReenviar;
    if (fn == null) throw StateError('onReenviar nao configurado');
    return fn(email);
  }
}
