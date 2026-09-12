export type ClassicDhoRole = "admin_youb" | "diretoria" | "rh" | "gestor" | "colaborador";

export type ClassicDhoQueryContext = {
  role: ClassicDhoRole | null;
  organizationId: string;
  userId: string;
  employeeId: string | null;
};

export const EMPTY_UUID = "00000000-0000-0000-0000-000000000000";

function encoded(value: string): string {
  return encodeURIComponent(value);
}

export function classicPopulationMode(context: ClassicDhoQueryContext): "organization" | "direct_reports" | "self" | "empty" {
  if (context.role === "admin_youb" || context.role === "rh" || context.role === "diretoria") return "organization";
  if (context.role === "gestor") return context.employeeId ? "direct_reports" : "empty";
  if (context.role === "colaborador") return context.employeeId ? "self" : "empty";
  return "empty";
}

export function employeeQueryFilters(context: ClassicDhoQueryContext): string {
  switch (classicPopulationMode(context)) {
    case "organization":
      return "status=eq.active";
    case "direct_reports":
      return `manager_employee_id=eq.${encoded(context.employeeId!)}`;
    case "self":
      return `auth_user_id=eq.${encoded(context.userId)}&status=eq.active`;
    case "empty":
      return `id=eq.${EMPTY_UUID}`;
  }
}

export function employeeRelationFilter(field: string, employeeIds: readonly string[]): string {
  if (employeeIds.length === 0) return `id=eq.${EMPTY_UUID}`;
  return `${field}=in.(${employeeIds.map(encoded).join(",")})`;
}

export function feedbackRelationFilter(employeeIds: readonly string[]): string {
  if (employeeIds.length === 0) return `id=eq.${EMPTY_UUID}`;
  const ids = employeeIds.map(encoded).join(",");
  return `or=(target_employee_id.in.(${ids}),author_employee_id.in.(${ids}))`;
}

export function relatedQueryFilters(context: ClassicDhoQueryContext, field: string, employeeIds: readonly string[]): string {
  const mode = classicPopulationMode(context);
  if (mode === "organization") return "";
  if (mode === "direct_reports" || mode === "self") return employeeRelationFilter(field, employeeIds);
  return `id=eq.${EMPTY_UUID}`;
}
