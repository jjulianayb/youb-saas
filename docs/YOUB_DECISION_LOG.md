# youB — Decision Log

## Decisões arquiteturais aprovadas

| Data | Decisão | Motivo | Impacto |
|---|---|---|---|
| 2026-08-26 | O produto deve ser multiempresa com isolamento por tenant. | Evitar vazamento entre organizações desde a fundação. | `organization_id`, FKs tenant-safe e RLS tornam o tenant parte do contrato estrutural. |
| 2026-08-27 | RLS é a autoridade de autorização; frontend não é mecanismo de segurança. | Impedir que escopo visual ou payload determine acesso. | Toda leitura e escrita sensível depende de políticas e funções SQL autorizadas. |
| 2026-08-30 | A escrita direta de sinais fica restrita a `admin_youb` e `rh` no próprio tenant. | Separar leitura de inteligência de ingestão privilegiada. | Colaborador, gestor e diretoria não recebem CRUD genérico de sinais. |
| 2026-08-31 | Recommendation & Intervention V1 é fundação estrutural, sem IA ou automação. | Evoluir incrementalmente sem acoplar produto a algoritmo prematuro. | Contratos são explícitos, explicáveis e rastreáveis; geração e execução ficam para fases futuras. |
| 2026-08-31 | A junction Recommendation–Evidence é a relação oficial. | Preservar múltiplas evidências, inclusive contraditórias. | `source_evidence_ids` permanece apenas como compatibilidade/denormalização. |
| 2026-08-31 | `insufficient` não pode aceitar `intervene`. | Evitar intervenção sem base mínima de evidência. | Constraint estrutural rejeita a combinação inválida. |
| 2026-08-31 | Escopo descritivo nunca autoriza acesso. | Evitar confundir alvo de negócio com autorização. | `scope_ref` e `target_scope_ref` são referências, não controles de segurança. |
| 2026-09-01 | Aprovação humana não cria nem executa Intervention automaticamente. | Evitar decisões organizacionais irreversíveis sem revisão. | O contrato registra aprovação, mas não há trigger, workflow ou action automática. |
| 2026-09-01 | Bee será role-aware e conversas privadas não serão expostas individualmente a gestores. | Proteger privacidade e manter utilidade contextual. | Compartilhamento depende de autorização, agregação ou consentimento explícito. |
| 2026-09-01 | Nenhuma decisão sensível será autônoma. | Risco humano, jurídico e ético. | Demissões, promoções, remuneração, disciplina e diagnósticos permanecem decisões humanas. |
| 2026-09-01 | PR #4 está `READY FOR STAGING` após o fechamento final de QA/governança. | Os testes cross-tenant passaram a usar payloads válidos no tenant B e as assertions fail-fast foram revisadas. | A implementação continua sem merge e sem produção; o próximo gate é staging descartável autorizado. |
| 2026-09-01 | Bee Action Request é uma camada distinta de `intelligence_actions`. | Separar capacidade, solicitação, autorização e execução concreta sem duplicar a ação organizacional. | `bee_action_requests` registra metadados mínimos, referências tenant-safe e estados; não executa ações. |
| 2026-09-01 | Acesso ao dado não equivale a permissão para agir. | Leitura contextual e ação mediada têm riscos diferentes. | RLS e constraints conservadoras separam leitura, confirmação, aprovação e execução. |
| 2026-09-01 | Aprovação humana não é execução. | Evitar automação de decisões e efeitos irreversíveis. | Aprovação apenas habilita o contrato estrutural; não há trigger, RPC, webhook ou executor. |
| 2026-09-01 | `OUTPUT`, `OUTCOME` e `IMPACT` são conceitos distintos. | Evitar atribuir impacto a uma saída ou a uma associação. | Outcomes recebem níveis e força de afirmação explícitos, sem causalidade ou ROI automático. |
| 2026-09-01 | Associação não é causalidade; ROI nunca é presumido. | Guardar incerteza e evitar claims financeiros indevidos. | `causal_validated` exige validação e metodologia; `financial_value` exige valor não negativo, moeda e metodologia. |
| 2026-09-01 | Conversa privada da Bee não vira relatório escondido. | Preservar privacidade e limitar o registro ao necessário. | A tabela de requests armazena metadados e payload mínimo, sem conversa bruta ou prompt completo. |
| 2026-09-01 | A máquina de estados de autorização deve ser coerente e conservadora. | Impedir execução ativa sem autorização correspondente e impedir estados impossíveis. | `none` só aceita `not_required`; confirmation/approval têm estados próprios; aprovação exige provenance; rejected/expired não executam; sensitive + execute exige approval; completed exige `executed_at`. |
| 2026-09-01 | Todo Outcome `validated` exige provenance de validação; valor financeiro exige metodologia. | Evitar validações sem responsável/data e valores financeiros sem base metodológica. | `validated_by`/`validated_at` são obrigatórios; `financial_value` exige valor não negativo, `currency` e `measurement_methodology`, sem cálculo de ROI. |
| 2026-09-01 | Provenance de requester/confirmed_by/approved_by/validated_by será validada na fronteira server-side em etapa futura. | Validar tenant e autoridade sem destruir histórico nem bloquear offboarding. | Não criar agora FK de membership; a fronteira server-side fica fora deste PR. |
| 2026-09-01 | PR #5 foi congelado no head `f8670a512b14d55e82bde213bf2e4f6de4c4a96a` e promovido documentalmente a `READY FOR STAGING`. | Encerrar o patch de QA sem alterar escopo funcional. | A suíte SQL autenticada continua pendente de staging; `READY FOR STAGING` não é `READY FOR MERGE`. |

## Estado de governança

- PR #1: `READY FOR STAGING`.
- PR #2: `READY FOR STAGING`.
- PR #4: `READY FOR STAGING`.
- Bee Actions + Impact Foundation V1: `READY FOR STAGING`; head congelado em `f8670a512b14d55e82bde213bf2e4f6de4c4a96a`.
- Bloqueio comum: execução autenticada em staging descartável ainda pendente.

A implementação continua sem merge e sem aplicação em produção. Nenhuma decisão deste log autoriza migration, staging ou merge.

## Estado da nova entrega

- Bee Actions + Impact Foundation V1: `READY FOR STAGING`, congelado no head `f8670a512b14d55e82bde213bf2e4f6de4c4a96a`; a suíte SQL autenticada continua pendente e isso não é `READY FOR MERGE`.
- Organizational Memory + Event Layer V1: `READY FOR STAGING` na branch `feature/organizational-memory-event-layer-v1`, baseada exatamente em `f8670a512b14d55e82bde213bf2e4f6de4c4a96a`; correção mínima da suíte, build/typecheck e fechamento técnico concluídos. A execução SQL autenticada em staging continua pendente e `READY FOR STAGING` não é `READY FOR MERGE`.

Bee Actions + Impact Foundation V1: `READY FOR STAGING`, congelado no head `f8670a512b14d55e82bde213bf2e4f6de4c4a96a`. A suíte SQL autenticada ainda depende de staging descartável autorizado. Este estado não autoriza merge nem aplicação em produção.


| 2026-09-01 | Organizational Memory + Event Layer V1 usa PostgreSQL com relações temporais e eventos leves append-oriented. | Manter a base operacional existente e criar memória estruturada sem graph database ou event sourcing completo. | Não há replay, Kafka/queue, trigger global ou substituição das tabelas operacionais. |
| 2026-09-01 | Memória distingue explicitamente `fact`, `declaration`, `reading`, `hypothesis`, `decision`, `intervention` e `outcome`; hipótese nunca é fato. | Preservar o tipo epistemológico e evitar promoção silenciosa de incerteza. | `knowledge_kind` é controlado; `hypothesis` permanece identificada como hipótese. |
| 2026-09-01 | Relações históricas são preservadas por encerramento temporal e nova inserção, sem sobrescrever a história. | Permitir mudanças de gestor/cargo/área/unidade com rastreabilidade. | `valid_until` não pode anteceder `valid_from`; IDs polimórficos são descritivos e não autorizam acesso. |
| 2026-09-01 | Vocabulários de entidades, relações e eventos são catálogos controlados e extensíveis por mudança explícita. | Impedir texto arbitrário silencioso e manter contrato evolutivo. | Eventos de compliance de treinamento entram apenas como contrato futuro, com `implemented=false`; a funcionalidade não está neste PR. |
| 2026-09-01 | O event layer registra ocorrências, não estado atual. | Separar fatos ocorridos das tabelas operacionais e evitar event sourcing implícito. | Eventos são append-oriented; V1 não implementa replay nem captura automática por triggers. |
| 2026-09-01 | RLS de memória/eventos é tenant-safe e conservador. | Evitar leitura genérica por gestor/colaborador e vazamento entre organizações. | Admin/RH gerem no próprio tenant; diretoria lê somente sensibilidades permitidas; IDs polimórficos não substituem autorização. |
| 2026-09-01 | Contexto e payload são JSONB objeto; conversa bruta da Bee não é armazenada. | Preservar estrutura mínima e privacidade. | Serviços expõem leitura tipada; não há prompt completo, conversa ou mensagem bruta. |

| 2026-09-01 | Organizational Memory + Event Layer V1 concluiu a correção mínima da suíte e o Build/typecheck e entrou em `READY FOR STAGING`. | Separar fechamento técnico da execução SQL autenticada em staging e do merge. | `READY FOR STAGING` não é `READY FOR MERGE`; staging autenticado e decisão posterior continuam obrigatórios. |

## Entrega futura registrada

**Training Compliance & Development Calendar** permanece futura e **NÃO IMPLEMENTADA**. O escopo planejado inclui catálogo obrigatório e de desenvolvimento, aplicabilidade por cargo/área/unidade, periodicidade/validade, histórico, próxima realização, calendário individual, alertas configuráveis para colaborador, gestor, RH/SSMA e facilitador, convocação, presença/conclusão, certificado, recertificação, status em dia/vencendo/agendamento necessário/vencido/não aplicável e integração futura com Bee, Organizational Reading e Impact.

## Decision Engine + Wiring Core V1

- PR #6 permanece `READY FOR STAGING`, congelado no head `023c07d52150955d488ae124fab4a6371b9e3eff`; não será alterado salvo bug real posterior.
- Decision Engine + Wiring Core V1 está em `READY FOR STAGING` na branch `feature/decision-engine-v1`, após a correção mínima da assertion JSON e novo Build/typecheck. `READY FOR STAGING` não é `READY FOR MERGE`; a execução SQL autenticada em staging continua pendente.
- Recommendation, Decision, Approval, Intervention, Action e Outcome são contratos distintos. Decidir ou aprovar não executa ação e não cria intervenção automaticamente.
- O Decision Engine usa a escala de risco Bee Action existente, mantém snapshots de evidência e registra decisões superseded sem apagar o histórico. `scope_ref` é descritivo e nunca autoriza acesso.
- A Bee poderá preparar/draftar decisões no futuro, mas nunca autoaprovar decisão sensível; não há LLM, scoring, UI final, Evidence Engine automático, Organizational Reading Engine ou Bee Runtime nesta entrega.

### Hardening final do Decision Engine V1

- Diretoria pode decidir, revisar decisões em `draft`/`pending_review` e aprovar somente quando for o approver requerido (`approval_required=true`, `required_approver_role='diretoria'`).
- Revisões são append-only em `intelligence_decision_revisions`; snapshots anterior/novo, autoria, motivo e número da revisão são preservados.
- Alteração substantiva durante `pending_approval` devolve a decisão para `pending_review` e precisa ser revisada antes da aprovação final.
- Aprovação, rejeição e retorno para revisão usam funções controladas e provenance clara; a Bee não pode autoaprovar decisões sensíveis.
- Atualização autenticada direta foi revogada. Depois de `decided`/`effective`, uma mudança exige nova Decision via supersession controlada.
- Semântica corrigida: a nova Decision aponta para a predecessora; a predecessora recebe `superseded`; sucessora e predecessora permanecem disponíveis.

## Organizational Reading Engine V1

- PR #8 permanece `READY FOR STAGING`, congelado no head `7a099b4353eb23109215f6ee7cb8e7a24e38750b`; não deve ser alterado salvo bug real comprovado.
- Organizational Reading Engine V1 está em `READY FOR STAGING` na branch `feature/organizational-reading-engine-v1`, após o hardening final da suíte e novo Build/typecheck. `READY FOR STAGING` não é `READY FOR MERGE`; a execução SQL/RLS autenticada em staging continua pendente.
- O conceito exposto é **Leitura Organizacional**. `intelligence_signals` continua somente como nome técnico legado quando necessário; `signal/sinal` não é o conceito de produto.
- Reading e Hypothesis são entidades epistemicamente distintas: Reading = interpretação estruturada; Hypothesis = explicação possível, sem confirmação causal automática.
- O engine não gera Evidence, Recommendation, Decision, Intervention ou Action automaticamente e não implementa scoring, LLM, ML, diagnóstico ou UI final.

## Evidence + Recommendation Operational V1

- PR #9 permanece `READY FOR STAGING`, congelado no head `9a17bffa1a014ea33697345e54f0b558fc952bca`; não deve ser alterado salvo bug real comprovado.
- Evidence + Recommendation Operational V1 está em `READY FOR STAGING` na branch `feature/evidence-recommendation-operational-v1`, após o hardening de compatibilidade do schema legado e das funções PL/pgSQL, com Build/typecheck aprovado. Isso não é `READY FOR MERGE`; SQL/RLS runtime autenticado continua pendente.
- O contrato conecta Leitura Organizacional → Hipótese → Evidência → avaliação de suficiência → Recommendation por FKs/junctions tenant-safe e provenance explícita.
- `insufficient`, `weak`, `moderate`, `strong` e `conflicting` não são probabilidades de causa. A ausência de evidência não é evidência negativa.
- Recommendation é proposta e permanece distinta de Decision, Approval, Intervention, Action e Outcome. A Bee poderá explicar a cadeia futuramente, mas não deverá apresentar hipótese como fato nem Recommendation como decisão.

## Bee Runtime V1

- PR #10 permanece `READY FOR STAGING`, congelado no head `316ee97c15ab96f10d77ea06ae7a9dd51c87094e`; não deve ser alterado salvo bug real comprovado.
- Bee Runtime V1 está em `READY FOR STAGING` na branch `feature/bee-runtime-v1`, criada exatamente do head do PR #10. Código, testes verificáveis e Build/typecheck foram concluídos. Isso não é `READY FOR MERGE`; SQL/RLS runtime autenticado continua pendente.
- O Runtime é um compositor read-only que depende do RLS e dos helpers existentes como primeira barreira. Contexto, escopos, papel, população, sensitivity e purpose são explícitos; a camada TypeScript pode restringir, mas nunca ampliar, a autorização.
- `attention_today` usa regras determinísticas e transparentes, sem score opaco. Explicações preservam provenance, unknowns e limitations e diferenciam FACT, READING, HYPOTHESIS, EVIDENCE, RECOMMENDATION, DECISION, INTERVENTION, ACTION e OUTCOME.
- Nenhum prompt bruto, conversa, chain-of-thought, write, trigger, execução ou evento de consulta é criado nesta entrega.

## Product Wiring + Executive Home V1

- PR #11 permanece `READY FOR STAGING`, congelado no head `25e5fff0540ab460ce16fededbc47b2e1e71e91f`; não alterar salvo bug real comprovado.
- Product Wiring + Executive Home V1 está em `AUDIT` na branch `feature/product-wiring-executive-home-v1`, criada exatamente do head do PR #11. Código + Build + testes foram concluídos; não promover automaticamente para `READY FOR STAGING`.
- A Home executiva usa o Bee Runtime como fonte estruturada para `attentionToday`, Readings, Recommendations, Decisions, Actions e Outcomes. O detalhe usa os contratos de explainability existentes.
- A UI não cria autorização paralela: o runtime continua primeira fonte autorizada via RLS, e a camada visual só reduz conteúdo. Colaborador permanece na experiência pessoal existente.
- Não há novos contratos SQL, migrations, writes, LLM, chat persistente, áudio, score ou redesign completo.

## Product Wiring + Executive Home V1 — hardening após auditoria

- PR #12 permanece `AUDIT → FIX`; não promover automaticamente para `READY FOR STAGING`.
- `openReadings` usa a coleção autorizada de `listOpenReadings`, com status somente `open` ou `under_investigation`; count, lista e empty state usam a mesma coleção.
- Actions próximas usam a mesma semântica do Bee Runtime V1: `dueAt` existente, sem `completedAt` e janela inclusiva de até 24 horas a partir de `now` explícito.
- A linha da decisão e execução do detail percorre somente links explícitos existentes no read model. Elo ausente é exibido como ausência; não há relação inferida.
- Atalhos sem rotas reais foram omitidos. Nenhuma rota de módulo foi inventada.
- Gap conhecido: **Manager/team authorized population wiring pending**. Não criar scope de equipe artificial neste PR.
- `bee-runtime.ts`, as sete suítes SQL, migrations, `main` e PR #11 permanecem inalterados.

## Último fix auditado — Decision → Intervention

- `buildDetailChain` passa a localizar Intervention por `decision.interventionIds`, conforme o contrato real do Bee Runtime V1.
- `BeeInterventionNode.decisionId` permanece nulo na fixture e não é usado como fonte principal.
- Foi adicionado teste específico para Decision com `interventionIds = ["int-a"]` encontrar a Intervention correspondente.
- PR #12 continua `AUDIT → FIX`; não promover automaticamente para `READY FOR STAGING`.

## Último fix auditado — continuação downstream

- Após resolver `resolvedIntervention`, `buildDetailChain` deriva `resolvedAction` nesta ordem: Action selecionada; Action apontada por `selectedOutcome.actionId`; Action com `interventionId` igual à Intervention resolvida.
- `resolvedOutcome` usa nesta ordem: Outcome selecionado; Outcome com `actionId` igual à Action resolvida; Outcome com `interventionId` igual à Intervention resolvida.
- Teste reproduz Decision → Intervention → Action → Outcome e confirma que Intervention sem Action relacionada não cria Action nem Outcome.
- PR #12 permanece `AUDIT → FIX`; não promover automaticamente para `READY FOR STAGING`.

## Último fix auditado — cadeia para todos os findings selecionáveis

- Reading selecionada busca Recommendation por `reading.recommendations` ou `recommendation.linkedReadingIds`.
- Assessment selecionado busca Recommendation por `recommendation.linkedAssessmentIds`.
- Action/Outcome selecionados podem subir até Decision por `decision.interventionIds`, mesmo quando Intervention não possui Recommendation nem Decision reversa.
- Action e Outcome continuam sendo derivados apenas por IDs explícitos.
- Testes cobrem Reading, Assessment, Action e Outcome selecionados, além de ausência sem inferência.
- PR #12 permanece `AUDIT → FIX`; não promover automaticamente para `READY FOR STAGING`.

## Product Wiring + Executive Home V1 — fechamento de governança

- Auditoria técnica final concluída com sucesso no head `8bf3f2d9b2f93b256a21e5223a47186418ab7b1a`.
- PR #12 tecnicamente aprovado: **IMPLEMENTADO + AUDITADO → READY FOR STAGING**.
- Build #239 (`pull_request`) passou; testes Bee Runtime + Executive Home/Product Wiring passaram.
- Não há bug conhecido bloqueante no escopo do PR #12.
- `bee-runtime.ts` permaneceu congelado; SQL e migrations permaneceram inalterados.
- PR #11 permanece congelado em `25e5fff0540ab460ce16fededbc47b2e1e71e91f`.
- `Manager/team authorized population wiring pending` permanece gap conhecido e não bloqueante do PR #12.
- A execução autenticada de SQL/RLS das fundações em staging continua pendente antes de `READY FOR MERGE`.
- `READY FOR STAGING` não significa `READY FOR MERGE`; não houve merge nem publicação.
- Este commit sincroniza somente a documentação oficial do estado final.
