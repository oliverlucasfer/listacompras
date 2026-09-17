import 'package:flutter/foundation.dart';

/// URL pública do app web (usada pelo nativo para montar links compartilháveis).
/// Em builds de release do nativo, definir
/// `--dart-define=APP_WEB_URL=https://<domínio>`; sem ele, links compartilhados
/// apontam para o default de dev.
const appWebUrl = String.fromEnvironment(
  'APP_WEB_URL',
  defaultValue: 'http://localhost:8080',
);

/// Scheme registrado no AndroidManifest/Info.plist (doc 05 §6.1).
const deepLinkNativo = 'br.com.oliverlucas.listacompras://';

/// Origem usada para links: a atual no web; [appWebUrl] no nativo.
String origemWeb({bool web = kIsWeb, Uri? base}) =>
    web ? (base ?? Uri.base).origin : appWebUrl;

/// URL de retorno do fluxo de auth (verificação de e-mail / recuperação).
String redirectAuth({bool web = kIsWeb, Uri? base}) => web
    ? '${(base ?? Uri.base).origin}/login-callback'
    : '${deepLinkNativo}login-callback';

/// Link de convite compartilhável (doc 08 §1.1).
String linkConviteDe(String token, {bool web = kIsWeb, Uri? base}) => web
    ? '${(base ?? Uri.base).origin}/entrar?token=$token'
    : '${deepLinkNativo}entrar?token=$token';
