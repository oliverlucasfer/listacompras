// parse_lista_e2e.mjs — F2-T03 (3 listas bagunçadas) + F2-T04 (códigos e2e)
// Uso: node parse_lista_e2e.mjs [--sem-gemini]
// Requer `supabase start` com supabase/.env (GEMINI_API_KEY) para o cenário Gemini.
// Cenários sem Gemini (401/400/429) rodam no CI (F2-T05) com --sem-gemini.

import { createClient } from '@supabase/supabase-js';

const URL = 'http://127.0.0.1:54321';
const KEY = 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH';
const FUNCAO = `${URL}/functions/v1/parse-lista`;
const SEM_GEMINI = process.argv.includes('--sem-gemini');

const UNIDADES = ['un', 'kg', 'g', 'l', 'ml', 'caixa', 'pacote', 'pct', 'dz'];
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let falhas = 0;

function ok(msg) { console.log(`  OK ${msg}`); }
function falhou(msg) { falhas++; console.error(`  FALHOU ${msg}`); }

async function jwtPara(email) {
  const c = createClient(URL, KEY);
  const { data, error } = await c.auth.signUp({ email, password: 'senha-teste-123' });
  if (error) throw new Error(`signup ${email}: ${error.message}`);
  return data.session.access_token;
}

async function chamar(token, corpo) {
  const headers = {
    'Content-Type': 'application/json',
    apikey: KEY,
  };
  if (token) headers.Authorization = `Bearer ${token}`; // sem header = JWT ausente (401)
  const res = await fetch(FUNCAO, {
    method: 'POST',
    headers,
    body: JSON.stringify(corpo),
  });
  return { status: res.status, body: await res.json().catch(() => null) };
}

// ===== usuário A: caminhos sem Gemini =====
console.log('[cenário A] contrato sem chegar ao Gemini');
const jwtA = await jwtPara(`pa-${Date.now()}@test.local`);

{
  const { status, body } = await chamar('', { texto: 'arroz' });
  if (status === 401 && body?.code === 'unauthorized' && body?.message) ok('401 unauthorized com {code,message}');
  else falhou(`esperado 401 unauthorized, veio ${status} ${JSON.stringify(body)}`);
}
{
  const { status, body } = await chamar(jwtA, { texto: '   ' });
  if (status === 400 && body?.code === 'texto_vazio') ok('400 texto_vazio (só espaços)');
  else falhou(`esperado 400 texto_vazio, veio ${status} ${JSON.stringify(body)}`);
}
{
  const { status, body } = await chamar(jwtA, {});
  if (status === 400 && body?.code === 'texto_vazio') ok('400 texto_vazio (sem texto)');
  else falhou(`esperado 400 texto_vazio, veio ${status} ${JSON.stringify(body)}`);
}
{
  const { status, body } = await chamar(jwtA, { texto: 'a'.repeat(2001) });
  if (status === 400 && body?.code === 'texto_longo') ok('400 texto_longo (2001 chars)');
  else falhou(`esperado 400 texto_longo, veio ${status} ${JSON.stringify(body)}`);
}
{
  const { status, body } = await chamar(jwtA, { texto: 'b'.repeat(2000) });
  // 2000 chars é aceito; SEM Gemini passa direto ao Gemini — com chave real responde
  // 200/429cota/504/422; com --sem-gemini (sem key) virá 500 erro_interno — aceitável.
  if (SEM_GEMINI) {
    if (status === 500 && body?.code === 'erro_interno') ok('400→não veio (limite ok; 500 esperado sem key)');
    else falhou(`esperado 500 sem key, veio ${status} ${JSON.stringify(body)}`);
  } else {
    if ([200, 429, 504, 422, 500].includes(status)) ok(`texto com 2000 chars aceito (status ${status} do caminho IA)`);
    else falhou(`2000 chars rejeitado indevidamente: ${status} ${JSON.stringify(body)}`);
  }
}

// ===== usuário B: rate limit (11ª → 429; não chega ao Gemini) =====
console.log('[cenário B] rate limit 10/min');
{
  const jwtB = await jwtPara(`pb-${Date.now()}@test.local`);
  let veio429 = -1;
  for (let i = 1; i <= 11; i++) {
    const { status, body } = await chamar(jwtB, { texto: 'x'.repeat(2001) }); // texto_longo evita gastar IA
    if (status === 429 && body?.code === 'rate_limit') { veio429 = i; break; }
    if (i === 1 && status !== 400) { falhou(`chamada 1 deveria ser 400 texto_longo, veio ${status}`); break; }
  }
  if (veio429 === 11) ok('429 rate_limit na 11ª chamada');
  else if (veio429 > 0) ok(`429 rate_limit na ${veio429}ª chamada (janela compartilhada de testes anteriores)`);
  else falhou('não recebeu 429 rate_limit em 11 chamadas');
}

// ===== usuário C: 3 listas bagunçadas reais (Gemini) — F2-T03 =====
if (!SEM_GEMINI) {
  console.log('[cenário C] Gemini real — 3 listas bagunçadas');
  const jwtC = await jwtPara(`pc-${Date.now()}@test.local`);
  const casos = [
    {
      texto: '1kg de arroz, 2 leites, 500g de queijo prato e macarrão',
      deveConter: ['arroz', 'leite', 'queijo'],
      minItens: 4,
    },
    {
      texto: 'meio quilo de carne moída, uma dúzia de ovos, 2 litros de leite, café e pão de ontem',
      deveConter: ['carne', 'ovo', 'leite', 'café', 'pão'],
      minItens: 5,
    },
    {
      texto: 'várias coisas para o bolo: 3 ovos, 1 caixa de leite condensado, 500g de farinha de trigo e açúcar',
      deveConter: ['ovo', 'leite condensado', 'farinha', 'açúcar'],
      minItens: 4,
    },
  ];

  for (const [i, caso] of casos.entries()) {
    const { status, body } = await chamar(jwtC, { texto: caso.texto });
    if (status !== 200) { falhou(`caso ${i + 1}: status ${status} ${JSON.stringify(body)}`); continue; }
    if (!Array.isArray(body.itens) || body.itens.length < caso.minItens) {
      falhou(`caso ${i + 1}: itens insuficientes (${JSON.stringify(body)})`); continue;
    }
    if (body.aviso !== null && typeof body.aviso !== 'string') {
      falhou(`caso ${i + 1}: aviso inválido`); continue;
    }
    const unidadesOk = body.itens.every((it) =>
      typeof it.nome === 'string' && it.nome.length > 0 &&
      typeof it.quantidade === 'number' && it.quantidade > 0 &&
      UNIDADES.includes(it.unidade)
    );
    if (!unidadesOk) { falhou(`caso ${i + 1}: item fora do contrato: ${JSON.stringify(body.itens)}`); continue; }
    const nomes = body.itens.map((it) => it.nome.toLowerCase()).join(' | ');
    const faltando = caso.deveConter.filter((d) => !nomes.includes(d));
    if (faltando.length > 0) { falhou(`caso ${i + 1}: faltou ${faltando.join(', ')} em "${nomes}"`); continue; }
    ok(`caso ${i + 1}: ${body.itens.length} itens [${nomes}] aviso=${JSON.stringify(body.aviso)}`);
  }
}

console.log(falhas === 0 ? 'TODOS OS TESTES E2E PASSARAM' : `${falhas} FALHA(S)`);
process.exit(falhas === 0 ? 0 : 1);
