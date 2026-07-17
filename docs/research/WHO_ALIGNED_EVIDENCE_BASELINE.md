# MindPulse AI — WHO-Aligned Evidence Baseline

## Status

This document defines the evidence, safety and governance baseline for
MindPulse AI.

MindPulse is an automated informational wellness-support application.

It is not:

- a mental-health diagnosis system;
- a therapist or counsellor;
- an emergency service;
- a replacement for qualified professional care;
- authorized to contact another person automatically.

---

## Authoritative evidence sources

### World Health Organization

1. Ethics and governance of artificial intelligence for health
   - WHO, 2021
   - https://www.who.int/publications/i/item/9789240029200

2. Regulatory considerations on artificial intelligence for health
   - WHO, 2023
   - https://www.who.int/publications/i/item/9789240078871

3. Ethics and governance of artificial intelligence for health:
   Guidance on large multi-modal models
   - WHO, 2025
   - https://www.who.int/publications/i/item/9789240084759

4. Towards responsible AI for mental health and well-being
   - WHO, 2026
   - https://www.who.int/news/item/20-03-2026-towards-responsible-ai-for-mental-health-and-well-being--experts-chart-a-way-forward

5. Suicide fact sheet
   - WHO, 2025
   - https://www.who.int/news-room/fact-sheets/detail/suicide

6. Guidelines on mental health at work
   - WHO, 2022
   - https://www.who.int/publications/i/item/9789240053052

7. Burn-out as an occupational phenomenon
   - WHO ICD-11 clarification
   - https://www.who.int/standards/classifications/frequently-asked-questions/burn-out-an-occupational-phenomenon

---

## Product intended use

MindPulse supports voluntary wellness self-management through:

- daily self-check-ins;
- wellness scans;
- journals;
- habits;
- recovery activities;
- screen-time aggregates;
- explainable wellness recommendations;
- supportive AI Coach conversations;
- crisis-language safety escalation.

MindPulse must not provide a clinical diagnosis or claim that a user has
depression, anxiety disorder, burnout disorder, suicidal intent or another
health condition.

---

## Burnout terminology decision

WHO defines burnout specifically as an occupational phenomenon caused by
chronic workplace stress that has not been successfully managed.

Therefore:

- general app screens should use "Wellness Strain", "Stress Load" or
  "Work/Study Pressure";
- "Burnout Indicator" may be shown only when the context is clearly
  occupational;
- student or general-life strain must not be labelled clinical burnout;
- existing internal database field names may remain temporarily for backward
  compatibility;
- user-facing wording must be corrected before release.

---

## AI Coach decision

AI Coach is a bounded wellness-support assistant.

It must:

- provide brief and practical support;
- use evidence-conscious wording;
- clearly communicate uncertainty;
- support Bangla and English;
- respect cultural and contextual differences;
- avoid dependency-forming language;
- avoid pretending to have emotions or consciousness;
- avoid diagnosis and treatment claims;
- display a disclaimer;
- provide crisis-referral options when necessary;
- preserve human choice and autonomy.

AI Coach must not:

- describe itself as a therapist;
- guarantee safety or recovery;
- direct medication changes;
- make a clinical diagnosis;
- encourage secrecy or isolation;
- discourage human or professional support;
- contact another person without explicit user action.

---

## Crisis-safety decision

Safety processing must use defence in depth:

1. critical rule-based phrase protection;
2. conservative contextual risk classification;
3. safe response policy;
4. emergency and trusted-support options;
5. follow-up support;
6. privacy-safe event recording;
7. monitoring and review.

Machine learning must never be the only crisis-safety layer.

Critical safety detection must continue working when an optional model is
unavailable.

No automatic call, SMS, email or emergency-contact action is allowed.

---

## Data and privacy decision

The application must apply data minimization.

Requirements:

- obtain meaningful consent;
- collect only required information;
- keep raw sensitive text out of ordinary analytics logs;
- redact crisis excerpts where practical;
- protect tokens, credentials and health-related records;
- document retention and deletion;
- allow users to disable AI analysis;
- avoid unsupported inferences from phone-use data;
- do not treat correlation as causation.

---

## Model release gate

A model cannot be labelled production-ready without:

- documented intended use and prohibited use;
- dataset source and licence;
- privacy and consent basis;
- data dictionary;
- duplicate and leakage checks;
- class-distribution report;
- train, validation and test separation;
- precision, recall and F1 by class;
- confusion matrix;
- calibration assessment;
- subgroup or fairness analysis where supported;
- error analysis;
- model version and dataset version;
- model card;
- human-oversight procedure;
- safety fallback;
- post-release monitoring plan.

High overall accuracy alone is not sufficient.

---

## Human benefit decision

Recommendations should support both personal coping and contextual action.

Depending on the situation, MindPulse may suggest:

- a small recovery activity;
- rest or sleep protection;
- workload reduction;
- speaking with a trusted person;
- discussing workload with a teacher, supervisor or manager;
- seeking qualified professional support;
- accessing urgent local support during immediate danger.

MindPulse must avoid implying that difficult working, studying or social
conditions are solely the user's fault.

---

## Research governance

Every major feature must have:

- an evidence source;
- an intended-use statement;
- a risk assessment;
- privacy considerations;
- safety tests;
- limitations;
- monitoring criteria.

The research baseline must be reviewed whenever major WHO guidance or
relevant high-quality evidence changes.