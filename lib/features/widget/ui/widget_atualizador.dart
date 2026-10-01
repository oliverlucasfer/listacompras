import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../router.dart';
import '../../listas/domain/lista.dart';
import '../../listas/providers/listas_providers.dart';
import '../domain/widget_service.dart';
import '../providers/widget_providers.dart';

/// Id da última lista aberta (RF-38, F55).
final _ultimaListaIdProvider = FutureProvider<String?>(
  (ref) => ref.watch(ultimaListaServiceProvider).ler(),
);

/// Lista que o widget deve exibir: a última aberta ou, se inválida, a mais
/// recente (RF-38 §5).
final _listaAlvoWidgetProvider = Provider<AsyncValue<Lista?>>((ref) {
  final listas = ref.watch(listasProvider);
  final id = ref.watch(_ultimaListaIdProvider);
  if (listas.isLoading || id.isLoading) return const AsyncLoading<Lista?>();
  final lista = listas.value;
  if (lista == null) return const AsyncData<Lista?>(null);
  final alvoId = id.value;
  return AsyncData<Lista?>(
    lista.where((l) => l.id == alvoId).firstOrNull ?? lista.firstOrNull,
  );
});

/// Payload do widget (título + pendentes), derivado dos streams locais.
final _widgetDadosProvider = Provider<AsyncValue<WidgetDados>>((ref) {
  final alvo = ref.watch(_listaAlvoWidgetProvider);
  if (alvo.isLoading) return const AsyncLoading<WidgetDados>();
  final lista = alvo.value;
  if (lista == null) {
    return const AsyncData<WidgetDados>(
      WidgetDados(titulo: null, pendentes: 0),
    );
  }
  final itens = ref.watch(itensDaListaProvider(lista.id));
  return itens.when(
    loading: () => const AsyncLoading<WidgetDados>(),
    error: (erro, pilha) => AsyncError<WidgetDados>(erro, pilha),
    data: (itensLista) => AsyncData<WidgetDados>(
      WidgetDados(
        titulo: lista.titulo,
        pendentes: itensLista.where((i) => !i.concluido).length,
      ),
    ),
  );
});

/// Mantém o widget da tela inicial atualizado (streams + resume) e trata o
/// toque → `/adicionar` (RF-38, F55). Montado no topo do app.
class WidgetAtualizador extends ConsumerStatefulWidget {
  const WidgetAtualizador({super.key});

  @override
  ConsumerState<WidgetAtualizador> createState() => _WidgetAtualizadorState();
}

class _WidgetAtualizadorState extends ConsumerState<WidgetAtualizador>
    with WidgetsBindingObserver {
  static const Duration _debounce = Duration(milliseconds: 300);

  StreamSubscription<String>? _toques;
  ProviderSubscription<AsyncValue<WidgetDados>>? _dados;
  Timer? _timer;
  WidgetDados? _ultimo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final service = ref.read(widgetServiceProvider);
    _toques = service.toques().listen((_) => _abrirAdicionar());
    _verificarToqueInicial(service);
    _dados = ref.listenManual<AsyncValue<WidgetDados>>(
      _widgetDadosProvider,
      (_, proximo) => _agendar(proximo.value),
      fireImmediately: true,
    );
  }

  Future<void> _verificarToqueInicial(WidgetService service) async {
    try {
      final alvo = await service.toqueInicial();
      if (alvo != null && mounted) _abrirAdicionar();
    } catch (_) {
      // best-effort: o widget nunca bloqueia a UI.
    }
  }

  void _abrirAdicionar() {
    if (!mounted) return;
    ref.read(routerProvider).go('/adicionar');
  }

  void _agendar(WidgetDados? dados) {
    if (dados == null) return;
    _ultimo = dados;
    _timer?.cancel();
    _timer = Timer(_debounce, () => _enviar(dados));
  }

  Future<void> _enviar(WidgetDados dados) async {
    try {
      await ref.read(widgetServiceProvider).atualizar(dados);
    } catch (_) {
      // best-effort: falha ao atualizar o widget é silenciosa.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _agendar(_ultimo);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dados?.close();
    _toques?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
