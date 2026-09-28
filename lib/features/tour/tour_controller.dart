import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_modo.dart';
import 'tour_roteiro.dart';
import 'tour_step.dart';

enum TourEtapa { primeira, recursos }

String _chave(TourEtapa e) =>
    e == TourEtapa.primeira ? 'tour_etapa1_visto' : 'tour_etapa2_visto';

/// Conclusão de cada etapa (SharedPreferences), espelho de `OnboardingNotifier`.
class TourVistoNotifier extends AsyncNotifier<bool> {
  TourVistoNotifier(this.etapa);

  final TourEtapa etapa;

  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_chave(etapa)) ?? false;
  }

  Future<void> marcarVista(TourEtapa etapa) async {
    state = const AsyncData(true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_chave(etapa), true);
  }
}

final tourEtapaVistaProvider =
    AsyncNotifierProvider.family<TourVistoNotifier, bool, TourEtapa>(
      TourVistoNotifier.new,
    );

class TourEstado {
  const TourEstado({
    this.ativo = false,
    this.passos = const [],
    this.indice = 0,
    this.etapa,
  });
  final bool ativo;
  final List<TourStep> passos;
  final int indice;
  final TourEtapa? etapa;
  TourStep? get atual =>
      ativo && indice < passos.length ? passos[indice] : null;
  TourEstado copyWith({bool? ativo, List<TourStep>? passos, int? indice}) =>
      TourEstado(
        ativo: ativo ?? this.ativo,
        passos: passos ?? this.passos,
        indice: indice ?? this.indice,
        etapa: etapa,
      );
}

class TourController extends Notifier<TourEstado> {
  @override
  TourEstado build() => const TourEstado();

  /// Inicia uma etapa; retorna false se não houver passos elegíveis/montados.
  ///
  /// Um alvo só entra na fila se estiver **de fato visível**: `currentContext`
  /// sozinho não basta — no `IndexedStack` do shell as abas ocultas continuam
  /// montadas (offstage) e o spotlight apontaria para um widget invisível.
  bool iniciar(TourEtapa etapa) {
    final cap = ref.read(capacidadesProvider);
    final lista = (etapa == TourEtapa.primeira ? passosEtapa1 : passosEtapa2)
        .where((p) => p.elegivel(cap))
        .where((p) => _alvoVisivel(p.alvo))
        .toList();
    if (lista.isEmpty) return false;
    state = TourEstado(ativo: true, passos: lista, indice: 0, etapa: etapa);
    return true;
  }

  static bool _alvoVisivel(GlobalKey alvo) {
    final ctx = alvo.currentContext;
    if (ctx == null || !ctx.mounted) return false;
    final render = ctx.findRenderObject();
    if (render is! RenderBox || !render.attached || !render.hasSize) {
      return false;
    }
    // `visitAncestorElements` percorre a cadeia até a raiz; se algum ancestral
    // for `Offstage`/`Visibility` invisível ou tiver tamanho zero, o alvo está
    // escondido (ex.: aba não selecionada no IndexedStack).
    var visivel = true;
    ctx.visitAncestorElements((element) {
      final widget = element.widget;
      if (widget is Offstage && widget.offstage) {
        visivel = false;
        return false;
      }
      if (widget is Visibility && !widget.visible) {
        visivel = false;
        return false;
      }
      return true;
    });
    if (!visivel || render.size.isEmpty) return false;
    final origem = render.localToGlobal(Offset.zero);
    final tela = WidgetsBinding.instance.platformDispatcher.views.first;
    final tam = tela.physicalSize / tela.devicePixelRatio;
    final rect = origem & render.size;
    return rect.overlaps(Offset.zero & tam);
  }

  Future<void> proximo() async {
    final i = state.indice + 1;
    if (i >= state.passos.length) return _encerrarMarcandoVista();
    state = state.copyWith(indice: i);
  }

  void anterior() {
    if (state.indice == 0) return;
    state = state.copyWith(indice: state.indice - 1);
  }

  Future<void> pular() => _encerrarMarcandoVista();

  Future<void> _encerrarMarcandoVista() async {
    final etapa = state.etapa;
    _encerrar();
    if (etapa != null) {
      await ref.read(tourEtapaVistaProvider(etapa).notifier).marcarVista(etapa);
    }
  }

  void _encerrar() => state = const TourEstado();
}

final tourControllerProvider = NotifierProvider<TourController, TourEstado>(
  TourController.new,
);
