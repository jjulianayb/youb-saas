import { AlertTriangle, ArrowRight, Gauge, HeartPulse, MessageCircle, Sparkles, Target, Users } from "lucide-react";
import BeeShell, { type BeeContext } from "./BeeShell";
import type { ManagerHomeData } from "../../features/manager-home/service";
import { appPath } from "../../lib/app-paths";

const avatarPool = ["/brand/avatars/juliana.png", "/brand/avatars/carlos.png", "/brand/avatars/luiza.png", "/brand/avatars/mariana.png", "/brand/avatars/pedro.png"];
function avatarFor(id: string): string {
  let hash = 0;
  for (let i = 0; i < id.length; i += 1) hash = (hash * 31 + id.charCodeAt(i)) >>> 0;
  return avatarPool[hash % avatarPool.length];
}
function formatDate(value?: string | null): string {
  if (!value) return "Sem data";
  return new Intl.DateTimeFormat("pt-BR", { day: "2-digit", month: "short" }).format(new Date(`${value}T12:00:00`));
}
function average(values: number[]): number | null {
  if (!values.length) return null;
  return values.reduce((sum, value) => sum + value, 0) / values.length;
}

function EmptyState({ children }: { children: string }) {
  return <div className="rounded-2xl border border-dashed border-border bg-muted/30 px-4 py-5 text-sm text-muted-foreground">{children}</div>;
}

function KpiCard({ icon: Icon, label, value, detail }: { icon: typeof Target; label: string; value: string; detail: string }) {
  return (
    <article className="rounded-2xl border border-border bg-card p-5 text-card-foreground shadow-sm">
      <div className="flex items-center justify-between gap-3">
        <p className="text-xs font-bold uppercase tracking-[0.1em] text-muted-foreground">{label}</p>
        <div className="rounded-xl bg-muted p-2 text-muted-foreground"><Icon size={16} /></div>
      </div>
      <p className="mt-3 text-2xl font-extrabold tracking-tight">{value}</p>
      <p className="mt-1 text-xs leading-5 text-muted-foreground">{detail}</p>
    </article>
  );
}

/**
 * Real, permission-scoped "Gestor" content: KPIs, team roster, check-ins and
 * feedbacks are all read from the same organization-scoped data the caller
 * already fetched (Dashboard.tsx's loadData, or readManagerHomeData for the
 * standalone /executive route). No mock data, no fabricated actions.
 */
export type GestorHomeBodyProps = { data: ManagerHomeData | null; loading: boolean; onOpenTeam?: () => void };

export function GestorHomeBody({ data, loading, onOpenTeam }: GestorHomeBodyProps) {
  const employeeNames = new Map((data?.team ?? []).map((employee) => [employee.id, employee.full_name]));
  const areaNames = new Map((data?.areas ?? []).map((area) => [area.id, area.name]));
  const positionNames = new Map((data?.positions ?? []).map((position) => [position.id, position.name]));
  const teamSize = data?.team.length ?? 0;

  const engagementAvg = average((data?.checkins ?? []).map((item) => item.engagement));
  const workloadHighCount = new Set((data?.checkins ?? []).filter((item) => item.workload >= 4).map((item) => item.employee_id)).size;
  const activePdiCount = (data?.pdis ?? []).filter((pdi) => pdi.status !== "completed" && pdi.status !== "cancelled").length;

  const latestCheckinByEmployee = new Map<string, NonNullable<typeof data>["checkins"][number]>();
  for (const checkin of data?.checkins ?? []) if (!latestCheckinByEmployee.has(checkin.employee_id)) latestCheckinByEmployee.set(checkin.employee_id, checkin);

  const peopleAtAttention = [...latestCheckinByEmployee.entries()]
    .filter(([, checkin]) => checkin.mood <= 2 || checkin.engagement <= 2 || checkin.workload >= 4)
    .map(([employeeId, checkin]) => ({ employeeId, checkin }))
    .slice(0, 5);

  const recentCheckins = (data?.checkins ?? []).slice(0, 5);
  const recentFeedbacks = (data?.feedbacks ?? []).slice(0, 4);

  if (loading) return <div className="rounded-2xl border border-border bg-card p-10 text-center text-sm text-muted-foreground">Carregando os dados do seu time...</div>;
  if (!data || teamSize === 0) return <EmptyState>Nenhum colaborador está vinculado a você como gestor direto. Assim que a estrutura for cadastrada, seu time aparecerá aqui.</EmptyState>;

  return (
    <div className="space-y-6">
      <section className="grid gap-4 sm:grid-cols-3">
        <KpiCard icon={Gauge} label="Engajamento do time" value={engagementAvg != null ? `${engagementAvg.toFixed(1)}/5` : "—"} detail={engagementAvg != null ? "Média dos check-ins registrados." : "Sem check-ins registrados ainda."} />
        <KpiCard icon={AlertTriangle} label="Risco de sobrecarga" value={String(workloadHighCount)} detail={workloadHighCount > 0 ? "pessoa(s) com carga alta no último check-in." : "Nenhum sinal de sobrecarga nos check-ins registrados."} />
        <KpiCard icon={Target} label="Desenvolvimento em andamento" value={String(activePdiCount)} detail={activePdiCount > 0 ? "PDI(s) ativo(s) no seu time." : "Nenhum PDI ativo registrado para o time."} />
      </section>

      <section className="rounded-3xl border border-border bg-card p-6 shadow-sm">
        <div className="mb-5 flex flex-wrap items-end justify-between gap-4">
          <div className="flex items-center gap-3">
            <div className="rounded-2xl bg-muted p-2.5 text-muted-foreground"><Users size={19} /></div>
            <div>
              <p className="text-xs font-bold uppercase tracking-[0.12em] text-muted-foreground">Meu time em foco</p>
              <h2 className="mt-1 text-xl font-bold">{teamSize} pessoa{teamSize === 1 ? "" : "s"} no seu time</h2>
            </div>
          </div>
          {onOpenTeam ? (
            <button type="button" onClick={onOpenTeam} className="inline-flex items-center gap-1 rounded-full border border-border px-3 py-2 text-xs font-bold text-muted-foreground hover:bg-muted">Abrir equipe completa <ArrowRight size={13} /></button>
          ) : (
            <a href={appPath("/commercial")} className="inline-flex items-center gap-1 rounded-full border border-border px-3 py-2 text-xs font-bold text-muted-foreground hover:bg-muted">Abrir equipe completa <ArrowRight size={13} /></a>
          )}
        </div>
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {data.team.map((employee) => (
            <div key={employee.id} className="flex items-center gap-3 rounded-2xl border border-border bg-background p-3">
              <img src={avatarFor(employee.id)} alt="" className="h-10 w-10 shrink-0 rounded-full border-2 border-white object-cover shadow-sm" onError={(event) => { event.currentTarget.style.display = "none"; }} />
              <div className="min-w-0">
                <p className="truncate text-sm font-bold" title={employee.full_name}>{employee.full_name}</p>
                <p className="truncate text-xs text-muted-foreground">{areaNames.get(employee.area_id ?? "") ?? "Sem área"} · {positionNames.get(employee.position_id ?? "") ?? "Sem cargo"}</p>
              </div>
            </div>
          ))}
        </div>
      </section>

      <div className="grid gap-6 lg:grid-cols-2">
        <section className="rounded-3xl border border-border bg-card p-6 shadow-sm">
          <div className="mb-4 flex items-center gap-3">
            <div className="rounded-2xl bg-muted p-2.5 text-muted-foreground"><HeartPulse size={19} /></div>
            <div>
              <p className="text-xs font-bold uppercase tracking-[0.12em] text-muted-foreground">Clima</p>
              <h2 className="mt-1 text-xl font-bold">Check-ins recentes</h2>
            </div>
          </div>
          {recentCheckins.length ? (
            <div className="space-y-3">
              {recentCheckins.map((checkin) => (
                <div key={checkin.id} className="rounded-2xl border border-border p-4">
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <p className="text-sm font-bold">{employeeNames.get(checkin.employee_id) ?? "Pessoa do time"}</p>
                    <span className="text-xs text-muted-foreground">{formatDate(checkin.checkin_date)}</span>
                  </div>
                  <p className="mt-1 text-xs text-muted-foreground">Clima {checkin.mood}/5 · Engajamento {checkin.engagement}/5 · Energia {checkin.energy}/5 · Carga {checkin.workload}/5</p>
                  {checkin.note && <p className="mt-2 text-sm text-muted-foreground">{checkin.note}</p>}
                </div>
              ))}
            </div>
          ) : (
            <EmptyState>Nenhum check-in registrado para o seu time ainda.</EmptyState>
          )}
        </section>

        <section className="rounded-3xl border border-border bg-card p-6 shadow-sm">
          <div className="mb-4 flex items-center gap-3">
            <div className="rounded-2xl bg-muted p-2.5 text-muted-foreground"><MessageCircle size={19} /></div>
            <div>
              <p className="text-xs font-bold uppercase tracking-[0.12em] text-muted-foreground">Conversas</p>
              <h2 className="mt-1 text-xl font-bold">Feedbacks recentes</h2>
            </div>
          </div>
          {recentFeedbacks.length ? (
            <div className="space-y-3">
              {recentFeedbacks.map((feedback) => (
                <div key={feedback.id} className="rounded-2xl border border-border p-4">
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <p className="text-sm font-bold">{employeeNames.get(feedback.target_employee_id) ?? "Pessoa do time"}</p>
                    <span className="text-xs text-muted-foreground">{formatDate(feedback.created_at.slice(0, 10))}</span>
                  </div>
                  <p className="mt-2 text-sm leading-6 text-muted-foreground">{feedback.content}</p>
                </div>
              ))}
            </div>
          ) : (
            <EmptyState>Nenhum feedback registrado envolvendo o seu time ainda.</EmptyState>
          )}
        </section>
      </div>

      <section className="rounded-3xl border border-border bg-card p-6 shadow-sm">
        <div className="mb-4 flex items-center gap-3">
          <div className="rounded-2xl bg-muted p-2.5 text-muted-foreground"><AlertTriangle size={19} /></div>
          <div>
            <p className="text-xs font-bold uppercase tracking-[0.12em] text-muted-foreground">Sinais do último check-in</p>
            <h2 className="mt-1 text-xl font-bold">Pessoas em atenção</h2>
          </div>
        </div>
        {peopleAtAttention.length ? (
          <div className="grid gap-3 sm:grid-cols-2">
            {peopleAtAttention.map(({ employeeId, checkin }) => (
              <div key={employeeId} className="flex items-center gap-3 rounded-2xl border border-amber-200 bg-amber-50 p-4">
                <img src={avatarFor(employeeId)} alt="" className="h-9 w-9 rounded-full border-2 border-white object-cover shadow-sm" />
                <div className="min-w-0">
                  <p className="truncate text-sm font-bold text-amber-900">{employeeNames.get(employeeId) ?? "Pessoa do time"}</p>
                  <p className="text-xs text-amber-800">Clima {checkin.mood}/5 · Engajamento {checkin.engagement}/5 · Carga {checkin.workload}/5</p>
                </div>
              </div>
            ))}
          </div>
        ) : (
          <EmptyState>Nenhum sinal de atenção nos check-ins mais recentes do seu time.</EmptyState>
        )}
      </section>
    </div>
  );
}

export type GestorHomeProps = { displayName: string; organizationName: string; beeContext: BeeContext; data: ManagerHomeData | null; loading: boolean };

/** Standalone Gestor home (used by the /executive route): header + real team content. */
export default function GestorHome({ displayName, organizationName, beeContext, data, loading }: GestorHomeProps) {
  const teamSize = data?.team.length ?? 0;
  return (
    <main className="min-h-screen bg-background px-5 py-8 text-foreground sm:px-8">
      <div className="mx-auto max-w-7xl space-y-8">
        <header className="rounded-[2rem] bg-primary p-7 text-primary-foreground shadow-lg sm:p-10">
          <div className="flex flex-col gap-7 lg:flex-row lg:items-end lg:justify-between">
            <div>
              <p className="text-xs font-bold uppercase tracking-[0.2em] text-primary-foreground/70">Visão do gestor · {organizationName}</p>
              <h1 className="mt-3 text-3xl font-extrabold tracking-tight sm:text-4xl">Bom dia, {displayName.split(" ")[0]}</h1>
              <p className="mt-3 max-w-2xl text-sm leading-7 text-primary-foreground/80">
                {teamSize > 0 ? `Você está apenas com o seu time: ${teamSize} pessoa${teamSize === 1 ? "" : "s"}.` : "Nenhuma pessoa está vinculada como seu liderado neste momento."}
              </p>
            </div>
            <BeeShell context={beeContext} />
          </div>
        </header>
        <GestorHomeBody data={data} loading={loading} />
        {!loading && data && teamSize > 0 && (
          <section className="rounded-3xl border border-border bg-card p-6 shadow-sm">
            <div className="flex items-center gap-3">
              <div className="rounded-2xl bg-primary p-3 text-primary-foreground"><Sparkles size={21} /></div>
              <div>
                <p className="text-xs font-bold uppercase tracking-[0.14em] text-muted-foreground">Bee · contexto do seu time</p>
                <h2 className="mt-1 text-xl font-bold">Pergunte à Bee sobre seu time</h2>
              </div>
            </div>
            <p className="mt-3 max-w-2xl text-sm leading-6 text-muted-foreground">A Bee responde apenas com o que está autorizado e registrado para o seu escopo de gestor.</p>
          </section>
        )}
      </div>
    </main>
  );
}
