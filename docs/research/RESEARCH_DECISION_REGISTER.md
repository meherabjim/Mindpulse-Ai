# MindPulse AI — Research Decision Register

## Locked decisions

### RD-001 — Product category

MindPulse is an informational wellness-support product, not a diagnostic or
emergency-care product.

Status: Accepted

### RD-002 — Burnout wording

General-purpose scores will use Wellness Strain or Stress Load wording.
Burnout wording is restricted to a clearly occupational context.

Status: Accepted

### RD-003 — AI Coach scope

AI Coach will use bounded, evidence-conscious supportive responses and will
not be marketed as an AI therapist.

Status: Accepted

### RD-004 — Crisis safety

Rule-based crisis detection remains mandatory even after an ML safety model
is introduced.

Status: Accepted

### RD-005 — Automatic contact

MindPulse will never automatically call, message or email a trusted contact
or emergency service.

Status: Accepted

### RD-006 — Model production status

Existing experimental models remain production_ready=false until the full
model release gate is satisfied.

Status: Accepted

### RD-007 — Sensitive logging

Raw journal or crisis text must not be copied into ordinary AI analysis logs.

Status: Accepted

### RD-008 — Human oversight

Safety events, model limitations and high-risk errors require human-review
procedures before production deployment.

Status: Accepted

### RD-009 — Cultural and linguistic support

Bangla and English behavior must be independently tested. Translation alone
is not sufficient; context and crisis wording must also be evaluated.

Status: Accepted

### RD-010 — Impact monitoring

AI Coach and recommendation features require monitoring for harmful advice,
false reassurance, emotional dependence, bias and unexpected user behavior.

Status: Accepted

---

## Immediate implementation consequences

1. Complete the authenticated AI Coach backend runtime test.
2. Audit existing burnout, stress and mood model artifacts.
3. Correct broad user-facing burnout terminology.
4. Prepare a dataset and model evidence report.
5. Develop Flutter AI Coach only after backend safety verification.
6. Add AI Coach impact, dependency and crisis-referral test cases.
7. Keep all experimental models visibly marked as non-production.