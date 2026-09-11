-- Forward-fix contract tests. Everything is rolled back at the end.
BEGIN;

CREATE TEMP TABLE hardening_context (
  organization_id uuid NOT NULL,
  employee_id uuid NOT NULL
);

INSERT INTO hardening_context VALUES (
  'f9000000-0000-0000-0000-000000000001',
  'f9000000-0000-0000-0000-000000000002'
);

INSERT INTO public.organizations(id, name, slug, plan, status)
VALUES (
  'f9000000-0000-0000-0000-000000000001',
  'Signal Status Hardening Test',
  'signal-status-hardening-test',
  'essencial',
  'active'
);

INSERT INTO public.employees(id, organization_id, full_name, status)
VALUES (
  'f9000000-0000-0000-0000-000000000002',
  'f9000000-0000-0000-0000-000000000001',
  'Signal Status Fixture',
  'active'
);

DO $$
DECLARE
  default_expression text;
  constraint_definition text;
BEGIN
  SELECT pg_get_expr(d.adbin, d.adrelid)
    INTO default_expression
  FROM pg_attribute a
  JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
  WHERE a.attrelid = 'public.intelligence_signals'::regclass
    AND a.attname = 'status';

  IF default_expression IS NULL OR default_expression NOT LIKE '%observed%' THEN
    RAISE EXCEPTION 'final status default must be observed, got %', default_expression;
  END IF;

  SELECT pg_get_constraintdef(c.oid)
    INTO constraint_definition
  FROM pg_constraint c
  WHERE c.conname = 'signals_status_v1_check';

  IF constraint_definition IS NULL
     OR constraint_definition NOT LIKE '%observed%'
     OR constraint_definition LIKE '%received%' THEN
    RAISE EXCEPTION 'status constraint contract mismatch: %', constraint_definition;
  END IF;
END
$$;

-- INSERT without status must receive the final default observed.
INSERT INTO public.intelligence_signals(
  organization_id, employee_id, signal_type, source_type
)
SELECT organization_id, employee_id, 'hardening_default_probe', 'test'
FROM hardening_context;

DO $$
BEGIN
  IF (SELECT status FROM public.intelligence_signals WHERE signal_type = 'hardening_default_probe') <> 'observed' THEN
    RAISE EXCEPTION 'INSERT without status did not default to observed';
  END IF;
END
$$;

CREATE OR REPLACE FUNCTION pg_temp.try_signal_status(p_status text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
BEGIN
  INSERT INTO public.intelligence_signals(
    organization_id, employee_id, signal_type, source_type, status
  )
  SELECT organization_id, employee_id, 'hardening_status_' || p_status, 'test', p_status
  FROM hardening_context;
  RETURN true;
EXCEPTION WHEN OTHERS THEN
  RETURN false;
END
$$;

DO $$
DECLARE
  valid_status text;
BEGIN
  FOREACH valid_status IN ARRAY ARRAY['observed','investigating','corroborated','dismissed','resolved'] LOOP
    IF NOT pg_temp.try_signal_status(valid_status) THEN
      RAISE EXCEPTION 'valid status was rejected: %', valid_status;
    END IF;
  END LOOP;

  IF pg_temp.try_signal_status('received') THEN
    RAISE EXCEPTION 'received must remain invalid';
  END IF;
END
$$;

ROLLBACK;
