# youB — Intelligence Architecture

## Cadeia oficial

`DADOS → CONTEXTO → LEITURAS ORGANIZACIONAIS → PADRÕES → HIPÓTESES → EVIDÊNCIAS → RECOMENDAÇÕES → DECISÕES → INTERVENÇÕES → AÇÕES → IMPACTO → MEMÓRIA ORGANIZACIONAL`

A cadeia separa observação, interpretação, hipótese, evidência, recomendação, decisão e execução. Uma hipótese não é fato; deve permanecer identificada como hipótese até receber evidência suficiente.

## Princípios

- **Bee** é a interface inteligente role-aware: adapta linguagem e escopo ao papel e ao contexto autorizado.
- **RLS** é a autoridade de acesso. Frontend, `scope_ref` e filtros de interface nunca substituem RLS.
- **Leitura Organizacional** é a linguagem do produto para transformar dados contextualizados em leituras explicáveis e acionáveis.
- Recomendações são contratos estruturados, rastreáveis e explicáveis; não são texto livre autônomo.
- Evidências de apoio, contradição e neutralidade devem ser preservadas.
- Conversas privadas da Bee não são expostas individualmente a gestores. Só informações autorizadas, agregadas ou explicitamente compartilháveis podem atravessar esse limite.
- Aprovação humana é obrigatória quando o contrato exigir; aprovação não significa execução automática.
- Nenhuma decisão sensível pode ser autônoma: demissão, promoção, remuneração, disciplina, diagnóstico de saúde/saúde mental ou equivalente exigem decisão humana e controles próprios.

## Escopo do PR #4

O PR #4 cria somente a fundação estrutural de Recommendation & Intervention V1: campos, constraints, relações, políticas conservadoras, contratos de leitura e testes. Não implementa LLM, scoring, ranking, matching, Decision Engine, Bee Actions, Impact, Memory ou Event Layer.


## Bee Action Authorization + Impact Model V1

- A capacidade da Bee (`observe`, `explain`, `ask`, `recommend`, `prepare`, `execute`) é diferente da autorização para agir.
- Acesso ao dado é diferente de permissão para agir; RLS continua sendo a autoridade.
- Aprovação humana é um registro de autorização, não execução. A camada não dispara executor, trigger, RPC ou webhook.
- Conversa privada não vira relatório escondido: `bee_action_requests` armazena metadados e payload mínimo, nunca conversa bruta, prompt completo ou mensagem privada.
- `intelligence_actions` continua representando a ação organizacional concreta; `bee_action_requests` representa solicitação, autorização e auditoria.
- **OUTPUT ≠ OUTCOME ≠ IMPACT**: uma saída da Bee, um resultado observado e um impacto organizacional são conceitos distintos.
- Associação não é causalidade. `claim_strength` é declarado, não inferido, e `causal_validated` exige validação explícita.
- ROI nunca é presumido; valores financeiros, quando existentes, são registrados com moeda e metodologia.


## Organizational Memory + Event Layer V1

A branch `feature/organizational-memory-event-layer-v1` adiciona uma camada estruturada e temporal sobre PostgreSQL. Ela não usa graph database, não implementa event sourcing completo, replay da aplicação, Kafka/queue ou captura automática por triggers. As tabelas operacionais existentes continuam sendo a fonte de estado atual; eventos representam ocorrências registradas.

### Memória temporal

`organizational_memory_relations` conecta entidades por relação temporal com `organization_id`, tipos e IDs de origem/destino, relação, `knowledge_kind`, intervalo de validade, origem, sensibilidade e contexto JSONB objeto. Os tipos epistemológicos distinguem `fact`, `declaration`, `reading`, `hypothesis`, `decision`, `intervention` e `outcome`; hipótese não é fato e não é promovida implicitamente. Mudanças históricas encerram a relação anterior com `valid_until` e inserem uma nova relação, preservando a história. IDs polimórficos são referências descritivas sem FK falsa e nunca autorizam acesso.

### Event layer

`organizational_events` é append-oriented e registra `event_type`, entidade, ocorrência, registro, origem, ator, sensibilidade, payload JSONB objeto e correlação. Seu vocabulário é mantido em catálogo controlado: tipos arbitrários são rejeitados e novas extensões exigem mudança explícita no catálogo. O contrato inclui eventos de pessoas, feedback, check-in, PDI, assessment, aprendizagem, leitura, recomendação, decisão, intervenção, ação e outcome, além de contratos futuros de treinamento (`training_assigned`, `training_scheduled`, `training_completed`, `training_expiring`, `training_expired`, `recertification_scheduled`) marcados como não implementados. Não há replay, substituição de estado ou automação global. Conversa bruta da Bee não é armazenada.

### Segurança

RLS é tenant-safe: `admin_youb` e `rh` gerenciam memória no próprio tenant e registram eventos; diretoria lê somente conteúdo organizacional dentro das sensibilidades permitidas; gestor e colaborador não recebem leitura genérica. `standard`, `restricted` e `highly_sensitive` são vocabulários controlados. O contrato de leitura TypeScript é read-only para relações e eventos.

## Decision Engine + Wiring Core V1

O Decision Engine V1 adiciona `intelligence_decisions` como registro tenant-safe de escolha humana. A arquitetura preserva a cadeia: Recommendation (proposta) → Decision (escolha) → Approval (autorização adicional, quando exigida) → Intervention (plano explícito) → Action (execução) → Outcome (medição). Nenhuma etapa gera a seguinte por trigger ou automação.

Uma Recommendation pode ter zero ou várias Decisions históricas. Uma Decision pode ter zero ou várias intervenções por meio de `intelligence_decision_interventions`, com vínculo explícito `derived_from_decision` e FKs compostas tenant-safe. Interventions, Actions e Outcomes continuam usando as tabelas existentes; não há duplicação de estado operacional.

Decisions podem ser representadas na Organizational Memory por serviço controlado como entidade `decision`, com relação temporal e `knowledge_kind` explícito; decisões superseded permanecem disponíveis. O Event Layer recebe somente contratos implementados controlados (`decision_created`, `decision_approved`, `decision_rejected`, `decision_deferred`, `decision_superseded`, `decision_effective`), sem captura automática.

`evidence_snapshot` preserva o estado disponível no momento da decisão e não recalcula o passado. `alternatives_considered` e `unknowns` são arrays JSONB; `evidence_snapshot` e `context` são objetos JSONB. A Bee poderá preparar rascunhos, mas não autoaprovar decisões sensíveis. Organizational Reading Engine, Evidence Engine automático, Bee Runtime, LLM, UI final, scoring e automações permanecem fora do escopo.

### Hardening: Decision colaborativa e versionável

`intelligence_decisions` continua representando o estado corrente. Enquanto está em `draft` ou `pending_review`, admin_youb, RH e diretoria (dentro do escopo organizacional permitido) podem colaborar por uma função controlada. Cada alteração substantiva grava uma linha em `intelligence_decision_revisions`, com snapshots JSONB estruturados antes/depois, `changed_by_user_id`, motivo e sequência append-only. O `evidence_snapshot` pode mudar nesses estados somente por esse caminho.

Em `pending_approval`, diretoria pode aprovar sem alteração, rejeitar, devolver para revisão ou revisar conteúdo. Uma revisão nesse estado sempre retorna a Decision para `pending_review`; portanto, não existe aprovação implícita do conteúdo alterado. A aprovação final grava `approved_by=auth.uid()` e `approved_at` e leva a decisão a `decided`; isso não executa Action.

Depois de `decided` ou `effective`, o estado corrente é protegido contra update autenticado direto. Uma mudança é uma nova Decision criada pelo serviço de supersession: a nova linha contém `supersedes_decision_id` apontando para a predecessora, e a predecessora muda para `superseded`. A predecessora não aponta para frente e nenhuma das duas é apagada.

Os contratos controlados `decision_revised` e `decision_returned_for_review`, além de `decision_approved`, foram adicionados ao Event Layer. Eles não são emitidos por triggers automáticos. Não são armazenadas conversa bruta, prompt completo ou chain-of-thought.

## Organizational Reading Engine V1 — Leitura Organizacional

A arquitetura expõe **Leitura Organizacional** como a camada entre Contexto e Padrões. A cadeia é: DADOS → CONTEXTO → LEITURAS ORGANIZACIONAIS → PADRÕES → HIPÓTESES → EVIDÊNCIAS → RECOMENDAÇÕES → DECISÕES → INTERVENÇÕES → AÇÕES → IMPACTO → MEMÓRIA ORGANIZACIONAL. O nome técnico legado `intelligence_signals` pode permanecer internamente sem transformar Signal no conceito de produto.

`intelligence_organizational_readings` registra uma interpretação estruturada tenant-safe com tipo controlado (`movement`, `pattern`, `anomaly`, `risk`, `opportunity`, `tension`, `gap`, `evolution`), escopo compartilhado, janela de observação, detecção, resumo de fonte e contexto. Em V1, `knowledge_kind` é obrigatoriamente `interpreted`: a Reading não é automaticamente fato, declaração, observação confirmada ou causa.

Reading e Hypothesis não são a mesma coisa. Reading descreve o que a organização apresenta; Hypothesis (`knowledge_kind = hypothesis`) registra uma explicação possível sobre por que isso ocorre. `supported` em uma hipótese não equivale a causalidade confirmada; Evidence Engine posterior continua necessário.

A junction `intelligence_organizational_reading_sources` referencia, com FKs compostas tenant-safe, múltiplas fontes existentes: `intelligence_evidence`, `knowledge_sources`, `knowledge_documents`, `organizational_events` e relações de memória. Não duplica o Evidence Engine. Cada vínculo declara seu tipo de relação e provenance.

Leituras podem ser registradas explicitamente na Organizational Memory como entidade `reading` e `knowledge_kind = interpreted`. O Event Layer recebe contratos controlados `organizational_reading_created`, `organizational_reading_updated`, `organizational_reading_supported` e `organizational_reading_dismissed`; nenhum trigger faz projeção automática.

Para preservar histórico, o estado corrente pode ser revisado pelo caminho controlado em `open`/`under_investigation`, com `intelligence_organizational_reading_revisions` append-only. A suíte e o contrato não armazenam conversa bruta, prompt completo ou chain-of-thought. Não há geração automática de evidência, scoring, ranking, ML, LLM, diagnóstico ou criação de Recommendation/Decision/Intervention/Action.


### Estado da entrega

O Organizational Reading Engine V1 está em `READY FOR STAGING` após o hardening final da suíte e o Build/typecheck. Isso não é `READY FOR MERGE`; a execução SQL/RLS autenticada em staging continua pendente. PR #8 permanece `READY FOR STAGING`.

## Evidence + Recommendation Operational V1

Esta camada operacionaliza o trecho Leitura Organizacional → Hipótese → Evidência → Avaliação de suficiência → Recommendation, preservando a cadeia epistemológica completa. `intelligence_evidence_assessments` registra a avaliação manual/controlled de uma Reading e de uma Hypothesis opcional. Counts são resumo; relações normalizadas de evidências supporting/contradicting são a provenance autoritativa.

`evidence_state` usa vocabulário fechado: `insufficient` (não sustenta Recommendation), `weak` (elementos iniciais com lacunas relevantes), `moderate` (Recommendation cautelosa possível com limitations), `strong` (suporte coerente de múltiplas fontes) e `conflicting` (evidências relevantes em direções diferentes). Nenhum estado é probabilidade de causa. `unknowns` e `limitations` são obrigatórios como arrays estruturados, e a ausência de evidência não vira evidência negativa.

Recommendations existentes recebem vínculos explícitos e tenant-safe para Reading, Assessment, Hypothesis e Evidence. `intelligence_recommendation_evidence` reaproveitado é complementado com relação `supports`/`contradicts`; não há segunda Evidence Engine. A Recommendation mantém rationale, evidence_state, unknowns, alternatives, do_not_recommend, measurement_plan, approval_required, owner, scope e context. `proposed`/`accepted` com `evidence_state = insufficient` são bloqueados.

Assessments e Recommendations podem ser revisados por caminho controlado com snapshots append-only, autoria, motivo e timestamp; updates autenticados diretos foram removidos para evitar reescrita silenciosa. Memory e Event Layer recebem registros somente por serviços controlados. Não há criação automática de Decision, Intervention, Action ou Outcome.


### Estado da entrega

Evidence + Recommendation Operational V1 está em `READY FOR STAGING` após os dois hardenings auditados e Build/typecheck aprovado. Isso não é `READY FOR MERGE`; PR #9 permanece `READY FOR STAGING`; SQL/RLS runtime autenticado continua pendente.


### Compatibilidade da Recommendation Evidence

A relação histórica `intelligence_recommendation_evidence` preserva a identidade composta `organization_id + recommendation_id + evidence_id` e não possui coluna sintética `id`. `evidence_relation` e `context` foram adicionados aditivamente. Portanto, a mesma Evidence não pode simultaneamente ser `supports` e `contradicts` na mesma Recommendation; essa exclusividade é intencional e coberta pela suíte. Types e service usam a identidade composta real.

## Bee Runtime V1

O Bee Runtime V1 é uma camada read-only e determinística sobre os read services existentes. Ele carrega, sob RLS e sem bypass, Readings, Reading Sources, Hypotheses, Evidence, Evidence Assessments, Recommendations, Decisions, revisões/intervenções permitidas, Organizational Memory, Events, Actions e Outcomes. O compositor retorna um read model estruturado com bundles `Reading → Hypothesis → Evidence/Assessment → Recommendation → Decision → Intervention/Action/Outcome`, além de provenance, unknowns e limitations; não retorna dumps brutos, payloads desnecessários, prompts ou conversas.

`BeeRuntimeContext` exige organization, usuário, papel, employee quando aplicável, escopos autorizados, população implícita nos escopos, sensitivity permitida e purpose. Para colaboradores, o Runtime restringe a contextos pessoais autorizados; para demais papéis, só considera escopos explicitamente fornecidos e resultados que o RLS já devolveu. `scope_ref` nunca é autorização e o Runtime não cria permissões paralelas.

Os intents V1 são determinísticos: `attention_today`, `explain_reading`, `explain_hypothesis`, `explain_evidence`, `explain_recommendation`, `explain_decision`, `list_unknowns`, `list_open_readings`, `list_actions` e `explain_outcome`. `attention_today` prioriza, nesta ordem transparente, risco aberto, evidência conflitante, evidência insuficiente em investigação, Recommendation que exige aprovação, Decision pendente, Action próxima/vencida e Outcome não validado, com limite padrão de cinco itens.

As funções de explicação preservam linguagem epistemicamente segura: hipótese é hipótese em investigação; Reading é leitura registrada; Recommendation é proposta preparada; Decision é decisão registrada; Action não é declarada executada pela Bee. `insufficient` e `conflicting` são sinalizados explicitamente. O Runtime não escreve, não executa, não cria Recommendation/Decision/Intervention/Action/Outcome e não registra cada consulta como evento.


### Estado da entrega

Bee Runtime V1 está em `READY FOR STAGING` após código, testes verificáveis e Build/typecheck. Isso não é `READY FOR MERGE`. PR #10 permanece `READY FOR STAGING`, congelado no head `316ee97c15ab96f10d77ea06ae7a9dd51c87094e`; não há migration e SQL/RLS runtime autenticado continua pendente.

## Product Wiring + Executive Home V1

A experiência de Home executiva é um consumidor do Bee Runtime V1, não um novo engine. A rota `/executive` carrega uma vez o read model autorizado e deriva dele o resumo executivo, as prioridades, listas de exceção e o detalhe estruturado. O detalhe chama `explainReading` e `explainRecommendation`, preservando a cadeia Reading → Hypothesis → Evidence → Evidence Assessment → Recommendation → Decision → Intervention → Action → Outcome.

A Home usa `attentionToday` sem recalcular epistemologia, causalidade ou score na UI. Cards exibem regra de prioridade, resumo, status, evidence state quando disponível, data e CTA de aprofundamento. Empty, loading e error states não confundem ausência autorizada com execução ou decisão.

Para papéis organizacionais, o contexto é montado com escopos explícitos e os resultados continuam subordinados ao RLS. Para colaborador, a rota não exibe Home de inteligência organizacional e encaminha para a experiência pessoal já existente. Quick actions chamam intents determinísticos do Runtime; não há write, chat persistente, LLM ou audit log de consulta.


### Estado da entrega

Product Wiring + Executive Home V1 está em `AUDIT` após código, Build e testes. PR #11 permanece `READY FOR STAGING`, congelado no head `25e5fff0540ab460ce16fededbc47b2e1e71e91f`. Esta entrega não é `READY FOR STAGING` nem `READY FOR MERGE`; não há migration nem validação de staging.

## Product Wiring + Executive Home V1 — hardening

O wiring de Home mantém o Bee Runtime como fonte autorizada. A coleção de Readings abertas é derivada por `listOpenReadings` e não trata status resolvido ou arquivado como aberto. A coleção de Actions próximas usa janela explícita de 24 horas, incluindo vencidas e excluindo futuras distantes, sem alterar o Runtime congelado.

O detail expõe a cadeia somente quando cada relação está presente no `BeeRuntimeReadModel`: Reading, Hypothesis, Evidence, Evidence Assessment, Recommendation, Decision, Intervention, Action e Outcome. Nenhum elo é inventado. Recommendation, Decision, Action e Outcome permanecem semanticamente distintos e com linguagem segura.

Não existem rotas reais verificadas para os atalhos Pessoas, Avaliações, PDI e desenvolvimento ou Relatórios no mockup atual; por isso os cards foram omitidos. Gap registrado: **Manager/team authorized population wiring pending**. A população autorizada de equipe do gestor será conectada com a estrutura de pessoas/equipes em entrega posterior.

O estado desta correção permanece `AUDIT → FIX`; não é `READY FOR STAGING`.

### Correção de relação Decision → Intervention

O Product Wiring resolve Decision → Intervention somente a partir de `BeeDecisionNode.interventionIds`, que é a relação explícita preenchida no read model real. `BeeInterventionNode.decisionId` pode permanecer nulo e não é tratado como fonte principal. A cadeia continua read-only, sem alteração do Runtime congelado.

### Continuação explícita da cadeia downstream

O detail da Home resolve Intervention → Action → Outcome somente por IDs presentes no `BeeRuntimeReadModel`. A Action é localizada por `action.interventionId`; o Outcome é localizado primeiro por `outcome.actionId` e depois por `outcome.interventionId` quando não houver Outcome ligado à Action. Ausência de relação permanece ausência, sem inferência ou nova epistemologia.

### Resolver para todos os findings selecionáveis

O detail da Home agora inicia a reconstrução a partir de Reading, Assessment, Recommendation, Decision, Action ou Outcome. As relações upstream/downstream são limitadas às chaves explícitas do read model: `linkedReadingIds`, `linkedAssessmentIds`, `recommendationId`, `interventionIds`, `interventionId` e `actionId`. Não há inferência por título, escopo, data, status ou posição. O Runtime congelado não foi alterado.

## Product Wiring + Executive Home V1 — estado final auditado

A auditoria técnica final do Dodo foi concluída com sucesso no head `8bf3f2d9b2f93b256a21e5223a47186418ab7b1a`. O PR #12 está **IMPLEMENTADO + AUDITADO → READY FOR STAGING**. O Build #239 (`pull_request`) e os testes Bee Runtime + Executive Home/Product Wiring passaram; não há bug conhecido bloqueante no escopo desta entrega.

`bee-runtime.ts` permaneceu congelado, assim como as sete suítes SQL. Não foram criadas migrations. PR #11 continua congelado no head `25e5fff0540ab460ce16fededbc47b2e1e71e91f`. `Manager/team authorized population wiring pending` segue como gap conhecido e não bloqueante do PR #12.

A execução autenticada de SQL/RLS das fundações em staging continua pendente antes de qualquer `READY FOR MERGE`. `READY FOR STAGING` não significa `READY FOR MERGE`. Este fechamento é documental: não houve merge, deploy, alteração da main, staging ou produção.
