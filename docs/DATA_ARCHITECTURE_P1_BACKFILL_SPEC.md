# Data Architecture 2.0 — P1 Historical Backfill Specification

Status: specification only. No backfill, hosted write, production change or migration is authorized by this document.

## Purpose

Convert history that is already preserved in append-oriented operational audit structures into `organizational_events` and, where deterministic, `organizational_memory_relations`.

The backfill must never invent facts, actor identity, timestamps, provenance or causality. Unknown values remain unknown.

## Sources

| Source | Event families | Relation projection |
|---|---|---|
| `pdi_audit_events` | PDI lifecycle, objective/action/check-in changes | PDI → employee/objective/action; only when the source payload is explicit |
| Feedback 360 snapshots | round activation, participant submission, completed round | feedback/round → employee/competency; never expose confidential peer content |
| Assessment lifecycle and score snapshots | assessment created/submitted/completed, score observations | assessment → employee/competency |
| Decision revisions | decision recorded/revised/approved/effective | decision → recommendation/intervention |
| Organizational Reading revisions | reading created/revised/status changes | reading → explicit sources only |
| Recommendation revisions | recommendation created/revised | recommendation → explicit evidence/reading/hypothesis |
| Evidence Assessment revisions | evidence assessed/revised | assessment → evidence/reading |
| Outcome records | outcome recorded/validated | outcome → intervention/action/evidence |

## Event identity and idempotency

Each generated event requires a deterministic key:

```text
backfill:{source_table}:{source_primary_key}:{source_revision_or_event_key}:{event_type}
```

The backfill must be safe to rerun. Existing events with the same source identity must be skipped, not duplicated.

## Timestamp rules

- `occurred_at`: use the source lifecycle timestamp or revision timestamp.
- `recorded_at`: time the backfill writes the event.
- If the source has no reliable occurrence time, use the source record timestamp only with an explicit `temporal_precision=recorded_only` payload marker.
- Never fabricate a historical date.

## Actor and provenance rules

- Use the source actor only when the source column is authoritative.
- Otherwise use `actor_user_id = null` and payload `actor_unknown=true`.
- `source_type` must identify the source family (`pdi_audit`, `assessment_revision`, `decision_revision`, etc.).
- `source_id` must identify the source row/revision.
- Preserve tenant, sensitivity and context from the source when available.

## Relationship rules

- Build only deterministic relations supported by explicit source IDs.
- Close/open temporal intervals without deleting old intervals.
- Do not infer `led_to` from sequence.
- Do not infer manager, position, area or competency history from a current-state row without an event/snapshot.
- If an interval cannot be reconstructed, emit the event only and leave the relation absent.

## Causality rules

Backfill may preserve:

```text
observed
associated
contribution_supported
causal_validated
```

It may not promote any record to `causal_validated`. Existing `claim_strength` and validation fields are copied as declared source state, never recalculated.

## Execution gates for P1

1. Run only against a local isolated copy.
2. Generate a dry-run count by event family and tenant.
3. Review unknown actor/time/provenance counts.
4. Verify idempotency by running the dry-run twice.
5. Validate tenant isolation and append-only grants.
6. Audit the generated relation intervals for overlap.
7. Obtain explicit approval before any hosted execution.

## Out of scope

- No hosted execution.
- No production execution.
- No UI or dashboard.
- No graph database.
- No embeddings or ML training.
- No cross-client learning.
- No raw conversation or prompt backfill.
