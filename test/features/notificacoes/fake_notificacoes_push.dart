import 'package:lista_compras/features/notificacoes/domain/notificacoes_push.dart';

class NotificacoesPushFake implements NotificacoesPush {
  NotificacoesPushFake({
    this.suportado = true,
    this.permissao = PermissaoPush.concedida,
  });

  @override
  bool suportado;
  PermissaoPush permissao;
  String? token = 'token-fake';
  bool apagouToken = false;
  int pedidos = 0;

  final _refresh = <String>[];
  final _toque = <Map<String, Object?>>[];
  final _recebida = <Map<String, Object?>>[];
  Map<String, Object?>? inicial;

  @override
  Future<PermissaoPush> pedirPermissao() async {
    pedidos++;
    return permissao;
  }

  @override
  Future<String?> obterToken() async => token;

  @override
  Future<void> apagarToken() async {
    apagouToken = true;
    token = null;
  }

  @override
  Stream<String> get onTokenRefresh => Stream.fromIterable(_refresh);

  @override
  Stream<Map<String, Object?>> get onToque => Stream.fromIterable(_toque);

  @override
  Future<Map<String, Object?>?> toqueInicial() async => inicial;

  @override
  Stream<Map<String, Object?>> get onRecebida => Stream.fromIterable(_recebida);
}
