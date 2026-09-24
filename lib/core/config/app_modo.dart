import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Modo de build do app (RF-31, F41): o flavor `prod` é colaborativo (conta +
/// Supabase); o flavor `lite` roda 100% no aparelho, sem conta nem rede.
enum AppModo { colaborativo, lite }

/// Capacidades ligadas em cada modo. A UI e as rotas decidem por estas flags —
/// **nunca** por [AppModo] diretamente.
class AppCapacidades {
  const AppCapacidades({
    required this.nuvem,
    required this.colaboracao,
    required this.notificacoes,
    required this.backup,
  });

  /// Supabase (auth + sync + realtime).
  final bool nuvem;

  /// Convites, membros e listas compartilhadas.
  final bool colaboracao;

  /// FCM/push.
  final bool notificacoes;

  /// Exportar/importar backup local.
  final bool backup;

  static const colaborativo = AppCapacidades(
    nuvem: true,
    colaboracao: true,
    notificacoes: true,
    backup: true,
  );

  static const lite = AppCapacidades(
    nuvem: false,
    colaboracao: false,
    notificacoes: false,
    backup: true,
  );
}

/// Sobrescrito no container raiz de cada entrypoint (`main.dart` /
/// `main_lite.dart`). O default é o modo colaborativo para que testes e o app
/// atual sigam sem override.
final capacidadesProvider = Provider<AppCapacidades>(
  (ref) => AppCapacidades.colaborativo,
);
