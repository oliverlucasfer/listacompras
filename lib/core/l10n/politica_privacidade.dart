/// Política de Privacidade do app (doc 06 §3.3): texto único e simples,
/// exibido in-app no cadastro ("Ver política") e em Configurações (F21-T04).
/// Sem versão online desde 18/09/2026 (ADR-013 — a página estática do Hosting
/// foi removida junto com os artefatos de publicação).
const politicaPrivacidadeTexto = '''
Política de Privacidade

1. Dados que coletamos
• E-mail e uma senha (armazenada apenas como hash) para autenticação.
• O conteúdo das listas de compras que você cria (títulos e itens).
• Marcadores técnicos de data/hora das alterações, usados pela sincronização.

2. Para que usamos
• Permitir que você crie, use e sincronize suas listas de compras entre seus dispositivos.
• Detectar e corrigir erros do aplicativo (registros técnicos de falhas, sem o conteúdo das suas listas).

Não coletamos dados pessoais sensíveis. Não usamos seus dados para publicidade e não há rastreamento publicitário.

3. Com quem compartilhamos
Seus dados ficam hospedados no Supabase (infraestrutura AWS). A importação por texto acontece inteiramente no seu dispositivo (parser local, offline) — nenhum trecho colado é enviado a terceiros. Registros de erro podem ser processados pelo Sentry, sem conteúdo das suas listas. Não vendemos nem compartilhamos seus dados com mais ninguém.

4. Por quanto tempo guardamos
Até você excluir sua conta. Ao excluir a conta, todas as suas listas e itens são apagados permanentemente (exclusão física). Registros técnicos de erros podem permanecer pelo período de retenção do serviço de monitoramento.

5. Seus direitos
Você pode acessar e corrigir seus dados diretamente no aplicativo (ele é a visão dos seus dados) e excluir tudo pela opção "Excluir minha conta" nas Configurações. O app não é direcionado a menores de 16 anos.

6. Contato
Dúvidas sobre privacidade ou exercício de direitos: utilize o canal de contato informado na página do aplicativo.
''';
