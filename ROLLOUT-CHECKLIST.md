# AHCS Practical Rollout Checklist

## Phase 1: Governance Baseline
- [x] Final roles set to `superadmin`, `admin`, `staff`.
- [x] Permission groups finalized: `admissions`, `jobs`, `news`, `gallery`, `reports`, `settings`.
- [x] Publish authority split by `can_publish` map with role/position/user overrides.
- [x] Strengthened: baseline permission maps persisted in `role_permission_maps`.

## Phase 2: Data Model
- [x] `staff_positions` table (positions + default permission matrix).
- [x] `staff_profiles` table (user profile + position + overrides).
- [x] `role_permission_maps` table (baseline permission map by role).
- [x] `audit_logs` table (status/role/permission/content changes).
- [x] JSON permissions retained for speed (normalization deferred).

## Phase 3: Identity and Onboarding
- [x] Admin/staff manager can create staff from dashboard.
- [x] Temporary password required during onboarding.
- [x] `must_change_password` and password-change completion flow enforced.
- [x] First-login modal forces password reset.

## Phase 4: UI Authorization
- [x] Unauthorized tabs hidden from navigation.
- [x] Blocked actions disabled in forms/tables.
- [x] No-permission states shown in reports section and action guards.

## Phase 5: Backend and RLS Authorization
- [x] Added backend permission resolver and guard middleware.
- [x] Added hard backend controls for staff creation and reports lifecycle.
- [x] Strengthened RLS policies for admissions, jobs, news, vacancies, gallery, reports.

## Phase 6: Teacher Reports Module
- [x] Teacher can create draft and submit reports.
- [x] Admin/reviewer can review and comment.
- [x] Status flow implemented:
  - Draft -> Submitted -> Under Review -> Approved/Needs Changes -> Archived
- [x] Reports UI added in admin dashboard.
- [x] Reports API added: list/create/update with transition checks.

## Phase 7: Auditing and Recovery
- [x] Audit logging for staff creation and report updates.
- [x] Owner-only emergency controls:
  - `POST /api/admin/emergency/unlock-account`
  - `POST /api/admin/emergency/repair-role`

## Phase 8: Stabilization and Handover
- [ ] Test with 2-3 real staff accounts.
- [ ] Run full role-based scenario tests.
- [ ] Confirm RLS behavior directly from Supabase SQL editor/session tests.
- [x] Admin SOP drafted (`ADMIN-SOP.md`).

## Recommended Build Sprint Status
- [x] Positions + permissions + staff creation + first-login reset.
- [x] Reports tab for teachers + review capability for admin.
- [x] Audit logs foundations.
