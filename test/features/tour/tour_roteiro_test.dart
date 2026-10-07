import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/features/tour/tour_roteiro.dart';
import 'package:lista_compras/features/tour/tour_step.dart';
import 'package:lista_compras/l10n/app_localizations_pt.dart';

TourStep _passo(String id) =>
    passosEtapa2.firstWhere((TourStep p) => p.id == id);

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('deve_ter_quatro_passos_na_etapa1_na_ordem_da_home', () {
    expect(passosEtapa1.map((p) => p.id).toList(), <String>[
      'lista.criar',
      'lista.busca',
      'lista.historico',
      'lista.config',
    ]);
  });

  test('deve_ter_sete_passos_na_etapa2_na_ordem_da_lista', () {
    expect(passosEtapa2.map((p) => p.id).toList(), <String>[
      'recursos.nome',
      'recursos.adicionar',
      'recursos.unidade',
      'recursos.importar',
      'recursos.marcar',
      'recursos.mercado',
      'recursos.menu',
    ]);
  });

  test('deve_ter_dois_passos_na_etapa3_na_ordem_do_historico', () {
    expect(passosEtapa3.map((p) => p.id).toList(), <String>[
      'historico.resumo',
      'historico.estatisticas',
    ]);
  });

  test('deve_citar_camera_nos_passos_quando_plataforma_tem_ocr', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final l = AppLocalizationsPt();

    expect(_passo('recursos.importar').corpo(l), contains('fotografe'));
    expect(_passo('recursos.mercado').corpo(l), contains('câmera'));
    expect(_passo('recursos.marcar').corpo(l), contains('câmera'));
  });

  test('deve_omitir_camera_nos_passos_quando_plataforma_sem_ocr', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final l = AppLocalizationsPt();

    for (final id in const [
      'recursos.importar',
      'recursos.mercado',
      'recursos.marcar',
    ]) {
      final corpo = _passo(id).corpo(l);
      expect(corpo, isNot(contains('câmera')), reason: id);
      expect(corpo, isNot(contains('fotografe')), reason: id);
    }
  });
}
