import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _chave = 'idioma_app';

/// Idioma escolhido pelo usuário (RF-39, F56). `sistema` segue o aparelho.
enum IdiomaApp {
  sistema,
  pt,
  en,
  es;

  /// `null` = idioma do sistema (o `MaterialApp` resolve pelo aparelho).
  Locale? get locale => switch (this) {
    IdiomaApp.sistema => null,
    IdiomaApp.pt => const Locale('pt'),
    IdiomaApp.en => const Locale('en'),
    IdiomaApp.es => const Locale('es'),
  };
}

IdiomaApp idiomaDeString(String? valor) => switch (valor) {
  'pt' => IdiomaApp.pt,
  'en' => IdiomaApp.en,
  'es' => IdiomaApp.es,
  _ => IdiomaApp.sistema,
};

String idiomaParaString(IdiomaApp idioma) => idioma.name;

class IdiomaNotifier extends AsyncNotifier<IdiomaApp> {
  @override
  Future<IdiomaApp> build() async {
    final prefs = await SharedPreferences.getInstance();
    return idiomaDeString(prefs.getString(_chave));
  }

  Future<void> selecionar(IdiomaApp idioma) async {
    state = AsyncData(idioma);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chave, idiomaParaString(idioma));
  }
}

final idiomaProvider = AsyncNotifierProvider<IdiomaNotifier, IdiomaApp>(
  IdiomaNotifier.new,
);
