const express = require('express');
const { supabase } = require('../supabase');
const {
  requireAuth,
  requirePermission,
  logAudit,
} = require('../authz');

const router = express.Router();

const ADMIN_DEFAULT_PREFERENCES = {
  admissions: true,
  jobs: true,
  news: true,
  gallery: true,
};

const ADMIN_DEFAULT_PERMISSIONS = {
  admissions: { view: true, update: true, export: true },
  jobs: { view: true, update: true, export: true, manage_vacancies: true },
  news: { view: true, create: true, edit: true, publish: true, delete: true },
  gallery: { view: true, upload: true, edit: true, publish: true, delete: true },
  reports: { view: true, submit: false, review: true, approve: true },
  settings: { own: true, manage_staff: false, manage_roles: false },
};

const ADMIN_DEFAULT_PUBLISH = {
  news: true,
  gallery: true,
  vacancies: true,
  reports: true,
};

const NON_TEACHING_EMPTY_PERMISSIONS = {
  admissions: { view: false, update: false, export: false },
  jobs: { view: false, update: false, export: false, manage_vacancies: false },
  news: { view: false, create: false, edit: false, publish: false, delete: false },
  gallery: { view: false, upload: false, edit: false, publish: false, delete: false },
  reports: { view: false, submit: false, review: false, approve: false },
  settings: { own: true, manage_staff: false, manage_roles: false },
};

const NON_TEACHING_EMPTY_PUBLISH = {
  news: false,
  gallery: false,
  vacancies: false,
  reports: false,
};

router.post('/create', requireAuth, requirePermission('settings', 'manage_staff', 'Only staff managers can create accounts.'), async (req, res) => {
  try {
    const {
      email,
      displayName,
      positionId,
      role = 'staff',
      accountType = 'teaching',
      temporaryPassword,
      permissionsOverride,
      canPublishOverride,
    } = req.body;
    const safePermissionsOverride = (permissionsOverride && typeof permissionsOverride === 'object' && !Array.isArray(permissionsOverride))
      ? permissionsOverride : null;
    const safeCanPublishOverride = (canPublishOverride && typeof canPublishOverride === 'object' && !Array.isArray(canPublishOverride))
      ? canPublishOverride : null;

    const normalizedEmail = String(email || '').trim().toLowerCase();
    const safeRole = String(role || 'staff').trim().toLowerCase();
    const safeAccountType = String(accountType || 'teaching').trim().toLowerCase();
    const password = String(temporaryPassword || '');

    if (!normalizedEmail || !normalizedEmail.includes('@')) {
      return res.status(400).json({ success: false, message: 'A valid email is required.' });
    }

    if (password.length < 8) {
      return res.status(400).json({ success: false, message: 'Temporary password must be at least 8 characters.' });
    }

    if (!['staff', 'admin'].includes(safeRole)) {
      return res.status(400).json({ success: false, message: 'Invalid staff role.' });
    }

    if (!['teaching', 'non_teaching'].includes(safeAccountType)) {
      return res.status(400).json({ success: false, message: 'Invalid account type.' });
    }

    const resolvedPermissionsOverride = safeRole === 'staff' && safeAccountType === 'non_teaching'
      ? (safePermissionsOverride || NON_TEACHING_EMPTY_PERMISSIONS)
      : safePermissionsOverride;
    const resolvedCanPublishOverride = safeRole === 'staff' && safeAccountType === 'non_teaching'
      ? (safeCanPublishOverride || NON_TEACHING_EMPTY_PUBLISH)
      : safeCanPublishOverride;

    const { data: createdAuth, error: createAuthErr } = await supabase.auth.admin.createUser({
      email: normalizedEmail,
      password,
      email_confirm: true,
      user_metadata: {
        name: String(displayName || '').trim() || null,
      },
    });

    if (createAuthErr || !createdAuth?.user) {
      const msg = createAuthErr?.message || 'Failed to create auth user.';
      return res.status(400).json({ success: false, message: msg });
    }

    const userId = createdAuth.user.id;
    const nowIso = new Date().toISOString();

    const staffProfilePayload = {
      id: userId,
      email: normalizedEmail,
      display_name: String(displayName || '').trim() || null,
      role: safeRole,
      staff_type: safeRole === 'staff' ? safeAccountType : 'teaching',
      position_id: positionId || null,
      must_change_password: true,
      status: 'active',
      created_by: req.authUser.id,
      temp_password_set_at: nowIso,
      permissions_override: resolvedPermissionsOverride,
      can_publish_override: resolvedCanPublishOverride,
    };

    let { data: insertedProfile, error: insertProfileErr } = await supabase
      .from('staff_profiles')
      .insert([staffProfilePayload])
      .select('id,email,display_name,role,position_id,must_change_password,status,created_at')
      .single();

    if (insertProfileErr && String(insertProfileErr.message || '').toLowerCase().includes('staff_type')) {
      const legacyPayload = { ...staffProfilePayload };
      delete legacyPayload.staff_type;
      ({ data: insertedProfile, error: insertProfileErr } = await supabase
        .from('staff_profiles')
        .insert([legacyPayload])
        .select('id,email,display_name,role,position_id,must_change_password,status,created_at')
        .single());
    }

    if (insertProfileErr) {
      // Roll back auth user if profile insert fails.
      await supabase.auth.admin.deleteUser(userId);
      return res.status(400).json({ success: false, message: insertProfileErr.message || 'Failed to create staff profile.' });
    }

    if (safeRole === 'admin') {
      const { error: adminProfileErr } = await supabase
        .from('admin_profiles')
        .upsert({
          id: userId,
          email: normalizedEmail,
          display_name: String(displayName || '').trim() || null,
          role: 'admin',
          preferences: ADMIN_DEFAULT_PREFERENCES,
          permissions: ADMIN_DEFAULT_PERMISSIONS,
          can_publish: ADMIN_DEFAULT_PUBLISH,
          must_change_password: true,
          temp_password_set_at: nowIso,
          updated_at: nowIso,
        });

      if (adminProfileErr) {
        await supabase.auth.admin.deleteUser(userId);
        return res.status(400).json({ success: false, message: adminProfileErr.message || 'Failed to create admin profile.' });
      }
    }

    await logAudit(req, 'staff.created', 'staff_profile', insertedProfile.id, {
      role: insertedProfile.role,
      account_type: safeRole === 'staff' ? safeAccountType : 'teaching',
      email: insertedProfile.email,
      position_id: insertedProfile.position_id,
      must_change_password: insertedProfile.must_change_password,
    });

    res.status(201).json({
      success: true,
      message: 'Staff account created. User must change password on first login.',
      data: insertedProfile,
    });
  } catch (error) {
    console.error('POST /api/staff/create error:', error);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

module.exports = router;
