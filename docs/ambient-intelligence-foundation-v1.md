# Ambient Intelligence Foundation V1

This document describes the connector-neutral foundation only. It does not activate provider integrations, background workers, autonomous messaging, LLM inference or graph storage.

## Flow

`authorized sources → normalized observations → organizational events and temporal memory → contextual preparation → reading/evidence/recommendation → human attention and planning → Bee read/prepare → human confirmation/decision → existing intervention/action/outcome → organizational memory`

## Epistemic contract

`system_record`, `machine_observed`, `human_declared`, `machine_inferred`, `human_confirmed` and `human_corrected` are explicit values. A machine inference is never promoted to fact by proximity or UI. Confirmation and correction are append-only review/history records; corrections preserve the original observation.

## New storage contracts

- `ambient_source_registry`: connector-neutral source identity, status, capabilities and non-secret metadata only.
- `ambient_observations`: normalized observation, provenance, time window, sensitivity, confidence, correlation and epistemic kind.
- `ambient_observation_reviews`: confirm/reject/correct history.
- `ambient_user_preferences`: private, user-owned work preferences. Default RLS does not expose them to manager, RH or diretoria.
- `ambient_attention_items`: human-required attention items with `now`, `today`, `week` and `later` horizons plus `confirm`, `review`, `decide`, `converse`, `delegate`, `act` and `monitor` types.
- `ambient_leadership_commitments`: context + impact + priority, not an autonomous task manager.
- `ambient_attention_briefs`: bounded snapshots; a context-insufficient brief must contain no focus or priority.

The existing organizational event catalog is extended with ambient source, observation, attention, commitment and preference events. Existing organizational memory, readings, evidence, recommendations, decisions, interventions, actions, outcomes, Bee Runtime and RLS remain the authoritative layers.

## Safety contract

- No raw transcript, full message/email body, prompt, chain-of-thought, credential or provider token is stored.
- No source/actor spoofing: writes require the authenticated actor and tenant-safe composite links.
- `scope_ref` is descriptive and never replaces RLS.
- Bee does not expand permissions.
- No health or mental-health diagnosis inference.
- No autonomous firing, promotion, discipline or remuneration decision.
- Human attention is capped at three priority items per brief.
- Empty context returns explicit insufficiency; it does not fabricate a plan.
- `valueBeforeInput` suppresses questions when an authorized system record already contains the answer.

## Out of scope for V1

Google/Microsoft OAuth, Gmail/Outlook/Teams/WhatsApp ingestion, meeting recording/transcription, calendar writes, external messages, production voice transcription, schedulers/workers, paid integrations, secrets and hosted activation.
