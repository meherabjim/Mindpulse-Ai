# MindPulse AI — Human Companion Phase 1D Adapter Plan

## Goal

Connect existing user-approved services to the `DailyCompanionContext` without changing existing API or database contracts.

## Detected adapter candidates

| Signal | Candidate read methods | Status |
|---|---|---|
| Phone usage | getInsights | Ready |
| Movement | getInsights | Ready |
| Daily check-in | getCheckinHistory, getTodayCheckin | Ready |
| Recovery | getActivePlan, getPlan, listActivities, listActivityLogs, listPlans, listProgress, updatePlanStatus | Ready |

## Required implementation boundaries

- Read a signal only when its companion permission is enabled.
- Catch permission denial, network failure and unsupported-device errors independently.
- Never treat missing data as a healthy or unhealthy score.
- Store only suggestion feedback and approved local preference state during this phase.
- Keep deterministic policy evaluation independent from experimental machine-learning models.

## Planned Phase 1E

Create concrete service adapters, generate a real daily context, and display one companion card on the dashboard with Helpful / Not helpful controls.
