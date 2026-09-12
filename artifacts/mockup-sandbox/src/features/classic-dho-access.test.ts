import assert from "node:assert/strict";
import test from "node:test";

import {
  EMPTY_UUID,
  classicPopulationMode,
  employeeQueryFilters,
  employeeRelationFilter,
  feedbackRelationFilter,
  relatedQueryFilters,
  type ClassicDhoQueryContext,
} from "./classic-dho-access";

const org = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa";
const user = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb";
const employee = "cccccccc-cccc-cccc-cccc-cccccccccccc";
const directReport = "dddddddd-dddd-dddd-dddd-dddddddddddd";

function context(role: ClassicDhoQueryContext["role"], employeeId: string | null = employee): ClassicDhoQueryContext {
  return { role, organizationId: org, userId: user, employeeId };
}

test("admin, RH and diretoria use the organization population only as a query scope", () => {
  for (const role of ["admin_youb", "rh", "diretoria"] as const) {
    assert.equal(classicPopulationMode(context(role)), "organization");
    assert.equal(employeeQueryFilters(context(role)), "status=eq.active");
    assert.equal(relatedQueryFilters(context(role), "employee_id", [employee]), "");
  }
});

test("manager query is direct-report-only and never falls back to organization", () => {
  assert.equal(classicPopulationMode(context("gestor")), "direct_reports");
  assert.equal(employeeQueryFilters(context("gestor")), `manager_employee_id=eq.${employee}`);
  assert.equal(relatedQueryFilters(context("gestor"), "employee_id", [directReport]), `employee_id=in.(${directReport})`);
  assert.doesNotMatch(employeeQueryFilters(context("gestor")), /area|position|name|email/);
});

test("manager without a valid employee has an empty population", () => {
  const manager = context("gestor", null);
  assert.equal(classicPopulationMode(manager), "empty");
  assert.equal(employeeQueryFilters(manager), `id=eq.${EMPTY_UUID}`);
  assert.equal(relatedQueryFilters(manager, "employee_id", []), `id=eq.${EMPTY_UUID}`);
  assert.equal(feedbackRelationFilter([]), `id=eq.${EMPTY_UUID}`);
});

test("collaborator query resolves by authenticated user and employee id", () => {
  const collaborator = context("colaborador");
  assert.equal(classicPopulationMode(collaborator), "self");
  assert.equal(employeeQueryFilters(collaborator), `auth_user_id=eq.${user}&status=eq.active`);
  assert.equal(employeeRelationFilter("employee_id", [employee]), `employee_id=in.(${employee})`);
});

test("unknown or missing role never receives a permissive query", () => {
  const unknown = context(null);
  assert.equal(classicPopulationMode(unknown), "empty");
  assert.equal(employeeQueryFilters(unknown), `id=eq.${EMPTY_UUID}`);
  assert.equal(relatedQueryFilters(unknown, "subject_employee_id", [employee]), `id=eq.${EMPTY_UUID}`);
});

test("feedback query includes only scoped targets/authors outside organization roles", () => {
  assert.equal(feedbackRelationFilter([employee, directReport]), `or=(target_employee_id.in.(${employee},${directReport}),author_employee_id.in.(${employee},${directReport}))`);
});
