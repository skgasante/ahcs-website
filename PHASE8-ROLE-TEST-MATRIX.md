# Phase 8 Role-Based Scenario Test Matrix

## Test Accounts
- Owner Superadmin: full access and emergency controls.
- Admin Reviewer: review/approve reports, manage operational modules.
- Staff Teacher: draft/submit reports, no approval/review rights.

## Setup Checklist
- [ ] Apply latest SQL in backend/database-setup.sql.
- [ ] Ensure admin_profiles and staff_profiles rows exist for each test user.
- [ ] Assign one teacher to a staff_positions role with reports.submit=true and reports.review=false.
- [ ] Ensure admin account has reports.review=true and reports.approve=true.
- [ ] Verify can_publish flags align with expected scenario permissions.

## Scenario A: Navigation and UI Authorization
1. Sign in as Staff Teacher.
2. Confirm visible tabs include Reports and exclude Audit.
3. Confirm restricted actions are hidden/disabled in Settings, Admissions, and Jobs.
4. Sign in as Admin Reviewer.
5. Confirm Audit tab is visible.
6. Confirm staff onboarding is shown only when settings.manage_staff=true.

Pass criteria:
- Unauthorized sections are hidden.
- Forbidden actions cannot be triggered from UI controls.

## Scenario B: Backend Authorization Mirror (Bypass Attempt)
1. As Staff Teacher, call reports update endpoint trying to set status=approved.
2. As Staff Teacher, call staff creation endpoint /api/staff/create.
3. As Admin Reviewer, call /api/reports and verify all reports are returned.
4. As Staff Teacher, call /api/reports and verify only own reports are returned.

Pass criteria:
- Staff gets 403 for forbidden transitions/actions.
- Admin reviewer can perform allowed review actions.
- Data scope differs correctly by role.

## Scenario C: Reports Workflow State Transitions
1. Staff Teacher creates Draft report.
2. Staff Teacher submits report.
3. Admin Reviewer moves to Under Review and adds review comment.
4. Admin Reviewer sets Needs Changes.
5. Staff Teacher updates content and re-submits.
6. Admin Reviewer approves.
7. Admin Reviewer archives.

Pass criteria:
- Allowed path: Draft -> Submitted -> Under Review -> Needs Changes -> Submitted -> Under Review -> Approved -> Archived.
- Disallowed shortcuts (e.g., Draft -> Approved by teacher) return 403.

## Scenario D: First Login Password Reset
1. Admin creates a new staff account with temporary password.
2. New staff signs in.
3. Confirm first-login modal forces password update.
4. Confirm user cannot proceed without successful password change.
5. Confirm must_change_password is cleared after completion.

Pass criteria:
- Password reset is mandatory and enforced at first login.

## Scenario E: Audit Logging Coverage
1. Create staff account.
2. Update report statuses across review flow.
3. Execute owner emergency endpoint once in test mode.
4. Open Audit tab as admin/superadmin.
5. Validate rows include actor, action, target, details, and timestamp.

Expected actions:
- staff.created
- report.created
- report.updated
- emergency.unlock_account (if tested)
- emergency.repair_role (if tested)

Pass criteria:
- All critical actions are logged with correct actor and target context.

## Scenario F: Owner Emergency Controls
1. Authenticate as non-owner admin and call emergency endpoints.
2. Expect 403.
3. Authenticate as owner superadmin and call emergency endpoints.
4. Expect success and matching audit events.

Pass criteria:
- Endpoints are owner-only.
- Recovery actions work for valid payloads.

## Recommended Evidence to Capture
- Screenshots for each role's visible tabs.
- API response snippets for allowed/denied calls.
- Before/after rows from teacher_reports and audit_logs.
- Timestamped checklist completion notes.

## Exit Criteria for Handover
- [ ] All scenarios passed.
- [ ] Any failures triaged and fixed.
- [ ] SOP verified against actual workflow.
- [ ] Sign-off from owner superadmin.
