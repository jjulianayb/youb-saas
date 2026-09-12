# youB — Access Model v1

> Contrato arquitetural da Sprint 1. Separa plataforma, partner/reseller e organização. Não substitui RLS, contexto autenticado, backend ou auditoria.

## Objetivo

```text
PLATFORM
  └── PARTNER / RESELLER
        └── ORGANIZATION
              └── USERS / EMPLOYEES
```

A identidade do usuário é global; o acesso é contextual, mínimo, explicável e auditável. A **Bee** é a assistente/IA/avatar da youB. Bee nunca decide autorização e só recebe contexto e dados já filtrados pelo backend e pelo RLS.

## Camadas

### Plataforma

- `platform_admin`: administração operacional da plataforma;
- `platform_support`: suporte temporário, mínimo e sempre auditado;
- `platform_analyst`: dados agregados e explicitamente autorizados.

### Partner / Reseller

- `partner_admin`: gestão do próprio tenant de partner;
- `partner_operator`: implantação e operação delegada;
- `partner_support`: suporte limitado às organizações concedidas.

O vínculo partner–organization é próprio, explícito, com estado, escopo, validade e auditoria. Ser membro de um partner não torna o usuário membro de nenhuma organização automaticamente.

### Organização

- `organization_admin`: configuração e usuários autorizados;
- `diretoria`: visão e decisões conforme capability;
- `rh`: governança de pessoas, ciclos, recomendações e intervenções;
- `gestor`: equipe/cadeia autorizada;
- `colaborador`: próprio perfil e dados permitidos.

`admin_youb` permanece somente como compatibilidade histórica. Não é autorização global da plataforma.

## Princípios obrigatórios

1. `organization_id` vindo do frontend não é autorização.
2. O servidor resolve o tenant pelo contexto autenticado.
3. Toda entidade pertence a exatamente um tenant.
4. Toda referência entre entidades deve ser validada no mesmo tenant.
5. RLS permanece obrigatório mesmo com API/BFF.
6. UI oculta ações; backend/RLS autoriza.
7. Branding, domínio, logo, cores e nome da Bee não definem acesso.
8. Suporte é temporário, explícito, mínimo e auditado.
9. Bee recebe somente contexto já filtrado.
10. Dados sensíveis, exportação e uso de IA geram audit log.
11. `suspended`, `revoked`, `closed` e grants expirados não concedem acesso.
12. Ausência de vínculo resulta em zero registros, sem fallback permissivo.

## Contexto de requisição

```text
requestContext = {
  userId,
  platformCapabilities,
  partnerGrants,
  organizationId,
  organizationCapabilities,
  populationScope,
  purpose,
  requestId
}
```

`populationScope` pode representar organização, unidade, área, time, cadeia de gestão ou o próprio usuário. `manager_employee_id` é dado organizacional e não prova autorização sozinho.

## Compatibilidade com o banco atual

- Reutilizar `organizations`, `memberships`, `employees`, `areas`, `positions`, `competencies`, `cycles`, `assessments`, `feedbacks`, `pdis`, `checkins` e entidades disciplinares.
- Manter a criação legada de organização até existir provisionamento contextual.
- Não alterar o significado dos dados sem migration de compatibilidade.
- Não usar HTML legado ou dados de cliente como seed.
- O novo modelo Platform/Partner não concede acesso às tabelas organizacionais legadas. Cada tabela continua dependendo das próprias policies e do vínculo em `memberships`.
- Referências legadas — employee, cycle, assessment, feedback, PDI e similares — precisam validar o mesmo tenant; `organization_id` isolado não basta.

## Bootstrap seguro de `platform_admin`

A migration não cria, promove nem concede automaticamente nenhum `platform_admin`.

O primeiro `platform_admin` deve ser provisionado fora do fluxo público de autenticação, por migration operacional ou endpoint interno com credencial server-side protegida. A operação deve verificar a identidade do operador; conferir o usuário por identificador exato; definir role, estado e validade explicitamente; registrar ator, alvo, motivo e request id; exigir revisão independente para produção; e executar testes de concessão e negação antes da liberação.

Não usar `organization_id`, branding, `admin_youb`, membership de partner ou frontend para bootstrap.

### Quem pode criar ou promover outro `platform_admin`

A policy da fundação permite gerir `platform_memberships` somente quando `is_platform_role(array['platform_admin'])` é verdadeira. Assim:

- apenas um `platform_admin` ativo e não expirado pode criar, atualizar, suspender ou revogar outro acesso de plataforma;
- `platform_support`, `platform_analyst`, roles de partner e roles organizacionais não podem promover ninguém;
- nenhum usuário autenticado pode se auto-promover sem já possuir um `platform_admin` ativo;
- `service_role`/owner do banco pode contornar RLS e deve ficar restrito a bootstrap, recuperação e migração, com segregação e auditoria;
- a promoção deve passar por endpoint protegido, motivo, validação de estado e audit log; nunca por operação genérica do cliente.

A policy não substitui controles de aplicação, segregação de funções e revisão humana.

## Grants de partner e validade

Um grant só autoriza a organização, escopo e finalidade indicados enquanto membership do usuário e partner estão ativos, grant está ativo e não expirado e capability/população correspondem ao `requestContext`. `partner_admin`, `partner_operator` e `partner_support` têm leitura operacional separada; somente `partner_admin` administra memberships e grants do próprio partner. Suporte exige grant, finalidade e trilha de auditoria.

## Risco de `ON DELETE CASCADE`

As entidades de Partner usam `ON DELETE CASCADE` para memberships e grants. Isso é útil para limpeza técnica, mas apagar um partner pode apagar relações de acesso e destruir a explicação histórica de quem teve acesso a qual organização.

Em produção, não excluir partner, membership ou grant com histórico. Usar `closed`, `revoked` ou `suspended`; manter audit log append-only fora da cadeia de cascade; e reservar hard delete para limpeza formal sem obrigação de retenção, com aprovação, backup, janela controlada e registro. A suíte de RLS não substitui a preservação histórica: isso exige tabela/serviço de auditoria e procedimento operacional próprio.

## Operações obrigatoriamente auditadas

Registrar `request_id`, ator, alvo, tenant/partner, capability, escopo, finalidade, resultado e timestamp para:

- bootstrap, criação, promoção, suspensão, revogação e expiração de `platform_admin`;
- criação, alteração, suspensão, revogação e fechamento de partner;
- mudanças em partner memberships e partner–organization grants;
- concessão e encerramento de suporte temporário;
- mudanças de memberships, roles ou capabilities organizacionais;
- leitura/exportação de dados individuais sensíveis;
- chamadas da Bee que consultem dados individuais, gerem recomendação ou acionem fluxo;
- criação, alteração, aprovação, rejeição ou exclusão lógica de PDI, recomendação e ação disciplinar;
- uso de `service_role`, recuperação e qualquer bypass de RLS;
- tentativas negadas de acesso privilegiado relevantes para segurança.

O log deve ser append-only para consumidores da aplicação e não deve armazenar segredos, tokens ou dados pessoais desnecessários.

## Matriz inicial

| Capacidade | Plataforma | Partner | Organização | Gestor | Colaborador |
|---|---:|---:|---:|---:|---:|
| Administrar plataforma | Sim | Não | Não | Não | Não |
| Administrar organizações delegadas | Conforme grant | Sim | Própria | Não | Não |
| Administrar usuários | Suporte auditado | Conforme grant | Sim | Não | Não |
| Visão organizacional | Agregado | Conforme grant | Conforme role | Equipe | Próprio |
| Criar recomendação | Não padrão | Conforme grant | RH/diretoria | Conforme fluxo | Não |
| Dados individuais sensíveis | Mínimo/auditado | Mínimo/auditado | Conforme escopo | Equipe autorizada | Próprio permitido |

A matriz deve ser detalhada por recurso, ação, população e sensibilidade antes da implementação.

## Suíte permanente de RLS

`supabase/tests/rls_access_foundation.sql` é uma suíte de staging rollback-only. Ela falha rápido se a fundação ou entidades legadas não existirem; cria dois tenants e dados de negócio nos dois; autentica um usuário membro somente do tenant A; testa usuário sem partner, grants ativo/expirado/suspenso/revogado, partner sem grant e os três papéis de partner; verifica escrita privilegiada; confirma isolamento das tabelas legadas e que Platform/Partner não amplia acesso; devolve um JSON consumível por CI e sempre executa `rollback`.

Executar somente após todas as migrations em staging descartável. A suíte não autoriza aplicar a migration em produção.

## Transição de `admin_youb`

Não fazer rename destrutivo. Inventariar memberships, separar organização de suporte de plataforma, criar vínculos mínimos, preservar histórico, testar dois tenants e remover dependências do frontend somente depois da validação.

## Critérios de aceite

- Usuário de organização não consulta outro tenant, inclusive por IDs relacionados.
- Gestor não acessa pessoas fora do escopo.
- Partner só acessa organização com grant ativo, escopo correto e validade vigente.
- Suporte só acessa operação autorizada e fica auditado.
- Branding diferente não altera autorização.
- Bee não recupera registros fora do contexto.
- Frontend não é necessário para garantir segurança.
- Nenhum vínculo Platform/Partner abre acesso às tabelas organizacionais legadas.
- Bootstrap e promoção de `platform_admin` são controlados e auditados.
- Exclusão física de Partner não revoga acesso nem substitui histórico.
- Toda decisão é explicável por identidade, camada, capability, escopo, estado, finalidade e request id.
