# youB — Delivery Plan

## Papéis

- **Juliana** — Product Owner; prioriza, aprova escopo e decisões de produto.
- **Dodo** — CTO / Arquitetura / PMO / QA; define guardrails, revisa desenho, coordena qualidade e auditoria.
- **Zapia** — implementação; executa mudanças autorizadas, validações e registro de evidências.

## Estados oficiais

`BACKLOG → SPEC READY → BUILDING → AUDIT → FIX → BLOCKED → READY FOR STAGING → READY FOR MERGE → DONE`

## Estado atual e gates

| Entrega | Estado | Responsável | Dependências | Prazo-alvo / gate |
|---|---|---|---|---|
| PR #1 — fundação multiempresa/RLS | READY FOR STAGING | Zapia / Dodo | staging descartável autorizado | condicionado ao staging descartável autorizado |
| PR #2 — Intelligence Core | READY FOR STAGING | Zapia / Dodo | PR #1; staging descartável autorizado | condicionado ao staging descartável autorizado |
| PR #4 — Recommendation & Intervention Model V1 | READY FOR STAGING | Zapia / Dodo | PR #2; auditoria fail-fast concluída | condicionado ao staging descartável autorizado |
| Bee Actions + Impact Foundation V1 | **READY FOR STAGING** | Zapia / Dodo | PR #4; hardening QA/governança concluído | staging descartável autorizado; sem promoção para merge antes dos gates reais |

**Fechamento PR #4:** `READY FOR STAGING`; head congelado em `311c6d3028fc3685c6479810e497db58b2695023`.

**Bee Actions + Impact Foundation V1:** `READY FOR STAGING`; head congelado em `f8670a512b14d55e82bde213bf2e4f6de4c4a96a`. Esta mudança é de governança após o patch final de QA; não altera o escopo funcional. A suíte SQL autenticada continua pendente de execução em staging descartável autorizado. `READY FOR STAGING` não significa `READY FOR MERGE`.

## Caminho após as fundações

As etapas abaixo são planejamento futuro. Não estão implementadas nesta branch e não devem ser interpretadas como entregas concluídas:

| Próxima entrega | Prazo-alvo / gate |
|---|---|
| Organizational Memory + Event Layer V1 | **READY FOR STAGING** | Zapia / Dodo | correção mínima da suíte concluída; contrato PostgreSQL aditivo; PR empilhado sobre Bee Actions + Impact | auditoria técnica fechada; staging autenticado pendente; não é READY FOR MERGE |
| Training Compliance & Development Calendar | Futuro; não implementado |
| Decision Engine + wiring core | 04/09/2026 |
| Organizational Reading Engine V1 | 05/09/2026 |
| Evidence + Recommendation operacional | 06/09/2026 |
| Bee Runtime V1 | 07–08/09/2026 |
| Product Wiring + jornadas por papel + Home de decisões | 09–10/09/2026 |
| Pilot Readiness, regressão, onboarding/importação, white-label básico, auditoria/observabilidade e staging final | a partir de 11/09/2026, condicionado aos gates reais de staging |

## Bloqueios e regras de qualidade

- Execução autenticada em staging descartável ainda pendente; nenhum horário é inventado.
- Nenhuma migration será aplicada em staging ou produção sem autorização explícita.
- Nenhum merge automático e nenhuma alteração em `main`.
- A suíte SQL autenticada de Bee/Impact continua pendente de staging e não é declarada `PASS` sem execução autenticada real.
- `READY FOR STAGING` não autoriza merge; o PR #5 permanece sem merge até os gates de staging e a decisão posterior de governança.
- PR #1, PR #2 e PR #4 aguardam execução autenticada assim que o staging descartável autorizado estiver disponível.
- O PR #4 permanece limitado à fundação estrutural de Recommendation & Intervention V1.


## Organizational Memory + Event Layer V1

A nova branch `feature/organizational-memory-event-layer-v1` parte exatamente do head congelado `f8670a512b14d55e82bde213bf2e4f6de4c4a96a` e implementa somente a camada de memória organizacional temporal e o event layer leve. O estado inicial foi `BUILDING`; código, build/typecheck e correção final da suíte foram concluídos e o estado atual é `READY FOR STAGING`. A execução SQL autenticada em staging continua pendente; `READY FOR STAGING` não é `READY FOR MERGE`. O escopo não usa graph database, não implementa event sourcing completo, replay, Kafka/queue ou automação de triggers; PostgreSQL permanece a base.

## Entrega futura — Training Compliance & Development Calendar

Entrega futura, **NÃO IMPLEMENTADA** e fora do PR #5. Escopo planejado: catálogo de treinamentos obrigatórios e de desenvolvimento; aplicabilidade por cargo, área e unidade; periodicidade e validade; histórico; próxima realização; calendário individual; alertas configuráveis para colaborador, gestor, RH/SSMA e facilitador; convocação; presença/conclusão; certificado; recertificação; status em dia, vencendo, agendamento necessário, vencido ou não aplicável; e integração futura com Bee, Organizational Reading e Impact.

## Decision Engine + Wiring Core V1

A nova branch `feature/decision-engine-v1` parte exatamente do head `023c07d52150955d488ae124fab4a6371b9e3eff` do PR #6, que permanece `READY FOR STAGING`. Esta entrega implementa somente o Decision Engine V1 e o wiring estrutural entre Recommendation, Decision, Approval, Intervention, Action, Outcome, Organizational Memory e Event Layer. O estado inicial foi `BUILDING`; após código, auditoria técnica da suíte e Build/typecheck, o estado atual é `READY FOR STAGING`. Isso não significa `READY FOR MERGE`; a execução SQL autenticada em staging continua pendente.

A separação contratual é obrigatória: Recommendation é proposta; Decision registra escolha humana; Approval é autorização adicional quando exigida; Action é execução; Outcome mede resultado. `decided`/`approved` não significam `executed`.

Ficam fora desta entrega: Organizational Reading Engine, Evidence Engine automático, Bee Runtime, LLM, UI final, scoring, ranking, matching e automações de decisão. A Bee poderá futuramente preparar rascunhos, mas não autoaprovar decisões sensíveis.

### Hardening final — colaboração, revisão e supersession

O Decision Engine V1 passa a tratar Decision como objeto colaborativo e versionável durante `draft` e `pending_review`. `admin_youb`, RH e diretoria usam caminho controlado de revisão; diretoria também pode, em `pending_approval`, aprovar como está, rejeitar, devolver para revisão ou propor alteração substantiva. A revisão substantiva é atômica e grava `intelligence_decision_revisions` append-only com snapshot anterior, snapshot novo, autoria, motivo e número sequencial.

Atualizações diretas autenticadas foram removidas. Após `decided` ou `effective`, o conteúdo corrente e o `evidence_snapshot` não podem ser reescritos silenciosamente. Mudanças posteriores usam uma nova Decision: a sucessora referencia a predecessora em `supersedes_decision_id`, enquanto a predecessora passa a `superseded`; ambas permanecem históricas.

## Organizational Reading Engine V1 — READY FOR STAGING

A nova branch `feature/organizational-reading-engine-v1` parte exatamente do head `7a099b4353eb23109215f6ee7cb8e7a24e38750b` do PR #8, que permanece `READY FOR STAGING`. Esta entrega implementa somente a fundação estrutural e de provenance da **Leitura Organizacional**. O hardening final da suíte e o Build/typecheck foram concluídos e o estado atual é `READY FOR STAGING`. Isso não significa `READY FOR MERGE`; a execução SQL/RLS autenticada em staging continua pendente.

A cadeia epistemológica permanece: DADOS → CONTEXTO → LEITURAS ORGANIZACIONAIS → PADRÕES → HIPÓTESES → EVIDÊNCIAS → RECOMENDAÇÕES → DECISÕES → INTERVENÇÕES → AÇÕES → IMPACTO → MEMÓRIA ORGANIZACIONAL. Uma Leitura descreve uma interpretação estruturada do que a organização apresenta; uma Hipótese é uma explicação possível e não causa confirmada.

A fundação usa taxonomia e lifecycle controlados, janelas de observação, provenance para múltiplas fontes existentes e integração explícita com Memory/Event Layer. Não há geração automática de evidências, scoring, ranking, machine learning, LLM, diagnóstico ou criação automática de Recommendation, Decision, Intervention ou Action.

## Evidence + Recommendation Operational V1 — READY FOR STAGING

A nova branch `feature/evidence-recommendation-operational-v1` parte exatamente do head `9a17bffa1a014ea33697345e54f0b558fc952bca` do PR #9, que permanece `READY FOR STAGING`. Esta entrega implementa somente a fundação operacional e de provenance entre Leitura Organizacional, Hipótese, Evidência, avaliação de suficiência e Recommendation. Os dois hardenings auditados foram concluídos e o Build/typecheck passou; o estado atual é `READY FOR STAGING`. Isso não é `READY FOR MERGE`; a execução SQL/RLS autenticada em staging continua pendente.

A avaliação registra evidências que sustentam e contradizem, unknowns, limitations, resumo e `evidence_state`, sem transformar contagens em verdade ou probabilidade de causa. `insufficient` não pode promover Recommendation para `proposed`/`accepted`; `weak` pode sustentar apenas uma Recommendation cautelosa com limitações explícitas.

Recommendations continuam distintas de Decisions e não criam Decision, Intervention, Action ou Outcome automaticamente. Não há LLM, ML, scoring, ranking, causalidade automática ou diagnóstico.

## Bee Runtime V1 — READY FOR STAGING

A nova branch `feature/bee-runtime-v1` parte exatamente do head `316ee97c15ab96f10d77ea06ae7a9dd51c87094e` do PR #10, que permanece `READY FOR STAGING`. Esta entrega cria somente a camada TypeScript read-only, determinística e tenant-safe para compor e explicar os contratos de inteligência existentes sob a autorização já aplicada pelo RLS. Código, testes verificáveis e Build/typecheck foram concluídos; o estado atual é `READY FOR STAGING`. Isso não é `READY FOR MERGE`; SQL/RLS runtime autenticado das fundações continua pendente.

O Runtime não cria, altera ou executa qualquer entidade. Não usa LLM, ML, scoring opaco, NLP complexo, chat persistente, raw prompt, conversa bruta ou chain-of-thought. A Bee pode entender e explicar; não pode conceder permissão a si mesma, apresentar hipótese como fato ou Recommendation como Decision.

## Product Wiring + Executive Home V1 — AUDIT

A nova branch `feature/product-wiring-executive-home-v1` parte exatamente do head `25e5fff0540ab460ce16fededbc47b2e1e71e91f` do PR #11, que permanece `READY FOR STAGING`. Esta entrega conecta o Bee Runtime à experiência visível da plataforma em uma Home executiva orientada a exceções, sem duplicar entidades ou reconstruir módulos antigos. Código, Build e testes foram concluídos; o estado atual é `AUDIT`. Não promover automaticamente para `READY FOR STAGING` antes da auditoria.

A Home utiliza `attentionToday`, o read model e os handlers determinísticos do Bee Runtime. A experiência preserva Reading, Hypothesis, Evidence, Assessment, Recommendation, Decision, Intervention, Action e Outcome. Não há score, KPI inventado, write, LLM, chat persistente, áudio ou execução automática.

### Product Wiring + Executive Home V1 — hardening AUDIT → FIX

Após a auditoria, o PR #12 permanece em `AUDIT → FIX`. O hardening filtra a seção de Leituras Organizacionais pela coleção explícita de status `open`/`under_investigation` e alinha Actions próximas à janela do Bee Runtime: `dueAt` existente, sem `completedAt` e `dueAt <= now + 24h`. O detalhe agora reconstrói a linha Reading → Outcome somente por relações presentes no `BeeRuntimeReadModel`, exibindo ausência quando um elo não existe.

Os atalhos de módulos sem rota real foram omitidos, sem criar rotas fake. O wiring de população autorizada de equipe do gestor continua pendente: **Manager/team authorized population wiring pending**. Esse gap será tratado com a conexão da estrutura de pessoas, equipes e módulos clássicos de DHO.

### Final chain hardening — Decision → Intervention

Após a auditoria do head `2c9a99f9662b89d36662bb919e697dede5a36a2a`, o detail chain foi corrigido para resolver Decision → Intervention pela relação oficial `BeeDecisionNode.interventionIds`. A implementação não usa `BeeInterventionNode.decisionId` como fonte principal, pois o contrato real do Runtime mantém esse campo nulo. A fixture agora reproduz o contrato real e o PR permanece em `AUDIT → FIX`.

### Downstream chain hardening — Intervention → Action → Outcome

Após a auditoria do head `9fd0e4ffb64c008c62d22c8f3c2f1e5ff49864e2`, o detail chain passou a resolver Action explicitamente ligada à Intervention por `action.interventionId`, depois Outcome por `outcome.actionId` e, como fallback explícito, `outcome.interventionId`. A ordem mantém a seleção atual quando aplicável e não infere elos por título, escopo, datas ou proximidade. O estado permanece `AUDIT → FIX`.

### Full selectable-finding chain hardening — AUDIT → FIX

Após a auditoria do head `be0f25ce1b36f41ee8d4ad211a2717d0feff72b2`, o `buildDetailChain` passou a resolver Recommendation por Reading e Assessment quando os links explícitos existirem, e Decision por Intervention em aberturas de Action/Outcome mesmo sem Recommendation. O downstream continua usando somente `interventionId`, `actionId` e `interventionId` de Outcome. O PR permanece `AUDIT → FIX`.

## Product Wiring + Executive Home V1 — IMPLEMENTADO + AUDITADO → READY FOR STAGING

### Fechamento de governança

A auditoria técnica final do Dodo foi concluída com sucesso no head `8bf3f2d9b2f93b256a21e5223a47186418ab7b1a`. O PR #12 está tecnicamente aprovado e classificado como **IMPLEMENTADO + AUDITADO → READY FOR STAGING**.

- Build #239 (`pull_request`): PASS.
- Testes Bee Runtime + Executive Home/Product Wiring: PASS.
- Não há bug conhecido bloqueante no escopo do PR #12.
- `bee-runtime.ts` permaneceu congelado; não houve mudança nas sete suítes SQL nem migrations.
- PR #11 continua congelado em `25e5fff0540ab460ce16fededbc47b2e1e71e91f`.
- `Manager/team authorized population wiring pending` continua gap conhecido, não bloqueante para o PR #12.
- SQL/RLS autenticado de staging das fundações continua pendente antes de `READY FOR MERGE`.
- `READY FOR STAGING` não significa `READY FOR MERGE`.

Este é o fechamento documental do PR #12. Não houve merge, deploy, alteração de main, staging ou produção.
