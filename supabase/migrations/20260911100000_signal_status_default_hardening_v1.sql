-- Commercial V1 hardening: align the intelligence signal default with the
-- already-approved signals_status_v1_check constraint without changing it.
DO $$
DECLARE
  constraint_definition text;
BEGIN
  SELECT pg_get_constraintdef(c.oid)
    INTO constraint_definition
  FROM pg_constraint c
  JOIN pg_class t ON t.oid = c.conrelid
  JOIN pg_namespace n ON n.oid = t.relnamespace
  WHERE c.conname = 'signals_status_v1_check'
    AND n.nspname = 'public'
    AND t.relname = 'intelligence_signals';

  IF constraint_definition IS NULL THEN
    RAISE EXCEPTION 'signals_status_v1_check is missing';
  END IF;

  IF constraint_definition NOT LIKE '%observed%' THEN
    RAISE EXCEPTION 'signals_status_v1_check must accept observed: %', constraint_definition;
  END IF;

  IF constraint_definition LIKE '%received%' THEN
    RAISE EXCEPTION 'signals_status_v1_check must not accept received: %', constraint_definition;
  END IF;
END
$$;

ALTER TABLE public.intelligence_signals
  ALTER COLUMN status SET DEFAULT 'observed';
