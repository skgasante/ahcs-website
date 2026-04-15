const { supabase } = require('./supabase');

const OWNER_SUPERADMIN_EMAIL = String(process.env.OWNER_SUPERADMIN_EMAIL || 'shad@admin.com').trim().toLowerCase();

const ROLE_BASELINE = {
  superadmin: {
    permissions: {
      admissions: { view: true, update: true, export: true },
      jobs: { view: true, update: true, export: true, manage_vacancies: true },
      news: { view: true, create: true, edit: true, publish: true, delete: true },
      gallery: { view: true, upload: true, edit: true, publish: true, delete: true },
      reports: { view: true, submit: true, review: true, approve: true },
      settings: { own: true, manage_staff: true, manage_roles: true },
    },
    canPublish: { news: true, gallery: true, vacancies: true, reports: true },
  },
  admin: {
    permissions: {
      admissions: { view: true, update: true, export: true },
      jobs: { view: true, update: true, export: true, manage_vacancies: true },
      news: { view: true, create: true, edit: true, publish: true, delete: true },
      gallery: { view: true, upload: true, edit: true, publish: true, delete: true },
      reports: { view: true, submit: false, review: true, approve: true },
      settings: { own: true, manage_staff: true, manage_roles: false },
    },
    canPublish: { news: true, gallery: true, vacancies: true, reports: true },
  },
  staff: {
    permissions: {
      admissions: { view: false, update: false, export: false },
      jobs: { view: false, update: false, export: false, manage_vacancies: false },
      news: { view: true, create: true, edit: true, publish: false, delete: false },
      gallery: { view: true, upload: true, edit: true, publish: false, delete: false },
      reports: { view: true, submit: true, review: false, approve: false },
      settings: { own: true, manage_staff: false, manage_roles: false },
    },
    canPublish: { news: false, gallery: false, vacancies: false, reports: false },
  },
};

const DUTY_BASELINE = {
  teaching: {
    permissions: {
      admissions: { view: false, update: false, export: false },
      jobs: { view: false, update: false, export: false, manage_vacancies: false },
      news: { view: true, create: true, edit: true, publish: false, delete: false },
      gallery: { view: true, upload: true, edit: true, publish: false, delete: false },
      reports: { view: true, submit: true, review: false, approve: false },
      settings: { own: true, manage_staff: false, manage_roles: false },
    },
    canPublish: { news: false, gallery: false, vacancies: false, reports: false },
  },
  non_teaching: {
    permissions: {
      admissions: { view: false, update: false, export: false },
      jobs: { view: false, update: false, export: false, manage_vacancies: false },
      news: { view: false, create: false, edit: false, publish: false, delete: false },
      gallery: { view: false, upload: false, edit: false, publish: false, delete: false },
      reports: { view: false, submit: false, review: false, approve: false },
      settings: { own: true, manage_staff: false, manage_roles: false },
    },
    canPublish: { news: false, gallery: false, vacancies: false, reports: false },
  },
};

function normalizeRole(role, email) {
  if (String(email || '').trim().toLowerCase() === OWNER_SUPERADMIN_EMAIL) return 'superadmin';
  const value = String(role || '').trim().toLowerCase();
  if (value === 'superadmin' || value === 'admin' || value === 'staff') return value;
  return 'staff';
}

function cloneBaseline(role) {
  const selected = ROLE_BASELINE[role] || ROLE_BASELINE.staff;
  return {
    permissions: JSON.parse(JSON.stringify(selected.permissions)),
    canPublish: { ...selected.canPublish },
  };
}

function cloneDutyBaseline(staffType) {
  const selected = DUTY_BASELINE[staffType] || DUTY_BASELINE.teaching;
  return {
    permissions: JSON.parse(JSON.stringify(selected.permissions)),
    canPublish: { ...selected.canPublish },
  };
}

function mergePermissionLayer(target, layer) {
  if (!layer || typeof layer !== 'object') return;
  Object.keys(target).forEach((group) => {
    if (layer[group] && typeof layer[group] === 'object') {
      target[group] = { ...target[group], ...layer[group] };
    }
  });
}

function mergePublishLayer(target, layer) {
  if (!layer || typeof layer !== 'object') return;
  Object.assign(target, layer);
}

async function resolveAccessByUser(user) {
  const email = user?.email || '';

  const { data: adminProfile } = await supabase
    .from('admin_profiles')
    .select('role,permissions,can_publish')
    .eq('id', user.id)
    .maybeSingle();

  if (adminProfile) {
    const role = normalizeRole(adminProfile.role, email);
    const baseline = cloneBaseline(role);
    mergePermissionLayer(baseline.permissions, adminProfile.permissions);
    mergePublishLayer(baseline.canPublish, adminProfile.can_publish);
    return {
      role,
      permissions: baseline.permissions,
      canPublish: baseline.canPublish,
      profileSource: 'admin_profiles',
    };
  }

  let { data: staffProfile, error: staffProfileErr } = await supabase
    .from('staff_profiles')
    .select('role,staff_type,position_id,permissions_override,can_publish_override')
    .eq('id', user.id)
    .maybeSingle();

  if (staffProfileErr && String(staffProfileErr.message || '').toLowerCase().includes('staff_type')) {
    const retry = await supabase
      .from('staff_profiles')
      .select('role,position_id,permissions_override,can_publish_override')
      .eq('id', user.id)
      .maybeSingle();
    staffProfile = retry.data;
  }

  if (staffProfile) {
    const role = normalizeRole(staffProfile.role, email);
    const staffType = String(staffProfile.staff_type || 'teaching').trim().toLowerCase();
    const baseline = role === 'staff'
      ? cloneDutyBaseline(staffType)
      : cloneBaseline(role);

    if (staffProfile.position_id && !(role === 'staff' && staffType === 'non_teaching')) {
      const { data: position } = await supabase
        .from('staff_positions')
        .select('permissions,can_publish')
        .eq('id', staffProfile.position_id)
        .maybeSingle();
      if (position) {
        mergePermissionLayer(baseline.permissions, position.permissions);
        mergePublishLayer(baseline.canPublish, position.can_publish);
      }
    }

    mergePermissionLayer(baseline.permissions, staffProfile.permissions_override);
    mergePublishLayer(baseline.canPublish, staffProfile.can_publish_override);

    return {
      role,
      permissions: baseline.permissions,
      canPublish: baseline.canPublish,
      profileSource: 'staff_profiles',
    };
  }

  const role = normalizeRole('staff', email);
  const baseline = cloneBaseline(role);
  return {
    role,
    permissions: baseline.permissions,
    canPublish: baseline.canPublish,
    profileSource: 'baseline',
  };
}

async function requireAuth(req, res, next) {
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

    const access = await resolveAccessByUser(userData.user);
    req.authUser = userData.user;
    req.authAccess = access;
    next();
  } catch (error) {
    console.error('requireAuth error:', error);
    res.status(500).json({ success: false, message: 'Authorization check failed' });
  }
}

function hasPermission(req, group, action) {
  return !!req.authAccess?.permissions?.[group]?.[action];
}

function canPublishArea(req, area, group = area) {
  return hasPermission(req, group, 'publish') && req.authAccess?.canPublish?.[area] !== false;
}

function requirePermission(group, action, message) {
  return (req, res, next) => {
    if (!hasPermission(req, group, action)) {
      return res.status(403).json({ success: false, message: message || 'You do not have permission to perform this action.' });
    }
    next();
  };
}

function requireRole(roles) {
  const allowed = Array.isArray(roles) ? roles : [roles];
  return (req, res, next) => {
    const role = req.authAccess?.role || '';
    if (!allowed.includes(role)) {
      return res.status(403).json({ success: false, message: 'You do not have the required role for this action.' });
    }
    next();
  };
}

function requireOwnerSuperadmin(req, res, next) {
  const role = req.authAccess?.role;
  const email = String(req.authUser?.email || '').trim().toLowerCase();
  if (role !== 'superadmin' || email !== OWNER_SUPERADMIN_EMAIL) {
    return res.status(403).json({ success: false, message: 'Owner-only emergency control.' });
  }
  next();
}

async function logAudit(req, action, targetType, targetId, details = {}) {
  try {
    await supabase.from('audit_logs').insert([
      {
        actor_id: req.authUser?.id || null,
        actor_email: req.authUser?.email || null,
        actor_role: req.authAccess?.role || null,
        action,
        target_type: targetType,
        target_id: targetId ? String(targetId) : null,
        details,
      },
    ]);
  } catch (error) {
    console.warn('audit_logs insert failed:', error?.message || error);
  }
}

module.exports = {
  OWNER_SUPERADMIN_EMAIL,
  requireAuth,
  requireRole,
  requirePermission,
  requireOwnerSuperadmin,
  hasPermission,
  canPublishArea,
  logAudit,
};
