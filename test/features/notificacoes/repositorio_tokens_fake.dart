import 'package:lista_compras/features/notificacoes/data/push_tokens_repository.dart';

class RepositorioTokensFake implements PushTokensRepository {
  final registrados = <String>[];
  final removidos = <String>[];

  @override
  Future<void> registrar({
    required String token,
    required String plataforma,
  }) async {
    registrados.add(token);
  }

  @override
  Future<void> remover(String token) async {
    removidos.add(token);
  }
}
