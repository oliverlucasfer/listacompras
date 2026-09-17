import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deve_bater_com_o_pubspec_quando_a_versao_mudar', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final bruto = RegExp(
      r'^version:\s*(\S+)$',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1)!;
    final partes = bruto.split('+');

    final json =
        jsonDecode(File('web/version.json').readAsStringSync())
            as Map<String, dynamic>;

    expect(
      json['version'],
      partes.first,
      reason: 'web/version.json alimenta o package_info_plus no web (F18-T04)',
    );
    expect(json['build_number'], partes.length > 1 ? partes[1] : '0');
  });
}
