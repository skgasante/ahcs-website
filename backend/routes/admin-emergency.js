const express = require('express');
const { supabase } = require('../supabase');
const {
  requireAuth,
  requireOwnerSuperadmin,
  logAudit,
} = require('../authz');

const router = express.Router();

router.post('/unlock-account', requireAuth, requireOwnerSuperadmin, async (req, res) => {
  try {
    const targetUserId = String(req.body.targetUserId || '').trim();
    if (!targetUserId) {
      return res.status(400).json({ success: false, message: 'targetUserId is required.' });
    }

    const payload = {
      must_change_password: false,
      updated_at: new Date().toISOString(),
    };

    await Promise.allSettled([
      supabase.from('admin_profiles').update(payload).eq('id', targetUserId),
      supabase.from('staff_profiles').update(payload).eq('id', targetUserId),
    ]);

    await logAudit(req, 'emergency.unlock_account', 'user', targetUserId, {
      reason: String(req.body.reason || '').trim() || 'owner recovery',
    });

    res.json({ success: true, message: 'Account unlock flags reset.' });
  } catch (error) {
    console.error('POST /api/admin/emergency/unlock-account error:', error);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

router.post('/repair-role', requireAuth, requireOwnerSuperadmin, async (req, res) => {
  try {
    const targetUserId = String(req.body.targetUserId || '').trim();
    const role = String(req.body.role || '').trim().toLowerCase();

    if (!targetUserId) {
      return res.status(400).json({ success: false, message: 'targetUserId is required.' });
    }
    if (!['superadmin', 'admin', 'staff'].includes(role)) {
      return res.status(400).json({ success: false, message: 'role must be superadmin, admin, or staff.' });
    }

    const nowIso = new Date().toISOString();

    const { error: staffErr } = await supabase
      .from('staff_profiles')
      .upsert({
        id: targetUserId,
        role,
        updated_at: nowIso,
      });

    if (staffErr) {
      return res.status(400).json({ success: false, message: staffErr.message || 'Could not repair staff role.' });
    }

    if (role === 'admin' || role === 'superadmin') {
      await supabase
        .from('admin_profiles')
        .upsert({
          id: targetUserId,
          role,
          updated_at: nowIso,
        });
    }

    await logAudit(req, 'emergency.repair_role', 'user', targetUserId, {
      repaired_role: role,
      reason: String(req.body.reason || '').trim() || 'owner recovery',
    });

    res.json({ success: true, message: 'Role repaired successfully.' });
  } catch (error) {
    console.error('POST /api/admin/emergency/repair-role error:', error);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

module.exports = router;
