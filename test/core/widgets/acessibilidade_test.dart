import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/core/theme/app_theme.dart';
import 'package:lista_compras/core/widgets/app_banner.dart';
import 'package:lista_compras/core/widgets/app_botao.dart';
import 'package:lista_compras/core/widgets/app_estado_erro.dart';
import 'package:lista_compras/core/widgets/app_estado_vazio.dart';

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.claro,
  home: Scaffold(body: child),
);

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

  testWidgets('deve_anunciar_banner_como_live_region_quando_offline', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        const AppBanner(
          tipo: AppBannerTipo.offline,
          mensagem: 'Sem conexão — alterações serão sincronizadas depois',
        ),
      ),
    );

    expect(
      tester.getSemantics(
        find.bySemanticsLabel(
          'Sem conexão — alterações serão sincronizadas depois',
        ),
      ),
      matchesSemantics(
        label: 'Sem conexão — alterações serão sincronizadas depois',
        isLiveRegion: true,
      ),
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

    expect(find.bySemanticsLabel(AppStrings.carregando), findsOneWidget);
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
}
