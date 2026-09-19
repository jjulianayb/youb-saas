alter function public.intelligence_decision_snapshot(public.intelligence_decisions) set search_path = pg_catalog, public, pg_temp;
alter function public.organizational_reading_snapshot(public.intelligence_organizational_readings) set search_path = pg_catalog, public, pg_temp;
alter function public._evidence_assessment_snapshot(public.intelligence_evidence_assessments) set search_path = pg_catalog, public, pg_temp;
alter function public._recommendation_snapshot(public.intelligence_recommendations) set search_path = pg_catalog, public, pg_temp;
