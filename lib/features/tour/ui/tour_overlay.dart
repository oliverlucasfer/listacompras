import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens/app_elevation.dart';
import '../../../core/theme/tokens/app_motion.dart';
import '../../../core/theme/tokens/app_radius.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/widgets/app_botao.dart';
import '../tour_controller.dart';
import '../tour_step.dart';

const double _margem = AppSpacing.lg;
const double _folga = AppSpacing.sm;
const double _alturaMinimaBolha = 160;
const double _opacidadeScrim = 0.6;

/// `Rect` do alvo em coordenadas globais (doc 05 / spec F46). O overlay ocupa a
/// tela inteira, então global e local coincidem.
Rect? _rectDoAlvo(GlobalKey alvo) {
  final contexto = alvo.currentContext;
  if (contexto == null) return null;
  final render = contexto.findRenderObject();
  if (render is! RenderBox || !render.hasSize) return null;
  return render.localToGlobal(Offset.zero) & render.size;
}

/// Scrim escurecido com recorte (spotlight) sobre o `Rect` do alvo e halo na
/// cor primária. Puramente decorativo: não recebe toques (doc 15 §4).
class Spotlight extends StatelessWidget {
  const Spotlight({super.key, required this.alvo});

  final GlobalKey alvo;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _SpotlightPainter(
        alvo: _rectDoAlvo(alvo),
        scrim: cores.scrim,
        halo: cores.primary,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({
    required this.alvo,
    required this.scrim,
    required this.halo,
  });

  final Rect? alvo;
  final Color scrim;
  final Color halo;

  @override
  void paint(Canvas canvas, Size size) {
    final tudo = Path()..addRect(Offset.zero & size);
    final preenchimento = Paint()
      ..color = scrim.withValues(alpha: _opacidadeScrim);
    final recorte = alvo;
    if (recorte == null) {
      canvas.drawPath(tudo, preenchimento);
      return;
    }
    final janela = RRect.fromRectAndRadius(
      recorte.inflate(_folga),
      const Radius.circular(AppRadius.md),
    );
    canvas.drawPath(
      Path.combine(PathOperation.difference, tudo, Path()..addRRect(janela)),
      preenchimento,
    );
    canvas.drawRRect(
      janela,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = halo,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.alvo != alvo || old.scrim != scrim || old.halo != halo;
}

/// Overlay do tour: spotlight sobre o passo atual e a bolha com os controles.
/// Só avança pelos botões — o resto da tela segue acessível (spec §4/§7).
class TourOverlay extends ConsumerWidget {
  const TourOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(tourControllerProvider);
    final passo = estado.atual;
    if (passo == null) return const SizedBox.shrink();

    final controlador = ref.read(tourControllerProvider.notifier);
    final duracao = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppMotion.media;

    return AnimatedSwitcher(
      duration: duracao,
      child: _Passo(
        key: ValueKey(passo.id),
        estado: estado,
        passo: passo,
        onPular: controlador.pular,
        onAnterior: estado.indice == 0 ? null : controlador.anterior,
        onProximo: controlador.proximo,
      ),
    );
  }
}

class _Passo extends StatelessWidget {
  const _Passo({
    super.key,
    required this.estado,
    required this.passo,
    required this.onPular,
    required this.onAnterior,
    required this.onProximo,
  });

  final TourEstado estado;
  final TourStep passo;
  final VoidCallback onPular;
  final VoidCallback? onAnterior;
  final VoidCallback onProximo;

  @override
  Widget build(BuildContext context) {
    final tamanho = MediaQuery.sizeOf(context);
    final alvo = _rectDoAlvo(passo.alvo);
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(child: Spotlight(alvo: passo.alvo)),
        ),
        _posicionar(context, tamanho, alvo),
      ],
    );
  }

  Widget _posicionar(BuildContext context, Size tamanho, Rect? alvo) {
    final conteudo = _Bolha(
      estado: estado,
      passo: passo,
      onPular: onPular,
      onAnterior: onAnterior,
      onProximo: onProximo,
    );
    if (alvo == null) return _noCentro(conteudo, tamanho);
    return switch (_escolherPosicao(alvo, tamanho)) {
      TourPosicao.centro => _noCentro(conteudo, tamanho),
      TourPosicao.abaixo => _abaixo(context, conteudo, alvo, tamanho),
      TourPosicao.acima => _acima(context, conteudo, alvo, tamanho),
    };
  }

  TourPosicao _escolherPosicao(Rect alvo, Size tamanho) {
    final abaixo = tamanho.height - alvo.bottom - _margem;
    final acima = alvo.top - _margem;
    final cabeAbaixo = abaixo >= _alturaMinimaBolha;
    final cabeAcima = acima >= _alturaMinimaBolha;
    return switch (passo.posicao) {
      TourPosicao.centro => TourPosicao.centro,
      TourPosicao.abaixo =>
        cabeAbaixo
            ? TourPosicao.abaixo
            : (cabeAcima ? TourPosicao.acima : TourPosicao.centro),
      TourPosicao.acima =>
        cabeAcima
            ? TourPosicao.acima
            : (cabeAbaixo ? TourPosicao.abaixo : TourPosicao.centro),
    };
  }

  Widget _noCentro(Widget conteudo, Size tamanho) => Positioned.fill(
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: tamanho.width - _margem * 2,
          maxHeight: tamanho.height - _margem * 2,
        ),
        child: SingleChildScrollView(child: conteudo),
      ),
    ),
  );

  Widget _abaixo(
    BuildContext context,
    Widget conteudo,
    Rect alvo,
    Size tamanho,
  ) {
    final topo = alvo.bottom + _folga;
    final disponivel = tamanho.height - topo - _margem;
    return Positioned(
      left: _margem,
      right: _margem,
      top: topo,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: disponivel),
        child: SingleChildScrollView(
          child: _comSeta(context, conteudo, alvo, tamanho, paraBaixo: false),
        ),
      ),
    );
  }

  Widget _acima(
    BuildContext context,
    Widget conteudo,
    Rect alvo,
    Size tamanho,
  ) {
    final base = tamanho.height - alvo.top + _folga;
    final disponivel = alvo.top - _margem - _folga;
    return Positioned(
      left: _margem,
      right: _margem,
      bottom: base,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: disponivel),
        child: SingleChildScrollView(
          child: _comSeta(context, conteudo, alvo, tamanho, paraBaixo: true),
        ),
      ),
    );
  }

  Widget _comSeta(
    BuildContext context,
    Widget conteudo,
    Rect alvo,
    Size tamanho, {
    required bool paraBaixo,
  }) {
    final largura = tamanho.width - _margem * 2;
    final x = ((alvo.center.dx - _margem) / largura * 2 - 1).clamp(-0.85, 0.85);
    final seta = SizedBox(
      height: _folga,
      child: Align(
        alignment: Alignment(x, 0),
        child: CustomPaint(
          size: Size(_folga * 2, _folga),
          painter: _SetaPainter(
            cor: Theme.of(context).colorScheme.surfaceContainerHigh,
            paraBaixo: paraBaixo,
          ),
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: paraBaixo ? [conteudo, seta] : [seta, conteudo],
    );
  }
}

class _SetaPainter extends CustomPainter {
  const _SetaPainter({required this.cor, required this.paraBaixo});

  final Color cor;
  final bool paraBaixo;

  @override
  void paint(Canvas canvas, Size size) {
    final caminho = Path();
    if (paraBaixo) {
      caminho
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height);
    } else {
      caminho
        ..moveTo(size.width / 2, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height);
    }
    canvas.drawPath(caminho..close(), Paint()..color = cor);
  }

  @override
  bool shouldRepaint(_SetaPainter old) =>
      old.cor != cor || old.paraBaixo != paraBaixo;
}

class _Bolha extends StatelessWidget {
  const _Bolha({
    required this.estado,
    required this.passo,
    required this.onPular,
    required this.onAnterior,
    required this.onProximo,
  });

  final TourEstado estado;
  final TourStep passo;
  final VoidCallback onPular;
  final VoidCallback? onAnterior;
  final VoidCallback onProximo;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final texto = Theme.of(context).textTheme;
    final total = estado.passos.length;
    final numero = estado.indice + 1;
    final ultimo = numero == total;

    return Semantics(
      container: true,
      liveRegion: true,
      explicitChildNodes: true,
      label: AppStrings.tourPasso(numero, total),
      child: Material(
        color: cores.surfaceContainerHigh,
        elevation: AppElevation.nivel3,
        borderRadius: AppRadius.lgTodos,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      passo.titulo(context.l10n),
                      style: texto.titleMedium,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text('$numero/$total', style: texto.labelMedium),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(passo.corpo(context.l10n), style: texto.bodyMedium),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                alignment: WrapAlignment.end,
                children: [
                  AppBotao(
                    rotulo: AppStrings.tourPular,
                    variante: AppBotaoVariante.texto,
                    expandido: false,
                    onPressed: onPular,
                  ),
                  AppBotao(
                    rotulo: AppStrings.tourAnterior,
                    variante: AppBotaoVariante.outlined,
                    expandido: false,
                    onPressed: onAnterior,
                  ),
                  AppBotao(
                    rotulo: ultimo
                        ? AppStrings.tourConcluir
                        : AppStrings.tourProximo,
                    expandido: false,
                    onPressed: onProximo,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
