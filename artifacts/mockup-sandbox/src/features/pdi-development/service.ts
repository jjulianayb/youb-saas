import type { SupabaseSession } from "../../lib/supabase";

const supabaseUrl = (import.meta.env.VITE_SUPABASE_URL as string | undefined)?.replace(/\/$/, "");
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined;

function errorMessage(body: unknown): string {
  if (body && typeof body === "object") {
    const value = body as { message?: string; details?: string; hint?: string };
    return value.message ?? value.details ?? value.hint ?? "Não foi possível atualizar o PDI.";
  }
  return "Não foi possível atualizar o PDI.";
}

export type PdiStatus = "draft" | "proposed" | "active" | "paused" | "completed" | "cancelled";
export type PdiObjectiveStatus = "draft" | "active" | "completed" | "cancelled";
export type PdiActionStatus = "planned" | "in_progress" | "blocked" | "completed" | "cancelled";

export type PdiRpc =
  | "pdi_create"
  | "pdi_propose"
  | "pdi_activate"
  | "pdi_transition"
  | "pdi_add_objective"
  | "pdi_set_objective_status"
  | "pdi_add_action"
  | "pdi_set_action_status"
  | "pdi_add_checkin"
  | "pdi_add_source_link";

export async function pdiRpc<T>(session: SupabaseSession, rpc: PdiRpc, parameters: Record<string, unknown>): Promise<T> {
  if (!supabaseUrl || !supabaseAnonKey) throw new Error("O ambiente ainda não está conectado ao Supabase.");
  const response = await fetch(`${supabaseUrl}/rest/v1/rpc/${rpc}`, {
    method: "POST",
    headers: {
      apikey: supabaseAnonKey,
      Authorization: `Bearer ${session.access_token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(parameters),
  });
  const body = await response.json().catch(() => null);
  if (!response.ok) throw new Error(errorMessage(body));
  return body as T;
}
