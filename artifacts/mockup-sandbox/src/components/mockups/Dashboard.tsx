import { useCallback, useEffect, useMemo, useState } from "react";
import type { FormEvent, ReactNode } from "react";

import type { SupabaseSession } from "../../lib/supabase";
import { EMPTY_UUID, employeeQueryFilters, feedbackRelationFilter, relatedQueryFilters } from "../../features/classic-dho-access";
import CompetencyCycleAssessment from "./CompetencyCycleAssessment";
import Feedback360Evolution from "./Feedback360Evolution";

type Organization = { id: string; name: string; slug: string };
type UserRole = "admin_youb" | "diretoria" | "rh" | "gestor" | "colaborador";
type View = "overview" | "team" | "employee-history" | "checkins" | "competency-journey" | "feedback-360" | "cycles" | "assessments" | "feedbacks" | "pdis";
type Employee = { id: string; full_name: string; email?: string | null; area_id?: string | null; position_id?: string | null; seniority?: "junior" | "pleno" | "senior" | null; manager_employee_id?: string | null };
type Area = { id: string; name: string };
type Position = { id: string; name: string; level?: string | null };
type Cycle = { id: string; name: string; starts_at?: string | null; ends_at?: string | null; status: string };
type Feedback = { id: string; content: string; visibility: string; created_at: string; target_employee_id: string; author_employee_id?: string | null; };
type Pdi = { id: string; objective: string; status: string; due_date?: string | null; employee_id: string; created_at?: string | null };
type Assessment = { id: string; subject_employee_id: string; cycle_id: string; created_at: string };
type DisciplinaryPolicy = { id: string; name: string; description?: string | null; requires_intermediate_approval: boolean; intermediate_approver_label?: string | null; requires_hr_approval: boolean; active: boolean; sequence_order: number };
type DisciplinaryAction = { id: string; employee_id: string; policy_id?: string | null; action_type: string; reason: string; notes?: string | null; approval_status: "approved" | "pending_intermediate" | "pending_rh" | "rejected"; applied_at: string; created_at: string };
type DisciplinaryApproval = { id: string; action_id: string; approver_type: "facilitador" | "rh"; status: "pending" | "approved" | "rejected"; note?: string | null; reviewed_at?: string | null };
type OrganizationApprover = { id: string; approver_label: string; email: string; active: boolean };
type Checkin = { id: string; employee_id: string; checkin_date: string; mood: number; engagement: number; energy: number; workload: number; note?: string | null; created_at: string };

type DashboardProps = {
  session: SupabaseSession;
  organization: Organization;
  onLogout: () => void;
};

const inputClassName = "mt-1 w-full rounded-xl border border-slate-200 bg-white px-3 py-2.5 text-sm text-slate-900 outline-none transition focus:border-blue-500 focus:ring-4 focus:ring-blue-100";
const buttonClassName = "rounded-xl bg-[#1e3a6e] px-4 py-2.5 text-sm font-bold text-white transition hover:bg-[#152c57] disabled:cursor-not-allowed disabled:opacity-50";
const secondaryButtonClassName = "rounded-xl border border-slate-200 px-4 py-2.5 text-sm font-bold text-slate-700 transition hover:border-blue-300 hover:bg-blue-50";

const supabaseUrl = (import.meta.env.VITE_SUPABASE_URL as string | undefined)?.replace(/\/$/, "");
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined;

function getErrorMessage(body: unknown): string {
  if (body && typeof body === "object") {
    const value = body as { message?: string; details?: string; hint?: string };
    return value.message ?? value.details ?? value.hint ?? "Não foi possível salvar agora.";
  }
  return "Não foi possível salvar agora.";
}

async function apiRequest<T>(session: SupabaseSession, path: string, options: RequestInit = {}): Promise<T> {
  if (!supabaseUrl || !supabaseAnonKey) throw new Error("O ambiente ainda não está conectado ao Supabase.");
  const response = await fetch(`${supabaseUrl}/rest/v1/${path}`, {
    ...options,
    headers: {
      apikey: supabaseAnonKey,
      Authorization: `Bearer ${session.access_token}`,
      "Content-Type": "application/json",
      ...(options.headers ?? {}),
    },
  });
  const body = await response.json().catch(() => null);
  if (!response.ok) throw new Error(getErrorMessage(body));
  return body as T;
}

function localDateValue(): string {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-${String(now.getDate()).padStart(2, "0")}`;
}

function formatDate(value?: string | null): string {
  if (!value) return "Sem data";
  return new Intl.DateTimeFormat("pt-BR", { day: "2-digit", month: "short", year: "numeric" }).format(new Date(`${value}T12:00:00`));
}

function statusLabel(status: string): string {
  return ({ draft: "Rascunho", active: "Ativo", closed: "Encerrado", completed: "Concluído", cancelled: "Cancelado" } as Record<string, string>)[status] ?? status;
}

function approvalStatusLabel(status: string): string {
  return ({ approved: "Aprovada", pending_intermediate: "Aguardando aprovação intermediária", pending_rh: "Aguardando RH", rejected: "Rejeitada" } as Record<string, string>)[status] ?? status;
}

function seniorityLabel(seniority?: string | null): string {
  return ({ junior: "Júnior", pleno: "Pleno", senior: "Sênior" } as Record<string, string>)[seniority ?? ""] ?? "Sem senioridade";
}

function roleLabel(role?: UserRole | null): string {
  return ({ admin_youb: "Administrador", diretoria: "Diretoria", rh: "RH", gestor: "Gestor", colaborador: "Colaborador" } as Record<string, string>)[role ?? ""] ?? "Acesso não identificado";
}

export default function Dashboard({ session, organization, onLogout }: DashboardProps) {
  const [view, setView] = useState<View>("overview");
  const [employees, setEmployees] = useState<Employee[]>([]);
  const [areas, setAreas] = useState<Area[]>([]);
  const [positions, setPositions] = useState<Position[]>([]);
  const [cycles, setCycles] = useState<Cycle[]>([]);
  const [feedbacks, setFeedbacks] = useState<Feedback[]>([]);
  const [pdis, setPdis] = useState<Pdi[]>([]);
  const [assessments, setAssessments] = useState<Assessment[]>([]);
  const [disciplinaryActions, setDisciplinaryActions] = useState<DisciplinaryAction[]>([]);
  const [disciplinaryApprovals, setDisciplinaryApprovals] = useState<DisciplinaryApproval[]>([]);
  const [organizationApprovers, setOrganizationApprovers] = useState<OrganizationApprover[]>([]);
  const [approverLabel, setApproverLabel] = useState("Business Partner");
  const [approverEmail, setApproverEmail] = useState("");
  const [editingApproverId, setEditingApproverId] = useState<string | null>(null);
  const [replacingApproverId, setReplacingApproverId] = useState<string | null>(null);
  const [disciplinaryPolicies, setDisciplinaryPolicies] = useState<DisciplinaryPolicy[]>([]);
  const [checkins, setCheckins] = useState<Checkin[]>([]);
  const [disciplinaryEmployee, setDisciplinaryEmployee] = useState("");
  const [disciplinaryPolicy, setDisciplinaryPolicy] = useState("");
  const [disciplinaryType, setDisciplinaryType] = useState("Orientação formal");
  const [disciplinaryReason, setDisciplinaryReason] = useState("");
  const [disciplinaryNotes, setDisciplinaryNotes] = useState("");
  const [disciplinaryDate, setDisciplinaryDate] = useState(localDateValue());
  const [policyName, setPolicyName] = useState("");
  const [policyDescription, setPolicyDescription] = useState("");
  const [policyRequiresIntermediateApproval, setPolicyRequiresIntermediateApproval] = useState(false);
  const [intermediateApproverLabel, setIntermediateApproverLabel] = useState("Business Partner");
  const [policyRequiresApproval, setPolicyRequiresApproval] = useState(false);
  const [checkinEmployee, setCheckinEmployee] = useState("");
  const [checkinMood, setCheckinMood] = useState("3");
  const [checkinEngagement, setCheckinEngagement] = useState("3");
  const [checkinEnergy, setCheckinEnergy] = useState("3");
  const [checkinWorkload, setCheckinWorkload] = useState("3");
  const [checkinNote, setCheckinNote] = useState("");
  const [userRole, setUserRole] = useState<UserRole | null>(null);
  const [authenticatedEmployeeId, setAuthenticatedEmployeeId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [cycleName, setCycleName] = useState("");
  const [cycleStartsAt, setCycleStartsAt] = useState("");
  const [cycleEndsAt, setCycleEndsAt] = useState("");
  const [employeeName, setEmployeeName] = useState("");
  const [employeeEmail, setEmployeeEmail] = useState("");
  const [employeeArea, setEmployeeArea] = useState("");
  const [employeePosition, setEmployeePosition] = useState("");
  const [employeeSeniority, setEmployeeSeniority] = useState<"" | "junior" | "pleno" | "senior">("");
  const [employeeManager, setEmployeeManager] = useState("");
  const [editingEmployee, setEditingEmployee] = useState<string | null>(null);
  const [historyEmployee, setHistoryEmployee] = useState("");
  const [areaName, setAreaName] = useState("");
  const [positionName, setPositionName] = useState("");
  const [positionLevel, setPositionLevel] = useState("");
  const [feedbackTarget, setFeedbackTarget] = useState("");
  const [feedbackContent, setFeedbackContent] = useState("");
  const [pdiEmployee, setPdiEmployee] = useState("");
  const [pdiObjective, setPdiObjective] = useState("");
  const [pdiDueDate, setPdiDueDate] = useState("");
  const [assessmentEmployee, setAssessmentEmployee] = useState("");
  const [assessmentCycle, setAssessmentCycle] = useState("");

  const loadData = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const org = encodeURIComponent(organization.id);
      const user = encodeURIComponent(session.user.id);
      const membershipRows = await apiRequest<{ role: UserRole }[]>(session, `memberships?select=role&organization_id=eq.${org}&user_id=eq.${user}&limit=1`);
      const role = membershipRows[0]?.role ?? null;
      setUserRole(role);
      const ownEmployeeRows = await apiRequest<Employee[]>(session, `employees?select=id,full_name,email,area_id,position_id,seniority,manager_employee_id&organization_id=eq.${org}&auth_user_id=eq.${user}&limit=2`);
      const ownEmployeeId = ownEmployeeRows.length === 1 ? ownEmployeeRows[0].id : null;
      setAuthenticatedEmployeeId(ownEmployeeId);
      const queryContext = { role, organizationId: organization.id, userId: session.user.id, employeeId: ownEmployeeId };
      const employeeFilters = employeeQueryFilters(queryContext);
      const employeeRows = await apiRequest<Employee[]>(session, `employees?select=id,full_name,email,area_id,position_id,seniority,manager_employee_id&organization_id=eq.${org}&${employeeFilters}&order=full_name`);
      const employeeIds = employeeRows.map((employee) => employee.id);
      const employeeScope = (field: string) => relatedQueryFilters(queryContext, field, employeeIds);
      const hasOrganizationPopulation = role === "admin_youb" || role === "rh";
      const sensitiveScope = hasOrganizationPopulation ? "" : role === "diretoria" ? `id=eq.${EMPTY_UUID}` : employeeScope("employee_id");
      const feedbackScope = hasOrganizationPopulation ? "" : role === "diretoria" ? `id=eq.${EMPTY_UUID}` : feedbackRelationFilter(employeeIds);
      const actionScope = hasOrganizationPopulation ? "" : role === "diretoria" ? `id=eq.${EMPTY_UUID}` : employeeScope("employee_id");
      const assessmentScope = role === "diretoria" ? "" : employeeScope("subject_employee_id");
      const [areaRows, positionRows, cycleRows, feedbackRows, pdiRows, assessmentRows, disciplinaryRows, policyRows, checkinRows, approverRows] = await Promise.all([
        apiRequest<Area[]>(session, `areas?select=id,name&organization_id=eq.${org}&order=name`),
        apiRequest<Position[]>(session, `positions?select=id,name,level&organization_id=eq.${org}&order=name`),
        apiRequest<Cycle[]>(session, `cycles?select=id,name,starts_at,ends_at,status&organization_id=eq.${org}&order=created_at.desc`),
        apiRequest<Feedback[]>(session, `feedbacks?select=id,content,visibility,created_at,target_employee_id,author_employee_id&organization_id=eq.${org}${feedbackScope ? `&${feedbackScope}` : ""}&order=created_at.desc`),
        apiRequest<Pdi[]>(session, `pdis?select=id,objective,status,due_date,employee_id,created_at&organization_id=eq.${org}${sensitiveScope ? `&${sensitiveScope}` : ""}&order=created_at.desc`),
        apiRequest<Assessment[]>(session, `assessments?select=id,subject_employee_id,cycle_id,created_at&organization_id=eq.${org}${assessmentScope ? `&${assessmentScope}` : ""}&order=created_at.desc`),
        apiRequest<DisciplinaryAction[]>(session, `disciplinary_actions?select=id,employee_id,policy_id,action_type,reason,notes,approval_status,applied_at,created_at&organization_id=eq.${org}${actionScope ? `&${actionScope}` : ""}&order=applied_at.desc,created_at.desc`),
        apiRequest<DisciplinaryPolicy[]>(session, `disciplinary_policies?select=id,name,description,requires_intermediate_approval,intermediate_approver_label,requires_hr_approval,active,sequence_order&organization_id=eq.${org}&active=eq.true&order=sequence_order,name`),
        apiRequest<Checkin[]>(session, `checkins?select=id,employee_id,checkin_date,mood,engagement,energy,workload,note,created_at&organization_id=eq.${org}${sensitiveScope ? `&${sensitiveScope}` : ""}&order=checkin_date.desc,created_at.desc&limit=100`),
        apiRequest<OrganizationApprover[]>(session, `organization_approvers?select=id,approver_label,email,active&organization_id=eq.${org}&order=active.desc,approver_label,email`),
      ]);
      setEmployees(employeeRows);
      setAreas(areaRows);
      setPositions(positionRows);
      setCycles(cycleRows);
      setFeedbacks(feedbackRows);
      setPdis(pdiRows);
      setAssessments(assessmentRows);
      setDisciplinaryActions(disciplinaryRows);
      setDisciplinaryApprovals([]);
      setOrganizationApprovers(approverRows);
      setDisciplinaryPolicies(policyRows);
      setCheckins(checkinRows);
      const actionIds = disciplinaryRows.map((action) => action.id);
      const approvalScope = actionIds.length ? `action_id=in.(${actionIds.join(",")})` : "id=eq.00000000-0000-0000-0000-000000000000";
      const approvalRows = await apiRequest<DisciplinaryApproval[]>(session, `disciplinary_action_approvals?select=id,action_id,approver_type,status,note,reviewed_at&organization_id=eq.${org}&${approvalScope}&order=created_at.desc`);
      setDisciplinaryApprovals(approvalRows);
    } catch (loadError) {
      setError(loadError instanceof Error ? loadError.message : "Não foi possível carregar os dados da empresa.");
    } finally {
      setLoading(false);
    }
  }, [organization.id, session]);

  useEffect(() => { void loadData(); }, [loadData]);

  const employeeNames = useMemo(() => new Map(employees.map((employee) => [employee.id, employee.full_name])), [employees]);
  const cycleNames = useMemo(() => new Map(cycles.map((cycle) => [cycle.id, cycle.name])), [cycles]);
  const areaNames = useMemo(() => new Map(areas.map((area) => [area.id, area.name])), [areas]);
  const positionNames = useMemo(() => new Map(positions.map((position) => [position.id, position.name])), [positions]);
  const policyNames = useMemo(() => new Map(disciplinaryPolicies.map((policy) => [policy.id, policy.name])), [disciplinaryPolicies]);
  const activeCycles = cycles.filter((cycle) => cycle.status === "active").length;
  const pendingPdis = pdis.filter((pdi) => pdi.status !== "completed" && pdi.status !== "cancelled").length;
  const firstName = String(session.user.user_metadata?.full_name ?? session.user.email ?? "Time").split(" ")[0];

  function resetMessages() { setNotice(null); setError(null); }

  async function createArea(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); resetMessages(); setSaving(true);
    try {
      await apiRequest(session, "areas", { method: "POST", headers: { Prefer: "return=minimal" }, body: JSON.stringify({ organization_id: organization.id, name: areaName.trim() }) });
      setAreaName(""); setNotice("Área criada."); await loadData();
    } catch (saveError) { setError(saveError instanceof Error ? saveError.message : "Não foi possível criar a área."); } finally { setSaving(false); }
  }

  async function createPosition(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); resetMessages(); setSaving(true);
    try {
      await apiRequest(session, "positions", { method: "POST", headers: { Prefer: "return=minimal" }, body: JSON.stringify({ organization_id: organization.id, name: positionName.trim(), level: positionLevel.trim() || null }) });
      setPositionName(""); setPositionLevel(""); setNotice("Cargo criado."); await loadData();
    } catch (saveError) { setError(saveError instanceof Error ? saveError.message : "Não foi possível criar o cargo."); } finally { setSaving(false); }
  }

  function startEditEmployee(employee: Employee) {
    setEditingEmployee(employee.id); setEmployeeName(employee.full_name); setEmployeeEmail(employee.email ?? ""); setEmployeeArea(employee.area_id ?? ""); setEmployeePosition(employee.position_id ?? ""); setEmployeeSeniority(employee.seniority ?? ""); setEmployeeManager(employee.manager_employee_id ?? ""); resetMessages();
  }

  function cancelEditEmployee() {
    setEditingEmployee(null); setEmployeeName(""); setEmployeeEmail(""); setEmployeeArea(""); setEmployeePosition(""); setEmployeeSeniority(""); setEmployeeManager("");
  }

  async function saveEmployee(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); resetMessages(); setSaving(true);
    try {
      const payload = { full_name: employeeName.trim(), email: employeeEmail.trim() || null, area_id: employeeArea || null, position_id: employeePosition || null, seniority: employeeSeniority || null, manager_employee_id: employeeManager || null };
      if (editingEmployee) {
        await apiRequest(session, `employees?id=eq.${encodeURIComponent(editingEmployee)}&organization_id=eq.${encodeURIComponent(organization.id)}`, { method: "PATCH", headers: { Prefer: "return=minimal" }, body: JSON.stringify(payload) });
        setNotice("Dados do colaborador atualizados.");
      } else {
        await apiRequest(session, "employees", { method: "POST", headers: { Prefer: "return=minimal" }, body: JSON.stringify({ organization_id: organization.id, ...payload, status: "active" }) });
        setNotice("Colaborador adicionado à equipe.");
      }
      cancelEditEmployee(); await loadData();
    } catch (saveError) { setError(saveError instanceof Error ? saveError.message : "Não foi possível salvar o colaborador."); } finally { setSaving(false); }
  }

  async function createCycle(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); resetMessages(); setSaving(true);
    try {
      await apiRequest(session, "cycles", { method: "POST", headers: { Prefer: "return=minimal" }, body: JSON.stringify({ organization_id: organization.id, name: cycleName.trim(), starts_at: cycleStartsAt || null, ends_at: cycleEndsAt || null, status: "draft", cycle_type: "performance" }) });
      setCycleName(""); setCycleStartsAt(""); setCycleEndsAt(""); setNotice("Ciclo criado. Você já pode ativá-lo quando estiver pronto."); await loadData(); setView("cycles");
    } catch (saveError) { setError(saveError instanceof Error ? saveError.message : "Não foi possível criar o ciclo."); } finally { setSaving(false); }
  }

  async function createFeedback(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); resetMessages(); setSaving(true);
    try {
      await apiRequest(session, "feedbacks", { method: "POST", headers: { Prefer: "return=minimal" }, body: JSON.stringify({ organization_id: organization.id, author_employee_id: authenticatedEmployeeId, target_employee_id: feedbackTarget, content: feedbackContent.trim(), visibility: "private" }) });
      setFeedbackTarget(""); setFeedbackContent(""); setNotice("Feedback registrado com segurança."); await loadData(); setView("feedbacks");
    } catch (saveError) { setError(saveError instanceof Error ? saveError.message : "Não foi possível registrar o feedback."); } finally { setSaving(false); }
  }

  async function createPdi(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); resetMessages(); setSaving(true);
    try {
      await apiRequest(session, "pdis", { method: "POST", headers: { Prefer: "return=minimal" }, body: JSON.stringify({ organization_id: organization.id, employee_id: pdiEmployee, objective: pdiObjective.trim(), due_date: pdiDueDate || null, actions: [], status: "draft" }) });
      setPdiEmployee(""); setPdiObjective(""); setPdiDueDate(""); setNotice("PDI criado para acompanhamento."); await loadData(); setView("pdis");
    } catch (saveError) { setError(saveError instanceof Error ? saveError.message : "Não foi possível criar o PDI."); } finally { setSaving(false); }
  }

  async function createAssessment(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); resetMessages(); setSaving(true);
    try {
      await apiRequest(session, "assessments", { method: "POST", headers: { Prefer: "return=minimal" }, body: JSON.stringify({ organization_id: organization.id, subject_employee_id: assessmentEmployee, cycle_id: assessmentCycle, scores: {} }) });
      setAssessmentEmployee(""); setAssessmentCycle(""); setNotice("Avaliação criada e pronta para preenchimento."); await loadData(); setView("assessments");
    } catch (saveError) { setError(saveError instanceof Error ? saveError.message : "Não foi possível criar a avaliação."); } finally { setSaving(false); }
  }

  async function saveOrganizationApprover(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); resetMessages(); setSaving(true);
    try {
      const payload = { organization_id: organization.id, approver_label: approverLabel.trim(), email: approverEmail.trim().toLowerCase(), active: true };
      if (replacingApproverId) {
        await apiRequest(session, "organization_approvers", { method: "POST", headers: { Prefer: "return=minimal" }, body: JSON.stringify(payload) });
        await apiRequest(session, `organization_approvers?id=eq.${encodeURIComponent(replacingApproverId)}&organization_id=eq.${encodeURIComponent(organization.id)}`, { method: "PATCH", headers: { Prefer: "return=minimal" }, body: JSON.stringify({ active: false }) });
        setNotice("Responsável substituído. O histórico anterior foi preservado.");
      } else if (editingApproverId) {
        await apiRequest(session, `organization_approvers?id=eq.${encodeURIComponent(editingApproverId)}&organization_id=eq.${encodeURIComponent(organization.id)}`, { method: "PATCH", headers: { Prefer: "return=minimal" }, body: JSON.stringify({ approver_label: payload.approver_label, email: payload.email }) });
        setNotice("Responsável atualizado sem apagar o histórico.");
      } else {
        await apiRequest(session, "organization_approvers", { method: "POST", headers: { Prefer: "return=minimal" }, body: JSON.stringify(payload) });
        setNotice("Responsável autorizado para aprovações intermediárias.");
      }
      setApproverLabel("Business Partner"); setApproverEmail(""); setEditingApproverId(null); setReplacingApproverId(null); await loadData();
    } catch (saveError) { setError(saveError instanceof Error ? saveError.message : "Não foi possível salvar o responsável."); } finally { setSaving(false); }
  }

  async function deactivateOrganizationApprover(approver: OrganizationApprover) {
    resetMessages(); setSaving(true);
    try {
      await apiRequest(session, `organization_approvers?id=eq.${encodeURIComponent(approver.id)}&organization_id=eq.${encodeURIComponent(organization.id)}`, { method: "PATCH", headers: { Prefer: "return=minimal" }, body: JSON.stringify({ active: false }) });
      setNotice("Responsável desativado. O histórico de aprovações foi mantido."); await loadData();
    } catch (saveError) { setError(saveError instanceof Error ? saveError.message : "Não foi possível desativar o responsável."); } finally { setSaving(false); }
  }

  function editOrganizationApprover(approver: OrganizationApprover) { setEditingApproverId(approver.id); setReplacingApproverId(null); setApproverLabel(approver.approver_label); setApproverEmail(approver.email); resetMessages(); }
  function replaceOrganizationApprover(approver: OrganizationApprover) { setReplacingApproverId(approver.id); setEditingApproverId(null); setApproverLabel(approver.approver_label); setApproverEmail(""); resetMessages(); }

  async function createDisciplinaryPolicy(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); resetMessages(); setSaving(true);
    try {
      await apiRequest(session, "disciplinary_policies", { method: "POST", headers: { Prefer: "return=minimal" }, body: JSON.stringify({ organization_id: organization.id, name: policyName.trim(), description: policyDescription.trim() || null, requires_intermediate_approval: policyRequiresIntermediateApproval, intermediate_approver_label: intermediateApproverLabel.trim() || "Aprovador intermediário", requires_hr_approval: policyRequiresApproval, sequence_order: disciplinaryPolicies.length + 1, active: true }) });
      setPolicyName(""); setPolicyDescription(""); setPolicyRequiresIntermediateApproval(false); setIntermediateApproverLabel("Business Partner"); setPolicyRequiresApproval(false); setNotice("Regra disciplinar adicionada à política da empresa."); await loadData();
    } catch (saveError) { setError(saveError instanceof Error ? saveError.message : "Não foi possível criar a regra disciplinar."); } finally { setSaving(false); }
  }

  async function createDisciplinaryAction(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); resetMessages(); setSaving(true);
    try {
      const selectedPolicy = disciplinaryPolicies.find((policy) => policy.id === disciplinaryPolicy);
      const approvalStatus = selectedPolicy?.requires_intermediate_approval ? "pending_intermediate" : selectedPolicy?.requires_hr_approval ? "pending_rh" : "approved";
      const created = await apiRequest<DisciplinaryAction[]>(session, "disciplinary_actions", { method: "POST", headers: { Prefer: "return=representation" }, body: JSON.stringify({ organization_id: organization.id, employee_id: disciplinaryEmployee, policy_id: disciplinaryPolicy || null, action_type: selectedPolicy?.name ?? disciplinaryType, approval_status: approvalStatus, reason: disciplinaryReason.trim(), notes: disciplinaryNotes.trim() || null, applied_at: disciplinaryDate }) });
      const action = created[0];
      if (action && selectedPolicy) {
        const approvals: Array<Record<string, unknown>> = [];
        if (selectedPolicy.requires_intermediate_approval) approvals.push({ organization_id: organization.id, action_id: action.id, approver_type: "facilitador", status: "pending" });
        if (selectedPolicy.requires_hr_approval) approvals.push({ organization_id: organization.id, action_id: action.id, approver_type: "rh", status: "pending" });
        if (approvals.length) await apiRequest(session, "disciplinary_action_approvals", { method: "POST", headers: { Prefer: "return=minimal" }, body: JSON.stringify(approvals) });
      }
      setDisciplinaryEmployee(""); setDisciplinaryPolicy(""); setDisciplinaryReason(""); setDisciplinaryNotes(""); setNotice(approvalStatus === "approved" ? "Medida disciplinar registrada no histórico." : "Medida registrada e encaminhada para aprovação."); await loadData();
    } catch (saveError) { setError(saveError instanceof Error ? saveError.message : "Não foi possível registrar a medida disciplinar."); } finally { setSaving(false); }
  }

  async function reviewDisciplinaryApproval(approval: DisciplinaryApproval, status: "approved" | "rejected") {
    resetMessages(); setSaving(true);
    try {
      await apiRequest(session, `disciplinary_action_approvals?id=eq.${encodeURIComponent(approval.id)}&organization_id=eq.${encodeURIComponent(organization.id)}`, { method: "PATCH", headers: { Prefer: "return=minimal" }, body: JSON.stringify({ status, reviewed_by: session.user.id, reviewed_at: new Date().toISOString() }) });
      await apiRequest(session, `disciplinary_actions?id=eq.${encodeURIComponent(approval.action_id)}&organization_id=eq.${encodeURIComponent(organization.id)}`, { method: "PATCH", headers: { Prefer: "return=minimal" }, body: JSON.stringify({ approval_status: status === "rejected" ? "rejected" : approval.approver_type === "facilitador" && disciplinaryApprovals.some((item) => item.action_id === approval.action_id && item.approver_type === "rh" && item.status === "pending") ? "pending_rh" : "approved" }) });
      setNotice(status === "approved" ? "Etapa de aprovação concluída." : "Medida devolvida como rejeitada."); await loadData();
    } catch (saveError) { setError(saveError instanceof Error ? saveError.message : "Não foi possível atualizar a aprovação."); } finally { setSaving(false); }
  }

  async function createCheckin(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); resetMessages(); setSaving(true);
    try {
      const today = localDateValue();
      await apiRequest(session, "checkins", { method: "POST", headers: { Prefer: "return=minimal,resolution=merge-duplicates" }, body: JSON.stringify({ organization_id: organization.id, employee_id: checkinEmployee, checkin_date: today, mood: Number(checkinMood), engagement: Number(checkinEngagement), energy: Number(checkinEnergy), workload: Number(checkinWorkload), note: checkinNote.trim() || null }) });
      setCheckinNote(""); setNotice("Check-in salvo. Os indicadores foram atualizados."); await loadData();
    } catch (saveError) { setError(saveError instanceof Error ? saveError.message : "Não foi possível salvar o check-in."); } finally { setSaving(false); }
  }

  const navItems: Array<{ id: View; label: string; icon: string }> = [
    { id: "overview", label: "Visão geral", icon: "⌂" },
    { id: "team", label: "Equipe", icon: "♙" },
    { id: "employee-history", label: "Histórico individual", icon: "▤" },
    { id: "checkins", label: "Clima & check-ins", icon: "♥" },
    { id: "competency-journey", label: "Jornada V1", icon: "◆" },
    { id: "feedback-360", label: "Feedback 360", icon: "◈" },
    { id: "feedbacks", label: "Feedbacks", icon: "↗" },
    { id: "pdis", label: "PDIs", icon: "◎" },
  ];
  const visibleNavItems = navItems.filter((item) => {
    if (!userRole || userRole === "admin_youb" || userRole === "diretoria" || userRole === "rh") return true;
    if (userRole === "gestor") return ["overview", "employee-history", "checkins", "competency-journey", "feedback-360", "feedbacks", "pdis"].includes(item.id);
    return ["overview", "feedback-360"].includes(item.id);
  });
  const canManageStructure = userRole === "admin_youb" || userRole === "rh";
  const canManageAssessments = userRole === "admin_youb" || userRole === "rh" || userRole === "gestor";
  const canManageDevelopment = userRole === "admin_youb" || userRole === "rh" || userRole === "gestor";

  return (
    <main className="min-h-screen bg-[#f5f8fc] text-slate-900">
      <div className="flex min-h-screen flex-col lg:flex-row">
        <aside className="w-full bg-[#102654] p-5 text-white lg:w-64 lg:p-6">
          <div className="flex items-baseline gap-1 px-2"><span className="text-2xl font-light text-white/75">you</span><span className="text-3xl font-extrabold">B</span></div>
          <div className="mt-8 rounded-2xl bg-white/10 p-4"><p className="text-[10px] font-bold uppercase tracking-[0.16em] text-blue-100/70">Empresa</p><p className="mt-1 truncate font-bold">{organization.name}</p><p className="mt-1 truncate text-xs text-blue-100/65">{organization.slug}</p></div>
          <nav className="mt-8 grid grid-cols-2 gap-2 lg:block lg:space-y-1">
            {visibleNavItems.map((item) => <button key={item.id} className={`flex w-full items-center gap-3 rounded-xl px-3 py-3 text-left text-sm font-semibold transition ${view === item.id ? "bg-white text-[#102654]" : "text-blue-100/80 hover:bg-white/10 hover:text-white"}`} onClick={() => { resetMessages(); setView(item.id); }} type="button"><span className="w-5 text-center text-lg">{item.icon}</span>{item.label}</button>)}
          </nav>
          <button className="mt-8 w-full rounded-xl border border-white/20 px-3 py-3 text-left text-sm font-semibold text-blue-100/80 hover:bg-white/10 hover:text-white" onClick={onLogout} type="button">↩ Sair</button>
        </aside>

        <section className="flex-1 p-5 sm:p-8 lg:p-10">
          <header className="mx-auto flex max-w-6xl flex-col justify-between gap-4 sm:flex-row sm:items-center"><div><p className="text-xs font-bold uppercase tracking-[0.16em] text-blue-600">Painel de pessoas</p><h1 className="mt-2 text-3xl font-extrabold tracking-tight">Olá, {firstName}.</h1><p className="mt-1 text-sm text-slate-500">Acompanhe o desenvolvimento da sua equipe em um só lugar.</p></div><div className="rounded-2xl border border-slate-200 bg-white px-4 py-3 text-sm shadow-sm"><span className="text-slate-400">Perfil </span><strong className="text-[#1e3a6e]">{roleLabel(userRole)}</strong><span className="mx-2 text-slate-300">·</span><span className="text-slate-400">Plano </span><strong className="text-[#1e3a6e]">Essencial</strong></div></header>
          <div className="mx-auto mt-8 max-w-6xl">{notice && <div className="mb-5 rounded-xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-800">{notice}</div>}{error && <div className="mb-5 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800">{error}</div>}
            {loading ? <div className="rounded-2xl border border-slate-200 bg-white p-10 text-center text-sm text-slate-500">Carregando os dados da empresa...</div> : <>
              {view === "overview" && <Overview employees={employees} cycles={cycles} feedbacks={feedbacks} pdis={pdis} activeCycles={activeCycles} pendingPdis={pendingPdis} onView={setView} />}
              {view === "competency-journey" && userRole && userRole !== "colaborador" && <CompetencyCycleAssessment session={session} organization={organization} role={userRole} employeeId={authenticatedEmployeeId} />}
              {view === "feedback-360" && userRole && <Feedback360Evolution session={session} organization={organization} role={userRole} employeeId={authenticatedEmployeeId} />}
              {canManageStructure && view === "team" && <ModuleSection title="Equipe" description="Cadastre colaboradores, áreas e cargos para dar contexto aos ciclos e planos.">
                <div className="grid gap-6 xl:grid-cols-[1.3fr_0.7fr]">
                  <form className="rounded-2xl border border-blue-100 bg-blue-50/60 p-5" onSubmit={saveEmployee}><h3 className="font-bold text-slate-800">Adicionar colaborador</h3><div className="mt-4 grid gap-3 sm:grid-cols-2"><label className="text-xs font-bold text-slate-600 sm:col-span-2">Nome completo<input className={inputClassName} value={employeeName} onChange={(event) => setEmployeeName(event.target.value)} placeholder="Ex.: Ana Souza" required /></label><label className="text-xs font-bold text-slate-600">E-mail<input className={inputClassName} type="email" value={employeeEmail} onChange={(event) => setEmployeeEmail(event.target.value)} placeholder="ana@empresa.com" /></label><label className="text-xs font-bold text-slate-600">Área<select className={inputClassName} value={employeeArea} onChange={(event) => setEmployeeArea(event.target.value)}><option value="">Sem área</option>{areas.map((area) => <option key={area.id} value={area.id}>{area.name}</option>)}</select></label><label className="text-xs font-bold text-slate-600">Cargo<select className={inputClassName} value={employeePosition} onChange={(event) => setEmployeePosition(event.target.value)}><option value="">Sem cargo</option>{positions.map((position) => <option key={position.id} value={position.id}>{position.name}</option>)}</select></label><label className="text-xs font-bold text-slate-600">Senioridade<select className={inputClassName} value={employeeSeniority} onChange={(event) => setEmployeeSeniority(event.target.value as "" | "junior" | "pleno" | "senior")}><option value="">Selecione</option><option value="junior">Júnior</option><option value="pleno">Pleno</option><option value="senior">Sênior</option></select></label><label className="text-xs font-bold text-slate-600 sm:col-span-2">Gestor direto<select className={inputClassName} value={employeeManager} onChange={(event) => setEmployeeManager(event.target.value)}><option value="">Sem gestor direto</option>{employees.filter((employee) => employee.id !== editingEmployee).map((employee) => <option key={employee.id} value={employee.id}>{employee.full_name}</option>)}</select><span className="mt-1 block font-normal text-slate-500">Use este campo para montar a hierarquia do organograma.</span></label></div><div className="mt-4 flex flex-wrap gap-2"><button className={buttonClassName} disabled={saving} type="submit">{saving ? "Salvando..." : editingEmployee ? "Salvar alterações" : "+ Adicionar à equipe"}</button>{editingEmployee && <button className={secondaryButtonClassName} onClick={cancelEditEmployee} type="button">Cancelar</button>}</div></form>
                  <div className="space-y-4"><form className="rounded-2xl border border-slate-200 bg-white p-5" onSubmit={createArea}><h3 className="font-bold text-slate-800">Nova área</h3><input className={inputClassName} value={areaName} onChange={(event) => setAreaName(event.target.value)} placeholder="Ex.: Produto" required /><button className={`${secondaryButtonClassName} mt-3`} disabled={saving} type="submit">Criar área</button></form><form className="rounded-2xl border border-slate-200 bg-white p-5" onSubmit={createPosition}><h3 className="font-bold text-slate-800">Novo cargo</h3><input className={inputClassName} value={positionName} onChange={(event) => setPositionName(event.target.value)} placeholder="Ex.: Gerente" required /><input className={inputClassName} value={positionLevel} onChange={(event) => setPositionLevel(event.target.value)} placeholder="Nível (opcional)" /><button className={`${secondaryButtonClassName} mt-3`} disabled={saving} type="submit">Criar cargo</button></form></div>
                </div>
                <div className="mt-6 space-y-3">{employees.length === 0 ? <EmptyState text="Ainda não há colaboradores cadastrados." /> : employees.map((employee) => <div className="flex flex-col justify-between gap-3 rounded-2xl border border-slate-200 bg-white p-5 sm:flex-row sm:items-center" key={employee.id}><div><h3 className="font-bold">{employee.full_name}</h3><p className="mt-1 text-sm text-slate-500">{employee.email || "Sem e-mail"} · {areaNames.get(employee.area_id ?? "") ?? "Sem área"} · {positionNames.get(employee.position_id ?? "") ?? "Sem cargo"} · {seniorityLabel(employee.seniority)}</p></div><div className="flex items-center gap-2"><StatusPill status="active" /><button className={secondaryButtonClassName} onClick={() => { setHistoryEmployee(employee.id); resetMessages(); setView("employee-history"); }} type="button">Ver histórico</button><button className={secondaryButtonClassName} onClick={() => startEditEmployee(employee)} type="button">Editar</button></div></div>)}</div>
                <OrgChart employees={employees} areas={areas} areaNames={areaNames} positionNames={positionNames} />
                <div className="mt-8 grid gap-6 xl:grid-cols-[0.8fr_1.2fr]"><form className="rounded-2xl border border-amber-100 bg-amber-50/60 p-5" onSubmit={createDisciplinaryAction}><h3 className="font-bold text-slate-800">Registrar medida disciplinar</h3><p className="mt-1 text-sm text-slate-500">O histórico fica vinculado ao colaborador e visível para RH, diretoria e gestores autorizados.</p><label className="mt-4 block text-xs font-bold text-slate-600">Colaborador<select className={inputClassName} value={disciplinaryEmployee} onChange={(event) => setDisciplinaryEmployee(event.target.value)} required><option value="">Selecione</option>{employees.map((employee) => <option key={employee.id} value={employee.id}>{employee.full_name}</option>)}</select></label><label className="mt-3 block text-xs font-bold text-slate-600">Regra da empresa<select className={inputClassName} value={disciplinaryPolicy} onChange={(event) => setDisciplinaryPolicy(event.target.value)}><option value="">Medida avulsa</option>{disciplinaryPolicies.map((policy) => <option key={policy.id} value={policy.id}>{policy.sequence_order} · {policy.name}{policy.requires_hr_approval ? " · requer RH" : ""}</option>)}</select><span className="mt-1 block font-normal text-slate-500">As regras são configuradas pela empresa abaixo.</span></label><label className="mt-3 block text-xs font-bold text-slate-600">Tipo da medida<select className={inputClassName} value={disciplinaryType} onChange={(event) => setDisciplinaryType(event.target.value)}><option>Orientação formal</option><option>Advertência verbal</option><option>Advertência escrita</option><option>Suspensão</option><option>Plano de melhoria</option><option>Outro</option></select></label><label className="mt-3 block text-xs font-bold text-slate-600">Data<input className={inputClassName} type="date" value={disciplinaryDate} onChange={(event) => setDisciplinaryDate(event.target.value)} required /></label><label className="mt-3 block text-xs font-bold text-slate-600">Motivo e regra aplicada<textarea className={inputClassName} rows={3} value={disciplinaryReason} onChange={(event) => setDisciplinaryReason(event.target.value)} placeholder="Descreva o fato e a regra interna relacionada." required /></label><label className="mt-3 block text-xs font-bold text-slate-600">Observações<textarea className={inputClassName} rows={2} value={disciplinaryNotes} onChange={(event) => setDisciplinaryNotes(event.target.value)} placeholder="Acordos, prazo de acompanhamento ou próximos passos" /></label><button className={`${buttonClassName} mt-4`} disabled={saving} type="submit">{saving ? "Salvando..." : "Registrar no histórico"}</button></form><div className="rounded-2xl border border-slate-200 bg-white p-5"><h3 className="font-bold text-slate-800">Histórico disciplinar</h3><p className="mt-1 text-sm text-slate-500">Registro cronológico por colaborador.</p><div className="mt-4 space-y-3">{disciplinaryActions.length === 0 ? <EmptyState text="Nenhuma medida registrada." /> : disciplinaryActions.map((action) => <div className="rounded-xl border border-slate-200 p-4" key={action.id}><div className="flex flex-wrap items-center justify-between gap-2"><div><p className="font-bold">{employeeNames.get(action.employee_id) ?? "Colaborador"}</p><p className="mt-1 text-xs text-amber-700">{action.action_type} · {formatDate(action.applied_at)}</p><span className={`mt-2 inline-flex rounded-full px-2 py-1 text-[11px] font-bold ${action.approval_status === "approved" ? "bg-emerald-50 text-emerald-700" : action.approval_status === "rejected" ? "bg-red-50 text-red-700" : "bg-amber-50 text-amber-700"}`}>{approvalStatusLabel(action.approval_status)}</span></div><span className="text-xs text-slate-400">Histórico</span></div>{disciplinaryApprovals.filter((approval) => approval.action_id === action.id).map((approval) => <div className="mt-3 rounded-lg bg-slate-50 p-3 text-xs"><div className="flex flex-wrap items-center justify-between gap-2"><span className="font-semibold">{approval.approver_type === "facilitador" ? "Aprovação intermediária" : "Aprovação do RH"}: {approval.status === "pending" ? "Pendente" : approval.status === "approved" ? "Aprovada" : "Rejeitada"}</span>{approval.status === "pending" && <div className="flex gap-2"><button className="rounded-lg bg-emerald-600 px-2 py-1 font-bold text-white hover:bg-emerald-700 disabled:opacity-50" disabled={saving} onClick={() => void reviewDisciplinaryApproval(approval, "approved")} type="button">Aprovar</button><button className="rounded-lg border border-red-200 px-2 py-1 font-bold text-red-700 hover:bg-red-50 disabled:opacity-50" disabled={saving} onClick={() => void reviewDisciplinaryApproval(approval, "rejected")} type="button">Rejeitar</button></div>}</div>{approval.reviewed_at && <p className="mt-1 text-slate-500">Revisada em {formatDate(approval.reviewed_at.slice(0, 10))}</p>}</div>)}<p className="mt-3 text-sm text-slate-600">{action.reason}</p>{action.notes && <p className="mt-2 text-xs text-slate-500">Observações: {action.notes}</p>}</div>)}</div></div></div><div className="mt-6 grid gap-6 xl:grid-cols-[0.8fr_1.2fr]"><form className="rounded-2xl border border-violet-100 bg-violet-50/60 p-5" onSubmit={createDisciplinaryPolicy}><h3 className="font-bold text-slate-800">Políticas da empresa</h3><p className="mt-1 text-sm text-slate-500">Configure a sequência de medidas e defina quando o RH precisa revisar.</p><label className="mt-4 block text-xs font-bold text-slate-600">Nome da regra<input className={inputClassName} value={policyName} onChange={(event) => setPolicyName(event.target.value)} placeholder="Ex.: 1ª ocorrência — orientação formal" required /></label><label className="mt-3 block text-xs font-bold text-slate-600">Descrição<textarea className={inputClassName} rows={2} value={policyDescription} onChange={(event) => setPolicyDescription(event.target.value)} placeholder="Quando esta regra deve ser aplicada?" /></label><div className="mt-3 space-y-2"><label className="flex items-center gap-2 text-sm font-semibold text-slate-700"><input type="checkbox" checked={policyRequiresIntermediateApproval} onChange={(event) => setPolicyRequiresIntermediateApproval(event.target.checked)} /> Exigir aprovação intermediária</label><label className="mt-3 block text-xs font-bold text-slate-600">Nome da função aprovadora<input className={inputClassName} value={intermediateApproverLabel} onChange={(event) => setIntermediateApproverLabel(event.target.value)} placeholder="Ex.: Business Partner, facilitador, comitê" /><span className="mt-1 block font-normal text-slate-500">Esse nome aparece no fluxo e no histórico.</span></label><label className="flex items-center gap-2 text-sm font-semibold text-slate-700"><input type="checkbox" checked={policyRequiresApproval} onChange={(event) => setPolicyRequiresApproval(event.target.checked)} /> Exigir aprovação do RH</label><p className="text-xs font-normal text-slate-500">A etapa intermediária é opcional. Quando marcada, a sequência fica: líder → função intermediária → RH.</p></div><button className={`${buttonClassName} mt-4`} disabled={saving} type="submit">{saving ? "Salvando..." : "Adicionar regra"}</button></form><div className="rounded-2xl border border-slate-200 bg-white p-5"><h3 className="font-bold text-slate-800">Sequência configurada</h3><p className="mt-1 text-sm text-slate-500">As regras ativas aparecem no registro de medidas.</p><div className="mt-4 space-y-3">{disciplinaryPolicies.length === 0 ? <EmptyState text="Nenhuma regra configurada ainda." /> : disciplinaryPolicies.map((policy) => <div className="rounded-xl border border-slate-200 p-4" key={policy.id}><div className="flex items-center justify-between gap-3"><div><p className="font-bold">{policy.sequence_order}. {policy.name}</p>{policy.description && <p className="mt-1 text-sm text-slate-600">{policy.description}</p>}</div><div className="flex flex-wrap justify-end gap-1">{policy.requires_intermediate_approval && <span className="rounded-full bg-blue-50 px-2 py-1 text-[11px] font-bold text-blue-700">{policy.intermediate_approver_label ?? "Intermediário"}</span>}{policy.requires_hr_approval && <span className="rounded-full bg-violet-50 px-2 py-1 text-[11px] font-bold text-violet-700">RH</span>}</div></div></div>)}</div></div></div><div className="mt-6 grid gap-6 xl:grid-cols-[0.8fr_1.2fr]"><form className="rounded-2xl border border-emerald-100 bg-emerald-50/60 p-5" onSubmit={saveOrganizationApprover}><h3 className="font-bold text-slate-800">Responsáveis pelas aprovações</h3><p className="mt-1 text-sm text-slate-500">Cadastre o e-mail das pessoas autorizadas na etapa intermediária.</p><label className="mt-4 block text-xs font-bold text-slate-600">Nome da função<input className={inputClassName} value={approverLabel} onChange={(event) => setApproverLabel(event.target.value)} placeholder="Ex.: Business Partner" required /></label><label className="mt-3 block text-xs font-bold text-slate-600">E-mail do responsável<input className={inputClassName} type="email" value={approverEmail} onChange={(event) => setApproverEmail(event.target.value)} placeholder="E-mail corporativo" required /></label><div className="mt-4 flex flex-wrap gap-2"><button className={buttonClassName} disabled={saving} type="submit">{saving ? "Salvando..." : replacingApproverId ? "Substituir responsável" : editingApproverId ? "Salvar alterações" : "Autorizar responsável"}</button>{(editingApproverId || replacingApproverId) && <button className={secondaryButtonClassName} onClick={() => { setEditingApproverId(null); setReplacingApproverId(null); setApproverLabel("Business Partner"); setApproverEmail(""); }} type="button">Cancelar</button>}</div></form><div className="rounded-2xl border border-slate-200 bg-white p-5"><h3 className="font-bold text-slate-800">Responsáveis cadastrados</h3><p className="mt-1 text-sm text-slate-500">Somente estes e-mails poderão concluir a aprovação intermediária.</p><div className="mt-4 space-y-3">{organizationApprovers.length === 0 ? <EmptyState text="Nenhum responsável intermediário cadastrado." /> : organizationApprovers.map((approver) => <div className="flex flex-wrap items-center justify-between gap-2 rounded-xl border border-slate-200 p-4" key={approver.id}><div><p className="font-bold">{approver.approver_label}</p><p className="mt-1 text-sm text-slate-500">{approver.email}</p></div><div className="flex flex-wrap items-center justify-end gap-2"><span className={`rounded-full px-2 py-1 text-[11px] font-bold ${approver.active ? "bg-emerald-50 text-emerald-700" : "bg-slate-100 text-slate-500"}`}>{approver.active ? "Ativo" : "Desativado"}</span>{approver.active && <><button className="rounded-lg border border-slate-200 px-2 py-1 text-xs font-bold text-slate-700 hover:bg-slate-50" disabled={saving} onClick={() => editOrganizationApprover(approver)} type="button">Editar</button><button className="rounded-lg border border-amber-200 px-2 py-1 text-xs font-bold text-amber-700 hover:bg-amber-50" disabled={saving} onClick={() => replaceOrganizationApprover(approver)} type="button">Substituir</button><button className="rounded-lg border border-red-200 px-2 py-1 text-xs font-bold text-red-700 hover:bg-red-50" disabled={saving} onClick={() => void deactivateOrganizationApprover(approver)} type="button">Desativar</button></>}</div></div>)}</div></div></div>
              </ModuleSection>}
              {view === "employee-history" && <EmployeeHistory employees={employees} selectedEmployeeId={historyEmployee} onSelectEmployee={setHistoryEmployee} checkins={checkins} feedbacks={feedbacks} pdis={pdis} assessments={assessments} disciplinaryActions={disciplinaryActions} disciplinaryApprovals={disciplinaryApprovals} areaNames={areaNames} positionNames={positionNames} cycleNames={cycleNames} policyNames={policyNames} />}
              {view === "checkins" && <ModuleSection title="Clima & check-ins diários" description="Registre sinais rápidos da equipe e acompanhe clima, energia e engajamento em tempo quase real."><div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4"><MetricCard label="Check-ins recentes" value={checkins.length} /><MetricCard label="Engajamento médio" value={checkins.length ? `${(checkins.reduce((sum, item) => sum + item.engagement, 0) / checkins.length).toFixed(1)}/5` : "—"} /><MetricCard label="Clima médio" value={checkins.length ? `${(checkins.reduce((sum, item) => sum + item.mood, 0) / checkins.length).toFixed(1)}/5` : "—"} /><MetricCard label="Energia média" value={checkins.length ? `${(checkins.reduce((sum, item) => sum + item.energy, 0) / checkins.length).toFixed(1)}/5` : "—"} /></div>{canManageDevelopment && <form className="mt-6 rounded-2xl border border-blue-100 bg-blue-50/60 p-5" onSubmit={createCheckin}><h3 className="font-bold text-slate-800">Novo check-in da equipe</h3><p className="mt-1 text-sm text-slate-500">Faça uma leitura rápida. Se já houver um registro hoje para a pessoa, ele será atualizado.</p><div className="mt-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-4"><label className="text-xs font-bold text-slate-600 lg:col-span-2">Pessoa<select className={inputClassName} value={checkinEmployee} onChange={(event) => setCheckinEmployee(event.target.value)} required><option value="">Selecione</option>{employees.map((employee) => <option key={employee.id} value={employee.id}>{employee.full_name}</option>)}</select></label><RatingSelect label="Clima / humor" value={checkinMood} onChange={setCheckinMood} /><RatingSelect label="Engajamento" value={checkinEngagement} onChange={setCheckinEngagement} /><RatingSelect label="Energia" value={checkinEnergy} onChange={setCheckinEnergy} /><RatingSelect label="Carga de trabalho" value={checkinWorkload} onChange={setCheckinWorkload} /><label className="text-xs font-bold text-slate-600 sm:col-span-2 lg:col-span-4">Observação<textarea className={inputClassName} rows={2} value={checkinNote} onChange={(event) => setCheckinNote(event.target.value)} placeholder="O que merece atenção hoje?" /></label></div><button className={`${buttonClassName} mt-4`} disabled={saving} type="submit">{saving ? "Salvando..." : "Salvar check-in"}</button></form>}<div className="mt-6 rounded-2xl border border-slate-200 bg-white p-5"><h3 className="font-bold text-slate-800">Leituras recentes</h3><div className="mt-4 space-y-3">{checkins.length === 0 ? <EmptyState text="Faça o primeiro check-in para acompanhar o clima." /> : checkins.slice(0, 20).map((item) => <div className="flex flex-col justify-between gap-2 rounded-xl border border-slate-200 p-4 sm:flex-row sm:items-center" key={item.id}><div><p className="font-bold">{employeeNames.get(item.employee_id) ?? "Pessoa da equipe"}</p><p className="mt-1 text-xs text-slate-500">{formatDate(item.checkin_date)} · Clima {item.mood}/5 · Engajamento {item.engagement}/5 · Energia {item.energy}/5 · Carga {item.workload}/5</p>{item.note && <p className="mt-2 text-sm text-slate-600">{item.note}</p>}</div><span className="text-xs font-bold text-blue-700">Check-in</span></div>)}</div></div></ModuleSection>}
              {view === "cycles" && <ModuleSection title="Ciclos de desenvolvimento" description="Organize períodos de avaliação e acompanhamento da equipe.">{canManageStructure && <form className="mb-6 grid gap-3 rounded-2xl border border-blue-100 bg-blue-50/60 p-5 md:grid-cols-4" onSubmit={createCycle}><label className="text-xs font-bold text-slate-600 md:col-span-2">Nome do ciclo<input className={inputClassName} value={cycleName} onChange={(event) => setCycleName(event.target.value)} placeholder="Ex.: Ciclo de desempenho 2026" required /></label><label className="text-xs font-bold text-slate-600">Início<input className={inputClassName} type="date" value={cycleStartsAt} onChange={(event) => setCycleStartsAt(event.target.value)} /></label><label className="text-xs font-bold text-slate-600">Fim<input className={inputClassName} type="date" value={cycleEndsAt} onChange={(event) => setCycleEndsAt(event.target.value)} /></label><button className={`${buttonClassName} md:col-span-4 md:w-fit`} disabled={saving} type="submit">{saving ? "Salvando..." : "+ Criar ciclo"}</button></form>}<div className="space-y-3">{cycles.length === 0 ? <EmptyState text="Ainda não há ciclos criados." /> : cycles.map((cycle) => <div className="flex flex-col justify-between gap-3 rounded-2xl border border-slate-200 bg-white p-5 sm:flex-row sm:items-center" key={cycle.id}><div><h3 className="font-bold">{cycle.name}</h3><p className="mt-1 text-sm text-slate-500">{formatDate(cycle.starts_at)} → {formatDate(cycle.ends_at)}</p></div><StatusPill status={cycle.status} /></div>)}</div></ModuleSection>}
              {view === "assessments" && <ModuleSection title="Avaliações" description="Crie avaliações vinculadas a um ciclo e acompanhe o preenchimento.">{canManageAssessments && <form className="mb-6 grid gap-3 rounded-2xl border border-blue-100 bg-blue-50/60 p-5 md:grid-cols-3" onSubmit={createAssessment}><label className="text-xs font-bold text-slate-600">Pessoa avaliada<select className={inputClassName} value={assessmentEmployee} onChange={(event) => setAssessmentEmployee(event.target.value)} required><option value="">Selecione</option>{employees.map((employee) => <option key={employee.id} value={employee.id}>{employee.full_name}</option>)}</select></label><label className="text-xs font-bold text-slate-600">Ciclo<select className={inputClassName} value={assessmentCycle} onChange={(event) => setAssessmentCycle(event.target.value)} required><option value="">Selecione</option>{cycles.map((cycle) => <option key={cycle.id} value={cycle.id}>{cycle.name}</option>)}</select></label><div className="flex items-end"><button className={buttonClassName} disabled={saving} type="submit">{saving ? "Salvando..." : "+ Nova avaliação"}</button></div></form>}<div className="space-y-3">{assessments.length === 0 ? <EmptyState text="Crie a primeira avaliação da sua equipe." /> : assessments.map((assessment) => <div className="flex flex-col justify-between gap-2 rounded-2xl border border-slate-200 bg-white p-5 sm:flex-row sm:items-center" key={assessment.id}><div><h3 className="font-bold">{employeeNames.get(assessment.subject_employee_id) ?? "Pessoa da equipe"}</h3><p className="mt-1 text-sm text-slate-500">{cycleNames.get(assessment.cycle_id) ?? "Ciclo"} · criada em {formatDate(assessment.created_at.slice(0, 10))}</p></div><StatusPill status="draft" /></div>)}</div></ModuleSection>}
              {view === "feedbacks" && <ModuleSection title="Feedbacks" description="Registre conversas importantes e mantenha uma cultura de desenvolvimento contínuo.">{canManageDevelopment && <form className="mb-6 space-y-3 rounded-2xl border border-blue-100 bg-blue-50/60 p-5" onSubmit={createFeedback}><label className="block text-xs font-bold text-slate-600">Pessoa que receberá o feedback<select className={inputClassName} value={feedbackTarget} onChange={(event) => setFeedbackTarget(event.target.value)} required><option value="">Selecione</option>{employees.map((employee) => <option key={employee.id} value={employee.id}>{employee.full_name}</option>)}</select></label><label className="block text-xs font-bold text-slate-600">Mensagem<textarea className={inputClassName} rows={3} value={feedbackContent} onChange={(event) => setFeedbackContent(event.target.value)} placeholder="Escreva um feedback claro e construtivo..." required /></label><button className={buttonClassName} disabled={saving} type="submit">{saving ? "Salvando..." : "+ Registrar feedback"}</button></form>}<div className="space-y-3">{feedbacks.length === 0 ? <EmptyState text="Nenhum feedback registrado ainda." /> : feedbacks.map((feedback) => <div className="rounded-2xl border border-slate-200 bg-white p-5" key={feedback.id}><div className="flex flex-wrap items-center justify-between gap-2"><h3 className="font-bold">Para {employeeNames.get(feedback.target_employee_id) ?? "pessoa da equipe"}</h3><span className="text-xs text-slate-400">{formatDate(feedback.created_at.slice(0, 10))}</span></div><p className="mt-3 text-sm leading-6 text-slate-600">{feedback.content}</p></div>)}</div></ModuleSection>}
              {view === "pdis" && <ModuleSection title="Planos de desenvolvimento individual" description="Transforme conversas em objetivos e próximos passos acompanháveis.">{canManageDevelopment && <form className="mb-6 grid gap-3 rounded-2xl border border-blue-100 bg-blue-50/60 p-5 md:grid-cols-3" onSubmit={createPdi}><label className="text-xs font-bold text-slate-600">Pessoa<select className={inputClassName} value={pdiEmployee} onChange={(event) => setPdiEmployee(event.target.value)} required><option value="">Selecione</option>{employees.map((employee) => <option key={employee.id} value={employee.id}>{employee.full_name}</option>)}</select></label><label className="text-xs font-bold text-slate-600 md:col-span-2">Objetivo<input className={inputClassName} value={pdiObjective} onChange={(event) => setPdiObjective(event.target.value)} placeholder="Ex.: Desenvolver liderança" required /></label><label className="text-xs font-bold text-slate-600">Prazo<input className={inputClassName} type="date" value={pdiDueDate} onChange={(event) => setPdiDueDate(event.target.value)} /></label><button className={`${buttonClassName} md:col-span-3 md:w-fit`} disabled={saving} type="submit">{saving ? "Salvando..." : "+ Criar PDI"}</button></form>}<div className="space-y-3">{pdis.length === 0 ? <EmptyState text="Nenhum PDI criado ainda." /> : pdis.map((pdi) => <div className="flex flex-col justify-between gap-3 rounded-2xl border border-slate-200 bg-white p-5 sm:flex-row sm:items-center" key={pdi.id}><div><h3 className="font-bold">{pdi.objective}</h3><p className="mt-1 text-sm text-slate-500">{employeeNames.get(pdi.employee_id) ?? "Pessoa da equipe"} · prazo {formatDate(pdi.due_date)}</p></div><StatusPill status={pdi.status} /></div>)}</div></ModuleSection>}
            </>}</div>
        </section>
      </div>
    </main>
  );
}

function MetricCard({ label, value }: { label: string; value: string | number }) { return <div className="rounded-2xl border border-slate-200 bg-white p-5"><p className="text-sm text-slate-500">{label}</p><p className="mt-2 text-2xl font-extrabold text-[#1e3a6e]">{value}</p></div>; }
function RatingSelect({ label, value, onChange }: { label: string; value: string; onChange: (value: string) => void }) { return <label className="text-xs font-bold text-slate-600">{label}<select className={inputClassName} value={value} onChange={(event) => onChange(event.target.value)}>{[1, 2, 3, 4, 5].map((score) => <option key={score} value={score}>{score} — {score === 1 ? "Muito baixo" : score === 2 ? "Baixo" : score === 3 ? "Regular" : score === 4 ? "Bom" : "Excelente"}</option>)}</select></label>; }

function OrgChart({ employees, areas, areaNames, positionNames }: { employees: Employee[]; areas: Area[]; areaNames: Map<string, string>; positionNames: Map<string, string> }) {
  const grouped = areas.map((area) => ({ area, people: employees.filter((employee) => employee.area_id === area.id) })).filter((group) => group.people.length > 0);
  const withoutArea = employees.filter((employee) => !employee.area_id || !areaNames.has(employee.area_id));
  const employeeById = new Map(employees.map((employee) => [employee.id, employee]));

  function renderPerson(person: Employee, areaPeople: Employee[], depth = 0, visited = new Set<string>()): ReactNode {
    if (visited.has(person.id)) return null;
    const nextVisited = new Set(visited).add(person.id);
    const reports = areaPeople.filter((employee) => employee.manager_employee_id === person.id);
    return <div className={depth > 0 ? "ml-4 border-l-2 border-blue-100 pl-3" : ""} key={person.id}><div className="rounded-xl bg-white p-3 shadow-sm"><p className="text-sm font-bold">{person.full_name}</p><p className="mt-1 text-xs text-slate-500">{positionNames.get(person.position_id ?? "") ?? "Cargo não informado"} · {seniorityLabel(person.seniority)}</p>{person.manager_employee_id && employeeById.has(person.manager_employee_id) && depth === 0 && <p className="mt-1 text-[11px] text-slate-400">Reporta a {employeeById.get(person.manager_employee_id)?.full_name}</p>}</div>{reports.length > 0 && <div className="mt-2 space-y-2">{reports.map((report) => renderPerson(report, areaPeople, depth + 1, nextVisited))}</div>}</div>;
  }

  function renderGroup(areaName: string, people: Employee[], key: string, muted = false) {
    const roots = people.filter((person) => !people.some((candidate) => candidate.id === person.manager_employee_id));
    return <div className={`min-w-[240px] flex-1 rounded-2xl border p-4 ${muted ? "border-dashed border-slate-300 bg-slate-50" : "border-blue-100 bg-blue-50/50"}`} key={key}><div className={`border-b pb-3 ${muted ? "border-slate-200" : "border-blue-100"}`}><p className={`text-xs font-bold uppercase tracking-[0.12em] ${muted ? "text-slate-500" : "text-blue-600"}`}>{muted ? "A organizar" : "Setor"}</p><h4 className={`mt-1 font-extrabold ${muted ? "text-slate-700" : "text-[#1e3a6e]"}`}>{areaName}</h4></div><div className="mt-3 space-y-2">{roots.map((person) => renderPerson(person, people))}</div></div>;
  }

  return <div className="mt-8 rounded-2xl border border-slate-200 bg-white p-6"><div className="flex flex-col justify-between gap-2 sm:flex-row sm:items-center"><div><h3 className="text-lg font-bold">Organograma automático</h3><p className="mt-1 text-sm text-slate-500">Setores, cargos e relações de gestão atualizados a cada cadastro.</p></div><span className="rounded-full bg-blue-50 px-3 py-1 text-xs font-bold text-blue-700">Atualizado agora</span></div>{employees.length === 0 ? <EmptyState text="Cadastre pessoas para visualizar o organograma." /> : <div className="mt-6 flex flex-wrap gap-4">{grouped.map((group) => renderGroup(group.area.name, group.people, group.area.id))}{withoutArea.length > 0 && renderGroup("Sem setor", withoutArea, "without-area", true)}</div>}</div>;
}

function EmployeeHistory({ employees, selectedEmployeeId, onSelectEmployee, checkins, feedbacks, pdis, assessments, disciplinaryActions, disciplinaryApprovals, areaNames, positionNames, cycleNames, policyNames }: { employees: Employee[]; selectedEmployeeId: string; onSelectEmployee: (id: string) => void; checkins: Checkin[]; feedbacks: Feedback[]; pdis: Pdi[]; assessments: Assessment[]; disciplinaryActions: DisciplinaryAction[]; disciplinaryApprovals: DisciplinaryApproval[]; areaNames: Map<string, string>; positionNames: Map<string, string>; cycleNames: Map<string, string>; policyNames: Map<string, string> }) {
  const [eventFilter, setEventFilter] = useState("all");
  const [periodFilter, setPeriodFilter] = useState("all");
  const employee = employees.find((item) => item.id === selectedEmployeeId) ?? employees[0];
  if (!employee) return <ModuleSection title="Histórico individual" description="Acompanhe a jornada de cada colaborador em uma visão única."><EmptyState text="Cadastre um colaborador para consultar o histórico individual." /></ModuleSection>;
  const employeeCheckins = checkins.filter((item) => item.employee_id === employee.id);
  const employeeFeedbacks = feedbacks.filter((item) => item.target_employee_id === employee.id);
  const employeePdis = pdis.filter((item) => item.employee_id === employee.id);
  const employeeAssessments = assessments.filter((item) => item.subject_employee_id === employee.id);
  const employeeActions = disciplinaryActions.filter((item) => item.employee_id === employee.id);
  const average = (values: number[]) => values.length ? (values.reduce((sum, value) => sum + value, 0) / values.length).toFixed(1) : "—";
  const timeline = [
    ...employeeCheckins.map((item) => ({ id: `checkin-${item.id}`, type: "checkin", date: item.checkin_date, label: "Check-in diário", title: `Clima ${item.mood}/5 · Engajamento ${item.engagement}/5`, description: item.note ?? "Leitura diária registrada pela liderança.", tone: "blue", meta: `Energia ${item.energy}/5 · Carga ${item.workload}/5` })),
    ...employeeFeedbacks.map((item) => ({ id: `feedback-${item.id}`, type: "feedback", date: item.created_at.slice(0, 10), label: "Feedback", title: "Conversa de desenvolvimento", description: item.content, tone: "emerald", meta: item.visibility === "private" ? "Registro privado" : "Registro compartilhado" })),
    ...employeePdis.map((item) => ({ id: `pdi-${item.id}`, type: "pdi", date: item.created_at?.slice(0, 10) ?? item.due_date ?? "", label: "PDI", title: item.objective, description: item.due_date ? `Prazo: ${formatDate(item.due_date)}` : "Sem prazo definido.", tone: "violet", meta: statusLabel(item.status) })),
    ...employeeAssessments.map((item) => ({ id: `assessment-${item.id}`, type: "assessment", date: item.created_at.slice(0, 10), label: "Avaliação", title: cycleNames.get(item.cycle_id) ?? "Avaliação de desempenho", description: "Avaliação vinculada ao ciclo de desenvolvimento.", tone: "amber", meta: "Registro criado" })),
    ...employeeActions.map((item) => ({ id: `disciplinary-${item.id}`, type: "disciplinary", date: item.applied_at, label: "Medida disciplinar", title: item.action_type, description: item.reason, tone: "red", meta: `${policyNames.get(item.policy_id ?? "") ? `${policyNames.get(item.policy_id ?? "")} · ` : ""}${approvalStatusLabel(item.approval_status)}` })),
  ].sort((left, right) => right.date.localeCompare(left.date));
  const cutoff = periodFilter === "all" ? null : new Date(Date.now() - Number(periodFilter) * 24 * 60 * 60 * 1000);
  const filteredTimeline = timeline.filter((item) => {
    const dateMatches = !cutoff || new Date(`${item.date}T23:59:59`).getTime() >= cutoff.getTime();
    return (eventFilter === "all" || item.type === eventFilter) && dateMatches;
  });
  function printHistory() { window.print(); }
  return <><style>{`@media print { @page { margin: 1.4cm; } body * { visibility: hidden !important; } .print-history, .print-history * { visibility: visible !important; } .print-history { position: absolute; left: 0; top: 0; width: 100%; } .no-print { display: none !important; } }`}</style><div className="print-history"><ModuleSection title="Histórico individual" description="Uma visão contínua de desenvolvimento, clima, conversas, metas, avaliações e medidas disciplinares.">
    <div className="no-print flex flex-col gap-3 rounded-2xl border border-blue-100 bg-blue-50/60 p-5 sm:flex-row sm:items-end sm:justify-between"><label className="block max-w-xl text-xs font-bold text-slate-600">Colaborador<select className={inputClassName} value={employee.id} onChange={(event) => onSelectEmployee(event.target.value)}><option value="">Selecione</option>{employees.map((item) => <option key={item.id} value={item.id}>{item.full_name}</option>)}</select></label><div className="flex flex-wrap items-center gap-3"><p className="text-sm text-slate-500">O histórico é atualizado com os registros da empresa.</p><button className={secondaryButtonClassName} onClick={printHistory} type="button">Exportar / imprimir PDF</button></div></div>
    <div className="mt-6 rounded-2xl border border-slate-200 bg-white p-6"><div className="flex flex-col justify-between gap-4 sm:flex-row sm:items-start"><div><p className="text-xs font-bold uppercase tracking-[0.16em] text-blue-600">Perfil do colaborador</p><h2 className="mt-2 text-2xl font-extrabold">{employee.full_name}</h2><p className="mt-1 text-sm text-slate-500">{areaNames.get(employee.area_id ?? "") ?? "Sem área"} · {positionNames.get(employee.position_id ?? "") ?? "Sem cargo"} · {seniorityLabel(employee.seniority)}</p></div><span className="rounded-full bg-emerald-50 px-3 py-1 text-xs font-bold text-emerald-700">Ativo</span></div><div className="mt-6 grid gap-3 sm:grid-cols-2 lg:grid-cols-5"><HistoryMetric label="Check-ins" value={employeeCheckins.length} /><HistoryMetric label="Engajamento médio" value={`${average(employeeCheckins.map((item) => item.engagement))}/5`} /><HistoryMetric label="Feedbacks" value={employeeFeedbacks.length} /><HistoryMetric label="PDIs" value={employeePdis.length} /><HistoryMetric label="Medidas" value={employeeActions.length} /></div></div>
    <div className="mt-6 grid gap-6 lg:grid-cols-[1.3fr_0.7fr]"><div className="rounded-2xl border border-slate-200 bg-white p-6"><div className="flex items-center justify-between gap-3"><div><h3 className="font-bold">Linha do tempo</h3><p className="mt-1 text-sm text-slate-500">Registros mais recentes primeiro.</p></div><span className="text-xs font-bold text-slate-400">{filteredTimeline.length} de {timeline.length} eventos</span></div><div className="no-print mt-5 grid gap-3 rounded-xl bg-slate-50 p-4 sm:grid-cols-2"><label className="text-xs font-bold text-slate-600">Tipo de evento<select className={inputClassName} value={eventFilter} onChange={(event) => setEventFilter(event.target.value)}><option value="all">Todos os eventos</option><option value="checkin">Check-ins</option><option value="feedback">Feedbacks</option><option value="pdi">PDIs</option><option value="assessment">Avaliações</option><option value="disciplinary">Medidas disciplinares</option></select></label><label className="text-xs font-bold text-slate-600">Período<select className={inputClassName} value={periodFilter} onChange={(event) => setPeriodFilter(event.target.value)}><option value="all">Todo o histórico</option><option value="30">Últimos 30 dias</option><option value="90">Últimos 90 dias</option><option value="365">Último ano</option></select></label></div><div className="mt-5 space-y-4">{filteredTimeline.length === 0 ? <EmptyState text="Ainda não há registros para este colaborador." /> : filteredTimeline.map((item) => <div className="relative flex gap-4 border-l-2 border-slate-100 pl-5" key={item.id}><span className={`absolute -left-[7px] top-1 h-3 w-3 rounded-full bg-${item.tone}-500 ring-4 ring-white`} /><div className="min-w-0 flex-1"><div className="flex flex-wrap items-center justify-between gap-2"><span className={`text-xs font-extrabold uppercase tracking-wide text-${item.tone}-700`}>{item.label}</span><span className="text-xs text-slate-400">{formatDate(item.date)}</span></div><p className="mt-1 font-bold text-slate-800">{item.title}</p><p className="mt-1 whitespace-pre-wrap text-sm leading-6 text-slate-600">{item.description}</p><p className="mt-2 text-xs font-semibold text-slate-400">{item.meta}</p>{item.label === "Medida disciplinar" && <div className="mt-2 space-y-1">{disciplinaryApprovals.filter((approval) => approval.action_id === item.id.replace("disciplinary-", "")).map((approval) => <p className="text-xs text-slate-500" key={approval.id}>{approval.approver_type === "facilitador" ? "Aprovação intermediária" : "RH"}: {approval.status === "pending" ? "Pendente" : approval.status === "approved" ? "Aprovada" : "Rejeitada"}</p>)}</div>}</div></div>)}</div></div><div className="space-y-6"><div className="rounded-2xl border border-slate-200 bg-white p-6"><h3 className="font-bold">Contexto atual</h3><dl className="mt-4 space-y-3 text-sm"><div className="flex justify-between gap-3"><dt className="text-slate-500">Gestor direto</dt><dd className="text-right font-semibold">{employeeNamesForHistory(employees, employee.manager_employee_id)}</dd></div><div className="flex justify-between gap-3"><dt className="text-slate-500">Avaliações</dt><dd className="font-semibold">{employeeAssessments.length}</dd></div><div className="flex justify-between gap-3"><dt className="text-slate-500">Ciclos relacionados</dt><dd className="font-semibold">{new Set(employeeAssessments.map((item) => item.cycle_id)).size}</dd></div></dl></div><div className="rounded-2xl bg-[#102654] p-6 text-white"><p className="text-xs font-bold uppercase tracking-[0.16em] text-blue-100/70">Próximo passo</p><h3 className="mt-3 text-lg font-bold">Use o histórico para preparar a próxima conversa.</h3><p className="mt-2 text-sm leading-6 text-blue-100/80">Combine os sinais de clima, os feedbacks e os objetivos antes de definir novas ações.</p></div></div></div>
  </ModuleSection></div></>;
}

function HistoryMetric({ label, value }: { label: string; value: string | number }) { return <div className="rounded-xl bg-slate-50 p-4"><p className="text-xs text-slate-500">{label}</p><p className="mt-1 text-xl font-extrabold text-slate-800">{value}</p></div>; }
function employeeNamesForHistory(employees: Employee[], id?: string | null): string { return employees.find((employee) => employee.id === id)?.full_name ?? "Não definido"; }

function Overview({ employees, cycles, feedbacks, pdis, activeCycles, pendingPdis, onView }: { employees: Employee[]; cycles: Cycle[]; feedbacks: Feedback[]; pdis: Pdi[]; activeCycles: number; pendingPdis: number; onView: (view: View) => void }) {
  const cards = [{ label: "Pessoas ativas", value: employees.length, view: "overview" as View, tone: "blue" }, { label: "Ciclos ativos", value: activeCycles, view: "cycles" as View, tone: "violet" }, { label: "Feedbacks registrados", value: feedbacks.length, view: "feedbacks" as View, tone: "emerald" }, { label: "PDIs em andamento", value: pendingPdis, view: "pdis" as View, tone: "amber" }];
  return <><div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">{cards.map((card) => <button className="rounded-2xl border border-slate-200 bg-white p-5 text-left shadow-sm transition hover:-translate-y-0.5 hover:shadow-md" key={card.label} onClick={() => onView(card.view)} type="button"><div className={`mb-5 h-2 w-12 rounded-full bg-${card.tone}-500`} /><p className="text-sm text-slate-500">{card.label}</p><p className="mt-2 text-3xl font-extrabold">{card.value}</p></button>)}</div><div className="mt-6 grid gap-6 lg:grid-cols-[1.2fr_0.8fr]"><div className="rounded-2xl border border-slate-200 bg-white p-6"><div className="flex items-center justify-between"><div><h2 className="text-lg font-bold">Próximos ciclos</h2><p className="mt-1 text-sm text-slate-500">Mantenha os rituais de desenvolvimento em dia.</p></div><button className={secondaryButtonClassName} onClick={() => onView("competency-journey")} type="button">Ver ciclos</button></div><div className="mt-5 space-y-3">{cycles.slice(0, 3).map((cycle) => <div className="flex items-center justify-between rounded-xl bg-slate-50 p-4" key={cycle.id}><div><p className="font-semibold">{cycle.name}</p><p className="mt-1 text-xs text-slate-500">{formatDate(cycle.starts_at)} → {formatDate(cycle.ends_at)}</p></div><StatusPill status={cycle.status} /></div>)}{cycles.length === 0 && <EmptyState text="Crie um ciclo para começar." />}</div></div><div className="rounded-2xl bg-gradient-to-br from-[#1e3a6e] to-[#315da0] p-6 text-white"><p className="text-xs font-bold uppercase tracking-[0.16em] text-blue-100/70">Próximo passo</p><h2 className="mt-3 text-xl font-bold">Dê contexto ao desenvolvimento.</h2><p className="mt-3 text-sm leading-6 text-blue-100/80">Comece criando um ciclo, registre um feedback ou transforme uma conversa em PDI.</p><div className="mt-6 flex flex-wrap gap-2"><button className="rounded-xl bg-white px-3 py-2 text-xs font-bold text-[#1e3a6e]" onClick={() => onView("competency-journey")} type="button">Criar ciclo</button><button className="rounded-xl border border-white/30 px-3 py-2 text-xs font-bold text-white" onClick={() => onView("pdis")} type="button">Criar PDI</button></div></div></div></>;
}

function ModuleSection({ title, description, children }: { title: string; description: string; children: ReactNode }) { return <div><div className="mb-6"><h2 className="text-2xl font-extrabold">{title}</h2><p className="mt-1 text-sm text-slate-500">{description}</p></div>{children}</div>; }
function EmptyState({ text }: { text: string }) { return <div className="rounded-2xl border border-dashed border-slate-300 bg-white p-8 text-center text-sm text-slate-500">{text}</div>; }
function StatusPill({ status }: { status: string }) { return <span className={`inline-flex rounded-full px-3 py-1 text-xs font-bold ${status === "active" ? "bg-emerald-100 text-emerald-700" : status === "completed" ? "bg-blue-100 text-blue-700" : status === "cancelled" ? "bg-red-100 text-red-700" : "bg-amber-100 text-amber-700"}`}>{statusLabel(status)}</span>; }
