# youB — Backend/Data Readiness V1

**Auditoria-base:** `integration/ambient-ux-v1`  
**Commit auditado:** `3740a6071b0df149d530f8c068f316dbd77205ff`  
**Branch de auditoria:** `audit/backend-data-readiness-v1`  
**Escopo:** prontidão técnica e de dados para as experiências da Commercial V1. Nenhum arquivo de interface, migration, RLS, Auth, banco ou produção foi alterado.

## Resumo executivo

A base possui uma fundação real de autenticação, multiempresa, memberships, papéis, RLS, dados clássicos de DHO, PDI, Feedback 360, Intelligence Core e Ambient Intelligence. O CI do commit-base está verde, e os testes locais de RLS e dos contratos de inteligência passam.

A base **ainda não consegue alimentar com dados reais e semanticamente completos todas as telas das referências**. Os principais bloqueios são:

1. não existe um contrato único de contexto autorizado/capabilities/entitlements consumido por todas as experiências;
2. a seleção de organização pode cair arbitrariamente na primeira membership quando não há organização escolhida;
3. a Home Executiva tem dados reais possíveis via Bee Runtime, mas o carregamento degrada falhas de fontes para arrays vazios;
4. a Home de RH possui contagens reais, mas não possui fontes/aggregators para retenção, sucessão, capacidade de liderança ou impacto;
5. Organização Viva não possui adapter real de grafo/relacionamentos;
6. Ambient Intelligence tem tabelas, contratos e RLS, mas não tem ingestão de provedores nem integração uniforme nas quatro Homes;
7. várias leituras legadas convertem erro de fonte em estado vazio, impedindo distinguir “sem dados” de “fonte indisponível”.

Não foi implementada nenhuma correção nesta etapa.

## Matriz de prontidão por tela

| Tela | Informação exibida | Fonte atual | Real/Demo/Ausente | Permissão necessária | Bloqueio | Correção proposta | Prioridade |
|---|---|---|---|---|---|---|---|
| Home Executiva | Atenção do dia, leituras organizacionais, recomendações, decisões, ações, outcomes, DHO | `readBeeRuntime` → tabelas `intelligence_*`, knowledge e eventos; RLS no banco | Real quando existem registros autorizados; preview/demo separado; métricas executivas derivadas não existem | Diretoria pode ler contexto organizacional autorizado e decidir em escopos permitidos; admin/RH possuem leitura administrativa; dados pessoais não são implícitos | `loadBeeRuntimeSource` usa `safe()` por fonte e transforma falhas em arrays vazios; não há DTO de freshness/quality; não há adapter para KPIs de retenção/sucessão | Criar read model/BFF ou adapter de Home com `source_status`, `freshness`, `context_status`, provenance e separação entre vazio e indisponível | P1 |
| Home do Gestor | Pessoas do time, feedbacks, PDIs, check-ins, avaliações; leitura Ambient opcional | `Dashboard.loadData` com filtros de subordinados; `readAmbientFoundation` somente para `gestor`; `ManagerHome` compõe prioridades locais | Dados clássicos podem ser reais; prioridades Ambient só são reais se as tabelas estiverem populadas; componentes de preview usam fixture | `gestor` + employee vinculado; escopo por `manager_employee_id`; RLS e `classicPopulationMode` devem coincidir | Se employee vinculado não existir, população vira vazia; falhas Ambient são absorvidas e `ambientModel` vira `null`; não existe agregador de impacto do time | Criar adapter de Manager Home com contexto, escopo, estado de fonte e agregações calculáveis; não tratar ausência Ambient como ausência de risco | P1 |
| Home de RH | Contagens de pessoas, feedbacks, PDIs e ciclos; navegação para módulos | `Dashboard` busca `employees`, `feedbacks`, `pdis`, `cycles`; `RhHome` recebe somente `counts` | Contagens podem ser reais; “retenção”, “sucessão”, “capacidade”, “impacto” e intervenções estratégicas não possuem fonte calculada nesta base; preview é demonstrativo | `admin_youb`/`rh` para população organizacional; RLS das tabelas clássicas | Não existe fonte ou RPC de KPI executivo de RH; contagens não sustentam os indicadores da referência; `roleCapabilities` é estático no cliente | Definir read model de RH com métrica, período, fonte, população, unidade, freshness e estado de insuficiência; somente depois conectar a UI | P1 |
| Home do Colaborador | Identidade, PDIs, último check-in, ações, avaliações concluídas, scores e competências | `getEmployeeExperienceContext` + `readEmployeeHomeData`; tabelas `pdis`, `checkins`, `intelligence_actions`, `assessments`, `assessment_competency_scores`, `competencies` | Dados podem ser reais quando há `employees.auth_user_id`; feedbacks e jornada completa não são carregados; check-in da Home não possui escrita própria | Colaborador somente no próprio employee/contexto; PDI raw via leitura própria; RLS clássico e PDI | `safeLegacyRead` devolve `[]` em qualquer erro; isso parece estado vazio; não há adapter para feedbacks/conquistas/aprendizados; check-in visual não está conectado à escrita | Retornar estado por fonte (`available`, `empty`, `unavailable`), incluir feedbacks autorizados e expor somente ações realmente disponíveis | P1 |
| Organização Viva | Grafo de Pessoas, Times, Projetos, Cultura, Capacidades, Conhecimento e Sucessão; painel de evidências | Não há adapter/tabela de grafo consumida pela Home; existem `organizational_memory_relations`, eventos, readings e fontes no Intelligence Core | Ausente como experiência de dados; mapas nos previews são demo/fixture; relações existentes não são montadas em grafo navegável | Deveria combinar organização + escopo + sensitivity + provenance; não há contrato de módulo específico | Não existe resolver de entidades, arestas, intensidade, cluster, nó central, evidência e painel contextual | Criar contrato de leitura do grafo e adapter somente depois de aprovar escopo; usar memory/events/readings como fontes, sem inventar relações | P1 |
| PDI e desenvolvimento | PDI, objetivos, ações, check-ins, links de fonte, auditoria e transições | `pdiRpc` para RPCs; `PdiDevelopment` lê tabelas de detalhe; migrations `20260908100000_pdi_development_v1.sql` | Backend funcional para operações autorizadas; leitura de aggregate existe em `pdi_read_organization_aggregate`, mas não é consumida pela Home | `pdi_can_read_raw` para leitura; admin/RH/gestor para gestão conforme employee/escopo; colaborador lê o próprio | Dashboard ainda mantém POST legado em outras áreas; não há read model único de PDI; origem de feedback/360 é opcional e depende de dados fechados | Consolidar adapter PDI usando RPCs/queries já existentes, adicionar estado de fonte e utilizar aggregate apenas onde autorizado | P1 |
| Feedbacks e check-ins | Feedbacks privados, check-ins diários, indicadores de clima/energia/carga, 360 | `Dashboard` consulta `feedbacks` e `checkins`; `Feedback360Evolution` usa adapters e RPCs de `feedback_360_*` | CRUD clássico pode ser real; agregados 360 dependem de rounds/participants/scores; check-in do colaborador não tem fluxo de gravação | Feedback/check-in: admin/RH/gestor para gestão; colaborador lê próprio; 360 usa RPCs com papel e confidencialidade | Não há camada comum de qualidade/freshness; métricas “engajamento médio” são médias locais da carga retornada; sem fonte de comparação temporal; falhas viram erro/empty dependendo do módulo | Criar contratos de agregação com período, população, response count, confidentiality e `source_status`; não exibir KPI quando denominator/quality forem insuficientes | P1 |
| Bee e Ambient Intelligence | Perguntas, atenção hoje, unknowns, provenance, fontes, preferências e compromissos | Bee Runtime (`intelligence-core`) e Ambient (`ambient_source_registry`, observations, reviews, preferences, attention, briefs, commitments) | Contratos e persistência são reais; dados dependem de ingestão/manual input; inferências têm `epistemic_kind`, mas não há provider adapter | Bee Runtime usa role/scope/RLS; Ambient usa `ambient_visibility_allows`, owner, roles e user ids | Ambient é carregado na UI somente para gestor; não há integração uniforme em RH/Diretoria/Colaborador; não há ingestão de fonte externa; `generated_by` é human reviewed/future preview, não geração automática | Criar camada de source adapters e um read model Ambient por papel, sempre mantendo epistemic kind, provenance, limitations e insufficient status | P1 |

## Autenticação e restauração de sessão

### O que existe

- `signIn` usa Supabase Auth password grant.
- `sessionFromAuth` exige `access_token` e `user`.
- `restoreSession` recupera `youb-session` do `localStorage`.
- Sessão expirada tenta refresh usando `refresh_token`.
- Falha de parse/refresh remove sessão e organização armazenadas.
- Os testes cobrem sessão válida, refresh, refresh inválido e signup.

### Limitações

- A sessão é mantida em `localStorage`; não há observabilidade de expiração, logout remoto ou estado de revogação além da resposta do Auth.
- O contexto de organização é outro item de `localStorage` e pode ficar stale em relação à membership atual.
- Não há um adapter central que retorne sessão + organização + membership + employee + capabilities + estado de fonte em uma única resposta.

## Identificação de organização e separação multiempresa

### Proteções existentes

- Consultas principais filtram `organization_id`.
- Migrations usam chaves compostas e foreign keys tenant-scoped em grande parte do Intelligence Core.
- `has_org_role`, `is_org_member`, `classic_*` e `intelligence_*` são usados em RLS.
- O CI executa a suíte local de migrations/RLS com sucesso.

### Bug encontrado — seleção implícita de organização

`getEmployeeExperienceContext` consulta memberships com `limit=1` quando não recebe `organizationId`. Se o usuário possui várias organizações e não existe uma seleção local válida, a função aceita a primeira linha retornada.

Consequências possíveis:

- abrir a Home correta para a organização errada;
- carregar contexto, employee e dados de outro tenant autorizado ao mesmo usuário;
- mascarar a necessidade de escolha explícita de organização.

Isso não configura, pelo código auditado, leitura entre tenants não autorizados, mas configura **contexto de tenant incorreto** e deve falhar fechado.

**Prioridade:** P1.

## Roteamento por perfil

O contrato atual é:

- `diretoria` → `ExecutiveHomeRoute`;
- `colaborador` → `EmployeeExperienceRoute`;
- `rh`, `gestor`, `admin_youb` → `Dashboard`.

O papel é obtido de `memberships.role`, limitado aos cinco papéis legados. A rota comercial não possui uma decisão baseada em capabilities reais; usa o papel fixo.

### Risco encontrado

`roleCapabilities` é uma constante no frontend. Ela não vem do backend, não é validada contra uma matriz configurável e não decide efetivamente a autorização do banco. Isso pode fazer a interface afirmar capabilities que não correspondem ao contrato operacional real.

**Prioridade:** P1.

## Vínculo usuário ↔ colaborador

O vínculo é procurado por:

```text
employees.organization_id = organization.id
employees.auth_user_id = session.user.id
```

Isso é suficiente para o fluxo pessoal quando há exatamente um employee. Porém:

- zero vínculos vira `employeeId = null` e algumas experiências continuam carregando;
- mais de um vínculo também vira `null` na leitura do Dashboard (`length === 1`);
- o contexto não retorna um estado explícito `unlinked` ou `ambiguous`;
- Home do Colaborador fica sem dados, mas a causa pode parecer simplesmente “nenhum registro”.

**Prioridade:** P1 para dados e diagnóstico; RLS continua sendo a autoridade final.

## Permissões e RLS

### Pontos fortes

- Papéis e memberships são tenant-scoped.
- Colaborador é limitado ao próprio employee em tabelas clássicas.
- Gestor usa relação `manager_employee_id` em filtros e helper SQL.
- Intelligence Core possui helpers para decision maker, employee scope e own employee.
- Diretoria não é implicitamente autorizada a acessar dados pessoais Ambient; o hardening exige audience explícita.
- PDI possui RPCs `security definer`, checagem de tenant, escopo, versão e auditoria.
- Feedback 360 possui RPCs de aggregate/subject/evolution e modo confidencial.

### Pontos de atenção

- A segurança depende de RLS e RPCs hospedados; os filtros do frontend não são garantia de autorização.
- O frontend usa capabilities estáticas e não possui um contrato uniforme de módulo/capability.
- Parte das leituras clássicas usa acesso REST direto; não há um gateway/read model que normalize autorização, freshness e origem.
- O Dashboard base continua permitindo que um `role` nulo siga para leituras organizacionais gerais antes de qualquer falha explícita. Os filtros de employee tendem a ficar vazios, mas o estado de autorização não é encerrado no início.

## Real, demonstrativo, inferência e ausente

### Dados reais possíveis

- memberships, organizations, employees;
- áreas, posições, ciclos;
- feedbacks e check-ins;
- PDIs e entidades de desenvolvimento;
- avaliações e scores;
- Feedback 360 fechado/submetido;
- sinais, evidências, readings, recommendations, decisions, interventions, actions, outcomes;
- eventos, memória organizacional, fontes e documentos publicados;
- registros Ambient persistidos.

### Dados demonstrativos

- previews em `CommercialV1Demo`, `ManagerHomePreview`, `EmployeeHomePreview` e componentes semelhantes;
- qualquer mapa Organização Viva que não venha de um adapter de grafo real;
- métricas fixas de retenção, sucessão, liderança, engajamento ou impacto presentes em previews;
- estados de Bee escritos como preview/future planned.

### Inferências

- `epistemic_kind = machine_inferred` existe no Ambient, mas exige `provenance.basis` no serviço de escrita.
- Hypotheses, readings, recommendations e assessments são entidades distintas no Intelligence Core.
- O backend não calcula confidence, score ou causalidade automaticamente no V1; esses campos não devem ser apresentados como métricas calculadas sem fonte.

### Ausentes

- KPI real de retenção, sucessão, capacidade de liderança e impacto da referência;
- grafo relacional Organização Viva navegável;
- source adapter para calendário, HRIS, ATS, LMS ou outros provedores;
- freshness/last-updated/quality de cada indicador;
- contrato central de capabilities e módulos;
- agregador de Home por papel;
- feedbacks e conquistas completos na Home do Colaborador;
- ingestão automática Ambient.

## Bugs e inconsistências encontrados

| ID | Achado | Efeito | Prioridade |
|---|---|---|---|
| B-01 | Organização ausente pode ser escolhida implicitamente pela primeira membership (`limit=1`) | Contexto de tenant potencialmente incorreto | P1 |
| B-02 | `role` nulo no Dashboard não interrompe o carregamento imediatamente | UI pode prosseguir com estado de autorização indefinido; leituras organizacionais genéricas ainda são tentadas | P1 |
| B-03 | `roleCapabilities` é hardcoded no cliente | Interface não representa uma fonte real de capabilities/entitlements | P1 |
| B-04 | `safe()` do Bee Runtime converte falhas de cada fonte em `[]` | Fonte indisponível aparece como ausência de dados; Home pode parecer saudável sem evidência | P1 |
| B-05 | `safeLegacyRead` do Colaborador converte qualquer erro em `[]` | Impossível diferenciar vazio, RLS denial, tabela ausente e indisponibilidade | P1 |
| B-06 | Employee ausente ou ambíguo vira `employeeId = null` sem estado discriminado | Home pessoal pode exibir vazio sem explicar vínculo ausente/ambíguo | P1 |
| B-07 | Ambient Foundation é carregada no Dashboard somente para `gestor` | RH, Diretoria e Colaborador não possuem integração Ambient equivalente | P1 |
| B-08 | `ExecutiveHomeRoute` depende do Bee Runtime, mas não possui source-status por entidade | Home executiva pode mostrar vazio sem contexto suficiente | P1 |
| B-09 | Organização Viva não tem adapter real de grafo | Mapa visual não pode ser alimentado com segurança por dados reais | P1 |
| B-10 | Métricas estratégicas da referência não têm endpoint/RPC/adapter correspondente | Não é possível afirmar retenção, sucessão, capacidade ou impacto como dado real | P1 |
| B-11 | Dashboard consulta muitos recursos diretamente e compõe estado no cliente | Falhas parciais, freshness e consistência entre cards não são normalizadas | P2 |
| B-12 | Não existe contrato de freshness, período, denominador e qualidade para médias/percentuais | Indicadores podem ser interpretados fora do recorte correto | P2 |

## Riscos críticos de exposição

1. **Tenant errado por seleção implícita:** o usuário pode possuir várias organizações; a escolha automática não é segura do ponto de vista de contexto.
2. **Dependência de RLS sem estado de autorização no frontend:** se uma policy ou migration hospedada não estiver no mesmo estado do código, o cliente não consegue explicar a diferença entre vazio e acesso negado.
3. **Escopo de gestor:** a proteção depende da relação `manager_employee_id` e de employee vinculado. Dados de gestor sem vínculo não devem ser tratados como organização inteira.
4. **Dados pessoais Ambient:** o hardening exige owner/user/role explícitos, mas o serviço ainda consulta por organização e depende da policy para filtrar; qualquer regressão de policy seria de alto impacto.
5. **Inferências apresentadas como fato:** readings, hypotheses, recommendations e métricas de preview não podem ser misturados sem `epistemic_kind`, evidence state, provenance e limitations.
6. **Confidencialidade Feedback 360:** aggregates e resultados individuais dependem de RPCs distintas; a UI não deve substituir `read_aggregate` por leitura bruta de participants/scores.

## Endpoints e adapters ausentes

### Ausentes ou incompletos

- `getAuthorizedExperienceContext`: organização obrigatória, membership, employee vínculo/ambiguidade, capabilities reais, escopos, módulos, source status e freshness.
- `getExecutiveHomeReadModel`: sinais, leituras, decisões, ações, outcomes e indicadores com provenance/quality.
- `getManagerHomeReadModel`: população direta, agregados, check-ins, feedbacks, PDIs e estado Ambient.
- `getRhHomeReadModel`: retenção, sucessão, capacidade, populações, ciclos, intervenções e impacto.
- `getOrganizationGraphReadModel`: nós, relações, intensidade, clusters, centralidade, filtros e evidências.
- `getEmployeeJourneyReadModel`: feedbacks, conquistas, trilhas, PDI e contexto pessoal completo.
- adapter de freshness/quality por fonte;
- adapters de ingestão de provedores para Ambient Intelligence;
- contrato de capability/module entitlement administrável;
- adapter único para agregações seguras de Feedback 360, PDI e check-ins.

## Funcionalidades visualmente prontas, mas ainda não funcionais ou incompletas

- **Organização Viva:** a camada visual pode existir, mas não há grafo real alimentando-a.
- **KPIs de retenção/sucessão/liderança:** podem aparecer em previews, mas não são calculados pelo backend atual.
- **Cenários/simulações:** não há motor de cenários nem dados de impacto; qualquer valor é demonstrativo.
- **Bee em todos os papéis:** BeeShell existe, mas a integração operacional é desigual; respostas dependem de callbacks e contratos que não estão uniformes.
- **Ambient Intelligence:** storage e filtros existem, mas sem ingestion/providers e sem integração nas quatro Homes.
- **Home de RH estratégica:** hoje é contagem clássica, não Intelligence Workspace com métricas de pessoas.
- **Home do Colaborador:** possui leitura de PDI/check-in/assessment, mas não possui jornada completa de feedbacks, aprendizados e conquistas.
- **Check-in do Colaborador:** a leitura existe; não há fluxo equivalente de gravação pela Home pessoal.
- **Indicadores derivados:** médias simples no Dashboard não possuem contrato de período, denominador, freshness ou qualidade.

## Estados de loading, vazio, erro e contexto insuficiente

### Existentes

- Rotas têm estados de loading, sessão ausente, erro e contexto indisponível.
- `AmbientBeeReadModel` possui `context_status = insufficient` e `limitations`.
- Bee Runtime possui listas vazias e explicações de unknowns.
- Componentes clássicos têm alguns `EmptyState`.

### Insuficientes

- Arrays vazios representam tanto “zero registros” quanto “request falhou”.
- Não existe estado por fonte/tabela.
- Não há distinção consistente entre RLS denial, tabela não migrada, timeout, contexto sem vínculo e ausência legítima.
- Não há freshness nem “última atualização” nos indicadores.
- O Bee Runtime carrega fontes com `safe()`, podendo produzir uma Home vazia sem erro crítico.

## Resultado de typecheck, testes e build

Resultado do CI do commit-base `3740a6071b0df149d530f8c068f316dbd77205ff`:

- **Build:** PASS
- **Typecheck:** PASS dentro de `Build workspace`
- **Bee Runtime unit tests:** PASS
- **Classic DHO access query tests:** PASS
- **SQL migrations e RLS suites locais:** PASS
- **Preview artifact:** PASS

CI: [34858627809](https://github.com/jjulianayb/youb-saas/actions/runs/34858627809)

Esta auditoria não alterou o código e não reexecutou migrations hospedadas.

## Próximo lote técnico recomendado

1. **P0/P1 — contexto autorizado único:** implementar/adaptar uma leitura central que exija organização explícita quando houver mais de uma membership e retorne `organization`, `membership`, `employeeLinkStatus`, `capabilities`, `scopes` e `sourceStatus`.
2. **P1 — estados de fonte:** substituir `safe()`/`safeLegacyRead` silenciosos por resultados discriminados (`available`, `empty`, `unavailable`, `unauthorized`, `insufficient`).
3. **P1 — read models por Home:** começar pela Home Executiva e Home de RH, sem inventar métricas; cada campo deve declarar fonte, período, população e qualidade.
4. **P1 — Organização Viva:** aprovar o contrato real de nós/arestas/evidências antes de qualquer integração visual.
5. **P1 — Ambient:** criar adapters de source registry e ingestão autorizada; integrar o read model por papel, mantendo `epistemic_kind`, provenance, limitations e human-required.
6. **P2 — observabilidade de dados:** registrar request/source status, latência, freshness e correlation id sem expor payload sensível.
7. **P2 — contract tests:** testar cada papel, múltiplas organizações, employee ausente/ambíguo, RLS denial, fonte vazia e fonte indisponível.

Nenhum item deste lote foi implementado nesta auditoria.
