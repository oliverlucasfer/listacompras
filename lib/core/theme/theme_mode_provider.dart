import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _chave = 'tema_modo';

ThemeMode temaModoDeString(String? valor) => switch (valor) {
  'claro' => ThemeMode.light,
  'escuro' => ThemeMode.dark,
  _ => ThemeMode.system,
};

String temaModoParaString(ThemeMode modo) => switch (modo) {
  ThemeMode.light => 'claro',
  ThemeMode.dark => 'escuro',
  ThemeMode.system => 'sistema',
};

class TemaModoNotifier extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    return temaModoDeString(prefs.getString(_chave));
  }

  Future<void> definir(ThemeMode modo) async {
    state = AsyncData(modo);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chave, temaModoParaString(modo));
  }
}

final temaModoProvider = AsyncNotifierProvider<TemaModoNotifier, ThemeMode>(
  TemaModoNotifier.new,
);
