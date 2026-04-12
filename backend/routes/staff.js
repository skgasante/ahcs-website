const express = require('express');
const { supabase } = require('../supabase');

const router = express.Router();

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
          temp_password_set_at: new Date().toISOString(),
        },
      ])
      .select('id,email,display_name,role,position_id,must_change_password,status,created_at')
      .single();

    if (insertProfileErr) {
      // Roll back auth user if profile insert fails.
      await supabase.auth.admin.deleteUser(userId);
      return res.status(400).json({ success: false, message: insertProfileErr.message || 'Failed to create staff profile.' });
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
