export type CommercialSourceStatus = "available" | "empty" | "unavailable" | "unauthorized" | "insufficient";

export type CommercialSourceState = {
  status: CommercialSourceStatus;
  reason?: string;
};

export type CommercialSourceStatusMap = Readonly<Record<string, CommercialSourceState>>;

export class CommercialSourceError extends Error {
  readonly sourceStatus: Exclude<CommercialSourceStatus, "available" | "empty">;

  constructor(sourceStatus: Exclude<CommercialSourceStatus, "available" | "empty">, message = "Não foi possível carregar esta fonte.") {
    super(message);
    this.name = "CommercialSourceError";
    this.sourceStatus = sourceStatus;
  }
}

export function sourceStateFromRows<T>(rows: readonly T[]): CommercialSourceState {
  return rows.length ? { status: "available" } : { status: "empty" };
}

export function sourceStateFromError(error: unknown): CommercialSourceState {
  if (error instanceof CommercialSourceError) return { status: error.sourceStatus, reason: error.message };
  return { status: "unavailable", reason: error instanceof Error ? error.message : "Fonte indisponível." };
}

export function sourceStateFromResponse(response: Response): CommercialSourceState {
  if (response.ok) return { status: "available" };
  if (response.status === 401 || response.status === 403) return { status: "unauthorized", reason: "A sessão não possui autorização para esta fonte." };
  return { status: "unavailable", reason: `A fonte respondeu com status ${response.status}.` };
}
