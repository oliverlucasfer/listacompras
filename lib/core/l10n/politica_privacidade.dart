/// Política de Privacidade do app (doc 06 §3.3): texto único e simples,
/// exibido in-app (cadastro e Configurações). A versão online pública é
/// publicada na F5-T06 — mesma fonte, uma página.
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
Seus dados ficam hospedados no Supabase (infraestrutura AWS). Para a função de importação por texto, o trecho que você colar é enviado ao Google Gemini para extração dos itens, sem identificadores pessoais. Registros de erro podem ser processados pelo Sentry, sem conteúdo das suas listas. Não vendemos nem compartilhamos seus dados com mais ninguém.

4. Por quanto tempo guardamos
Até você excluir sua conta. Ao excluir a conta, todas as suas listas e itens são apagados permanentemente (exclusão física). Registros técnicos de erros podem permanecer pelo período de retenção do serviço de monitoramento.

5. Seus direitos
Você pode acessar e corrigir seus dados diretamente no aplicativo (ele é a visão dos seus dados) e excluir tudo pela opção "Excluir minha conta" nas Configurações. O app não é direcionado a menores de 16 anos.

6. Contato
Dúvidas sobre privacidade ou exercício de direitos: utilize o canal de contato informado na página do aplicativo.
''';
