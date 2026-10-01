import 'package:shared_preferences/shared_preferences.dart';

const _chaveUltimaLista = 'ultima_lista_id';

class UltimaListaService {
  Future<void> registrar(String listaId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chaveUltimaLista, listaId);
  }

  Future<String?> ler() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_chaveUltimaLista);
  }
}
