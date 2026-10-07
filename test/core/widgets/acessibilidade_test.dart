import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/theme/app_theme.dart';
import 'package:lista_compras/core/widgets/app_banner.dart';
import 'package:lista_compras/core/widgets/app_botao.dart';
import 'package:lista_compras/core/widgets/app_estado_erro.dart';
import 'package:lista_compras/core/widgets/app_estado_vazio.dart';

import '../../support/app_teste.dart';

Widget _app(Widget child) =>
    appTeste(Scaffold(body: child), theme: AppTheme.claro);

void main() {
  testWidgets(
    'deve_anunciar_um_unico_rotulo_quando_estado_vazio_tem_titulo_e_descricao',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          const AppEstadoVazio(
            titulo: 'Nada aqui',
            descricao: 'Crie uma lista',
          ),
        ),
      );

      expect(
        find.bySemanticsLabel('Nada aqui. Crie uma lista'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Nada aqui'), findsNothing);

      handle.dispose();
    },
  );

  testWidgets('deve_manter_cta_fora_do_rotulo_quando_estado_vazio', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var criou = false;
    await tester.pumpWidget(
      _app(
        AppEstadoVazio(
          titulo: 'Nada aqui',
          descricao: 'Crie uma lista',
          acao: FilledButton(
            onPressed: () => criou = true,
            child: const Text('Criar'),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Criar'), findsOneWidget);
    await tester.tap(find.text('Criar'));
    expect(criou, isTrue);

    handle.dispose();
  });

  testWidgets('deve_anunciar_banner_como_live_region_quando_erro', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        const AppBanner(
          tipo: AppBannerTipo.erro,
          mensagem: 'Sem conexão com o servidor',
        ),
      ),
    );

    expect(find.bySemanticsLabel('Sem conexão com o servidor'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Sem conexão com o servidor')),
      matchesSemantics(label: 'Sem conexão com o servidor', isLiveRegion: true),
    );

    handle.dispose();
  });

  testWidgets('deve_anunciar_banner_como_live_region_quando_aviso', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        const AppBanner(
          tipo: AppBannerTipo.aviso,
          mensagem: 'Atenção: item duplicado',
        ),
      ),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('Atenção: item duplicado')),
      matchesSemantics(label: 'Atenção: item duplicado', isLiveRegion: true),
    );

    handle.dispose();
  });

  testWidgets('deve_anunciar_carregamento_quando_botao_carregando', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(AppBotao(rotulo: 'Entrar', carregando: true, onPressed: () {})),
    );

    expect(find.bySemanticsLabel('Carregando...'), findsOneWidget);
    expect(find.bySemanticsLabel('Entrar'), findsOneWidget);

    handle.dispose();
  });

  testWidgets('deve_ter_alvos_rotulados_nos_estados_e_botoes', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            AppEstadoVazio(
              titulo: 'Nada aqui',
              descricao: 'Crie uma lista',
              acao: AppBotao(
                rotulo: 'Criar',
                expandido: false,
                onPressed: () {},
              ),
            ),
            AppEstadoErro(mensagem: 'Falhou', onRetentar: () {}),
            const AppBanner(tipo: AppBannerTipo.erro, mensagem: 'Erro'),
            AppBotao(rotulo: 'Entrar', carregando: true, onPressed: () {}),
          ],
        ),
      ),
    );

    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));

    handle.dispose();
  });

  testWidgets('deve_nao_estourar_quando_botao_com_rotulo_longo_em_2x', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      _app(
        AppBotao(
          rotulo: 'Importar lista',
          icone: Icons.playlist_add,
          onPressed: () {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
