import type { SupabaseSession } from "../../lib/supabase";
import { employeeQueryFilters, relatedQueryFilters, type ClassicDhoQueryContext } from "../classic-dho-access";

const viteEnv = (import.meta as ImportMeta & { env?: Record<string, unknown> }).env ?? {};
const supabaseUrl = (viteEnv.VITE_SUPABASE_URL as string | undefined)?.replace(/\/$/, "");
const supabaseAnonKey = viteEnv.VITE_SUPABASE_ANON_KEY as string | undefined;

export type ManagerTeamEmployee = {
  id: string;
  full_name: string;
  email?: string | null;
  area_id?: string | null;
  position_id?: string | null;
  seniority?: "junior" | "pleno" | "senior" | null;
};
export type ManagerCheckin = {
  id: string;
  employee_id: string;
  checkin_date: string;
  mood: number;
  engagement: number;
  energy: number;
  workload: number;
  note?: string | null;
  created_at: string;
};
export type ManagerFeedback = {
  id: string;
  content: string;
  created_at: string;
  target_employee_id: string;
  author_employee_id?: string | null;
};
export type ManagerPdi = {
  id: string;
  objective: string;
  status: string;
  due_date?: string | null;
  employee_id: string;
};
export type ManagerArea = { id: string; name: string };
export type ManagerPosition = { id: string; name: string };

export type ManagerHomeData = {
  team: ManagerTeamEmployee[];
  areas: ManagerArea[];
  positions: ManagerPosition[];
  checkins: ManagerCheckin[];
  feedbacks: ManagerFeedback[];
  pdis: ManagerPdi[];
};

export type ManagerHomeReadContext = {
  session: SupabaseSession;
  organizationId: string;
  userId: string;
  employeeId: string | null;
};

function requireConfig(): { url: string; key: string } {
  if (!supabaseUrl || !supabaseAnonKey) throw new Error("O ambiente ainda não está conectado ao Supabase.");
  return { url: supabaseUrl, key: supabaseAnonKey };
}
function encode(value: string): string {
  return encodeURIComponent(value);
}
async function readTable<T>(session: SupabaseSession, table: string, select: string, filters: string): Promise<T[]> {
  const { url, key } = requireConfig();
  const response = await fetch(`${url}/rest/v1/${table}?select=${encode(select)}&${filters}`, {
    headers: { apikey: key, Authorization: `Bearer ${session.access_token}` },
  });
  if (!response.ok) throw new Error(`Não foi possível carregar ${table} agora.`);
  return (await response.json()) as T[];
}

/**
 * Reads the real team data a "gestor" (manager) is authorized to see: their direct
 * reports and the check-ins / feedbacks / PDIs linked to those employees. Uses the
 * same RLS-respecting REST reads and scope filters already used by Dashboard.tsx —
 * no new table, RPC or backend logic.
 */
export async function readManagerHomeData(context: ManagerHomeReadContext): Promise<ManagerHomeData> {
  const empty: ManagerHomeData = { team: [], areas: [], positions: [], checkins: [], feedbacks: [], pdis: [] };
  if (!context.employeeId) return empty;
  const org = encode(context.organizationId);
  const queryContext: ClassicDhoQueryContext = { role: "gestor", organizationId: context.organizationId, userId: context.userId, employeeId: context.employeeId };
  const employeeFilters = employeeQueryFilters(queryContext);
  const team = await readTable<ManagerTeamEmployee>(context.session, "employees", "id,full_name,email,area_id,position_id,seniority", `organization_id=eq.${org}&${employeeFilters}&order=full_name`);
  const employeeIds = team.map((employee) => employee.id);
  if (!employeeIds.length) return { ...empty, team };
  const checkinScope = relatedQueryFilters(queryContext, "employee_id", employeeIds);
  const pdiScope = relatedQueryFilters(queryContext, "employee_id", employeeIds);
  const ids = employeeIds.map(encode).join(",");
  const feedbackScope = `or=(target_employee_id.in.(${ids}),author_employee_id.in.(${ids}))`;
  const [areas, positions, checkins, feedbacks, pdis] = await Promise.all([
    readTable<ManagerArea>(context.session, "areas", "id,name", `organization_id=eq.${org}&order=name`),
    readTable<ManagerPosition>(context.session, "positions", "id,name", `organization_id=eq.${org}&order=name`),
    readTable<ManagerCheckin>(context.session, "checkins", "id,employee_id,checkin_date,mood,engagement,energy,workload,note,created_at", `organization_id=eq.${org}&${checkinScope}&order=checkin_date.desc,created_at.desc&limit=60`),
    readTable<ManagerFeedback>(context.session, "feedbacks", "id,content,created_at,target_employee_id,author_employee_id", `organization_id=eq.${org}&${feedbackScope}&order=created_at.desc&limit=20`),
    readTable<ManagerPdi>(context.session, "pdis", "id,objective,status,due_date,employee_id", `organization_id=eq.${org}&${pdiScope}&order=created_at.desc`),
  ]);
  return { team, areas, positions, checkins, feedbacks, pdis };
}
