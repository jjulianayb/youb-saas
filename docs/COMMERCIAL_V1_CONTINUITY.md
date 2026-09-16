# youB Commercial V1 — estado e continuidade

Atualizado em: 15/09/2026 (UTC)

## Fonte oficial de continuidade

- Repositório: `jjulianayb/youb-saas`
- Branch de trabalho: `design/approved-youb-visual-system-v1`
- Head remoto auditado: `99d469b788457647234bd287a6650caccaf08228`
- Branch `work/finish-commercial-v1`: idêntica ao head acima; não há trabalho extra a integrar.
- Base funcional preservada: `integration/ambient-ux-v1` em `3740a6071b0df149d530f8c068f316dbd77205ff`.
- Não usar nem mesclar `design/commercial-v1-final-ui` ou `design/commercial-v1-ui-polish`: são linhas divergentes do visual rejeitado.

## Entregue na branch aprovada

- Shell horizontal autenticado, sem sidebar dominante.
- Navegação responsiva com navegação inferior no mobile.
- Home de RH/Orquestração.
- Home de Gestor.
- Home de Colaborador pessoal, sem indicadores executivos.
- Home Executiva.
- Demo Commercial V1 com troca de papéis.
- Organização Viva com leitura relacional.
- Bee presente de forma seletiva.
- Sistema visual off-white/lilás/violeta, tipografia editorial e cards compactos.
- Testes de contratos críticos de home e integração.

## Guardrails obrigatórios

- Não alterar `main`, não fazer merge e não publicar/deployar sem autorização explícita da Juliana.
- Não alterar Supabase, Auth, RLS, migrations, secrets ou DNS para concluir o visual.
- Não inventar APIs, permissões ou dados reais.
- As referências visuais aprovadas são especificação, não inspiração.
- Prioridade: V1 comercial vendável; melhorias secundárias ficam para beta.

## Calendário de ação rápido

| Janela | Ação | Critério de saída |
|---|---|---|
| 0–10 min | Confirmar que a branch oficial continua em `99d469b` ou em descendente direto | Nenhuma mudança externa perdida |
| 10–30 min | Abrir preview local e revisar desktop (1440 px) e mobile (390 px) nas quatro homes e na demo | Sem corte, overflow, sobreposição ou sidebar dominante |
| 30–50 min | Corrigir apenas defeitos P0/P1 encontrados na revisão visual | Fluxo comercial apresentável, sem redesign |
| 50–65 min | Executar typecheck, build e testes completos | Todos verdes; warnings de chunk podem permanecer |
| 65–75 min | Comparar branch com `main` e registrar arquivos alterados | Escopo visual confirmado; sem mudanças acidentais |
| 75–85 min | Abrir PR em modo draft, sem merge, se Juliana autorizar | PR pronto para revisão visual |
| Após aprovação | Fazer merge/deploy somente mediante autorização explícita | Preview/produção liberados pelo Product Owner |

## Comandos de validação

```bash
pnpm run typecheck
PORT=4173 BASE_PATH=/ pnpm --filter @workspace/mockup-sandbox run build
VITE_SUPABASE_URL=https://example.supabase.co VITE_SUPABASE_ANON_KEY=test-anon-key pnpm --filter @workspace/scripts run test:bee-runtime
pnpm --filter @workspace/scripts run test:classic-dho-access
```

## Prompt para colar em outra janela

```text
Continue o SaaS youB sem reiniciar a análise. Trabalhe no repositório jjulianayb/youb-saas, exclusivamente na branch design/approved-youb-visual-system-v1. O head remoto auditado em 15/09/2026 era 99d469b788457647234bd287a6650caccaf08228; antes de editar, confirme se o head atual é esse ou um descendente direto. A branch work/finish-commercial-v1 era idêntica e não continha trabalho adicional. Não use nem incorpore design/commercial-v1-final-ui ou design/commercial-v1-ui-polish, pois representam o caminho visual rejeitado.

O visual aprovado é especificação: header horizontal, sem sidebar dominante, hero editorial com ondas/formas orgânicas, cards compactos, fundo off-white com névoa lilás, violeta como cor principal, combinação serif + sans, mobile responsivo, Bee seletiva e Organização Viva relacional. Existem quatro experiências distintas: RH/Orquestração, Gestor, Colaborador (pessoal, nunca executivo) e Executivo.

Prioridade absoluta: terminar a V1 comercial vendável. Faça primeiro QA visual renderizado em 1440 px e 390 px, corrija apenas P0/P1, depois rode typecheck, build e testes. Não invente APIs/dados/permissões. Não altere Supabase, Auth, RLS, migrations, secrets, DNS, main, merge ou deploy sem autorização explícita da Juliana. Preserve alterações locais alheias. Leia docs/COMMERCIAL_V1_CONTINUITY.md para o checklist completo. Informe resultados concretos e links, sem gastar tempo repetindo contexto.
```

## Pendência real

A validação de código foi repetida em 15/09/2026: typecheck passou, build de produção passou e 68/68 testes passaram. Permaneceram somente avisos não bloqueantes de divisão de chunks do Vite. Falta somente QA visual renderizado em browser para declarar fidelidade visual final. Esse gate exige um navegador local disponível ou um preview autorizado; não deve ser substituído por suposição.
