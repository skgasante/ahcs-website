# AHCS Admin SOP

## 1) Create a Staff Account
1. Sign in to the admin dashboard.
2. Open Settings.
3. In Staff Onboarding, enter name, email, role, and position.
4. Review permission checkboxes and publish rights.
5. Generate or set a temporary password.
6. Click Create Staff Account.

Expected result:
- Account is created in auth.
- Profile is created in `staff_profiles`.
- `must_change_password` is set to true.

## 2) First Login Password Reset
1. Staff signs in with temporary password.
2. First-login modal appears.
3. Staff enters and confirms new password.
4. System clears `must_change_password` after success.

## 3) Review Teacher Reports
1. Open Reports section.
2. Use Open/Edit on a submitted report.
3. Move status to Under Review.
4. Add review comment.
5. Set status to Approved or Needs Changes.
6. Archive once finalized.

## 4) Reset Access (Owner Emergency Only)
Use backend endpoints with owner superadmin credentials:
- Unlock account flags:
  - `POST /api/admin/emergency/unlock-account`
  - Body: `{ "targetUserId": "...", "reason": "..." }`
- Repair role:
  - `POST /api/admin/emergency/repair-role`
  - Body: `{ "targetUserId": "...", "role": "staff|admin|superadmin", "reason": "..." }`

## 5) Audit Review
1. Filter `audit_logs` by `action`, `target_type`, and date.
2. Confirm who changed roles, permissions, report statuses, and staff records.
3. Escalate unexpected changes immediately.

## 6) Quick Troubleshooting
- If staff cannot open sections: verify `staff_profiles.role`, `position_id`, and permission overrides.
- If publish fails: verify `can_publish` rights for user/position/role.
- If reports save fails: verify status transitions and reviewer permissions.
- If dashboard data is missing: recheck Supabase RLS policies from `backend/database-setup.sql`.
