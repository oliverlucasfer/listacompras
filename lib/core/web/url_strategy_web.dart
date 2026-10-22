import 'package:flutter_web_plugins/url_strategy.dart';

/// URLs limpas no web (doc 05 §2, ADR-012); hash apenas no build de demo
/// publicado no GitHub Pages (`--dart-define=DEMO=true`), onde não há rewrite.
void usarPathUrlStrategy() {
  if (const bool.fromEnvironment('DEMO')) {
    setUrlStrategy(HashUrlStrategy());
    return;
  }
  usePathUrlStrategy();
}
