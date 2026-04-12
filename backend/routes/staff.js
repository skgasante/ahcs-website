const express = require('express');
const { supabase } = require('../supabase');

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

async function requireAdmin(req, res, next) {
  try {
    const authHeader = req.headers.authorization || '';
    const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;

    if (!token) {
      return res.status(401).json({ success: false, message: 'Missing auth token' });
    }

    const { data: userData, error: userErr } = await supabase.auth.getUser(token);
    if (userErr || !userData?.user) {
      return res.status(401).json({ success: false, message: 'Invalid session token' });
    }

    const { data: profile, error: profileErr } = await supabase
      .from('admin_profiles')
      .select('id,role')
      .eq('id', userData.user.id)
      .maybeSingle();

    if (profileErr) {
      return res.status(500).json({ success: false, message: 'Could not validate admin role' });
    }

    const role = String(profile?.role || '').toLowerCase();
    if (!profile || (role !== 'admin' && role !== 'superadmin')) {
      return res.status(403).json({ success: false, message: 'Only admin users can perform this action' });
    }

    req.authUser = userData.user;
    req.authRole = role;
    next();
  } catch (error) {
    console.error('requireAdmin error:', error);
    res.status(500).json({ success: false, message: 'Authorization check failed' });
  }
}

router.post('/create', requireAdmin, async (req, res) => {
  try {
    const {
      email,
      displayName,
      positionId,
      role = 'staff',
      temporaryPassword,
    } = req.body;

    const normalizedEmail = String(email || '').trim().toLowerCase();
    const safeRole = String(role || 'staff').trim().toLowerCase();
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

    const { data: insertedProfile, error: insertProfileErr } = await supabase
      .from('staff_profiles')
      .insert([
        {
          id: userId,
          email: normalizedEmail,
          display_name: String(displayName || '').trim() || null,
          role: safeRole,
          position_id: positionId || null,
          must_change_password: true,
          status: 'active',
          created_by: req.authUser.id,
          temp_password_set_at: nowIso,
        },
      ])
      .select('id,email,display_name,role,position_id,must_change_password,status,created_at')
      .single();

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
