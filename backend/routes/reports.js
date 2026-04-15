const express = require('express');
const { supabase } = require('../supabase');
const {
  requireAuth,
  hasPermission,
  logAudit,
} = require('../authz');

const router = express.Router();

const REPORT_STATUSES = ['draft', 'submitted', 'under_review', 'approved', 'needs_changes', 'archived'];

function normalizeStatus(status) {
  const value = String(status || '').trim().toLowerCase();
  return REPORT_STATUSES.includes(value) ? value : null;
}

function canUserEditOwnReport(report) {
  const status = normalizeStatus(report?.status || 'draft') || 'draft';
  return status === 'draft' || status === 'needs_changes';
}

function canTransition({ role, isOwner, currentStatus, nextStatus, canSubmit, canReview, canApprove }) {
  if (!nextStatus || currentStatus === nextStatus) return true;

  // Author transitions
  if (isOwner) {
    if (!canSubmit) return false;
    if ((currentStatus === 'draft' || currentStatus === 'needs_changes') && nextStatus === 'submitted') return true;
    if (currentStatus === 'submitted' && nextStatus === 'draft') return true;
    if (currentStatus === 'needs_changes' && nextStatus === 'draft') return true;
  }

  // Reviewer transitions
  if (canReview || role === 'admin' || role === 'superadmin') {
    if (currentStatus === 'submitted' && nextStatus === 'under_review') return true;
    if (currentStatus === 'under_review' && nextStatus === 'needs_changes') return true;
    if (currentStatus === 'under_review' && nextStatus === 'approved' && (canApprove || role === 'superadmin')) return true;
    if ((currentStatus === 'approved' || currentStatus === 'needs_changes') && nextStatus === 'archived') return true;
    if (currentStatus === 'submitted' && nextStatus === 'needs_changes') return true;
  }

  return false;
}

router.get('/', requireAuth, async (req, res) => {
  try {
    if (!hasPermission(req, 'reports', 'view')) {
      return res.status(403).json({ success: false, message: 'You do not have permission to view reports.' });
    }

    const canReview = hasPermission(req, 'reports', 'review');
    let query = supabase
      .from('teacher_reports')
      .select('*')
      .order('updated_at', { ascending: false });

    if (!canReview) {
      query = query.eq('submitted_by', req.authUser.id);
    }

    const { data, error } = await query;
    if (error) {
      return res.status(500).json({ success: false, message: error.message || 'Could not load reports.' });
    }

    res.json({ success: true, data: data || [] });
  } catch (error) {
    console.error('GET /api/reports error:', error);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

router.post('/', requireAuth, async (req, res) => {
  try {
    const canSubmit = hasPermission(req, 'reports', 'submit');
    if (!canSubmit) {
      return res.status(403).json({ success: false, message: 'You do not have permission to draft or submit reports.' });
    }

    const title = String(req.body.title || '').trim();
    const className = String(req.body.className || '').trim();
    const termLabel = String(req.body.termLabel || '').trim();
    const reportBody = String(req.body.reportBody || '').trim();
    const studentCount = Number(req.body.studentCount || 0);
    const requestedStatus = normalizeStatus(req.body.status || 'draft') || 'draft';

    if (!title) return res.status(400).json({ success: false, message: 'Title is required.' });
    if (!className) return res.status(400).json({ success: false, message: 'Class is required.' });
    if (!termLabel) return res.status(400).json({ success: false, message: 'Term is required.' });
    if (!reportBody) return res.status(400).json({ success: false, message: 'Report body is required.' });

    const status = requestedStatus === 'submitted' ? 'submitted' : 'draft';
    const nowIso = new Date().toISOString();

    const { data, error } = await supabase
      .from('teacher_reports')
      .insert([
        {
          submitted_by: req.authUser.id,
          submitted_by_email: req.authUser.email || null,
          title,
          class_name: className,
          term_label: termLabel,
          report_body: reportBody,
          student_count: Number.isFinite(studentCount) ? studentCount : 0,
          status,
          submitted_at: status === 'submitted' ? nowIso : null,
          status_updated_at: nowIso,
        },
      ])
      .select('*')
      .single();

    if (error) {
      return res.status(400).json({ success: false, message: error.message || 'Could not create report.' });
    }

    await logAudit(req, 'report.created', 'teacher_report', data.id, {
      status: data.status,
      title: data.title,
    });

    res.status(201).json({ success: true, data });
  } catch (error) {
    console.error('POST /api/reports error:', error);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

router.patch('/:id', requireAuth, async (req, res) => {
  try {
    const reportId = req.params.id;
    const { data: report, error: reportErr } = await supabase
      .from('teacher_reports')
      .select('*')
      .eq('id', reportId)
      .maybeSingle();

    if (reportErr || !report) {
      return res.status(404).json({ success: false, message: 'Report not found.' });
    }

    const isOwner = report.submitted_by === req.authUser.id;
    const canReview = hasPermission(req, 'reports', 'review');
    const canApprove = hasPermission(req, 'reports', 'approve');
    const canSubmit = hasPermission(req, 'reports', 'submit');

    if (!isOwner && !canReview) {
      return res.status(403).json({ success: false, message: 'You do not have permission to update this report.' });
    }

    const nextStatus = req.body.status ? normalizeStatus(req.body.status) : normalizeStatus(report.status);
    if (!nextStatus) {
      return res.status(400).json({ success: false, message: 'Invalid report status.' });
    }

    const currentStatus = normalizeStatus(report.status) || 'draft';
    const role = req.authAccess?.role || 'staff';

    if (!canTransition({ role, isOwner, currentStatus, nextStatus, canSubmit, canReview, canApprove })) {
      return res.status(403).json({ success: false, message: 'Status transition is not allowed for your role.' });
    }

    const payload = {
      updated_at: new Date().toISOString(),
      status: nextStatus,
      status_updated_at: new Date().toISOString(),
    };

    if (isOwner && canUserEditOwnReport(report)) {
      if (typeof req.body.title === 'string') payload.title = req.body.title.trim();
      if (typeof req.body.className === 'string') payload.class_name = req.body.className.trim();
      if (typeof req.body.termLabel === 'string') payload.term_label = req.body.termLabel.trim();
      if (typeof req.body.reportBody === 'string') payload.report_body = req.body.reportBody.trim();
      if (req.body.studentCount != null) {
        const count = Number(req.body.studentCount);
        payload.student_count = Number.isFinite(count) ? count : report.student_count;
      }

      if (!payload.title) return res.status(400).json({ success: false, message: 'Title is required.' });
      if (!payload.class_name) return res.status(400).json({ success: false, message: 'Class is required.' });
      if (!payload.term_label) return res.status(400).json({ success: false, message: 'Term is required.' });
      if (!payload.report_body) return res.status(400).json({ success: false, message: 'Report body is required.' });
    }

    if (nextStatus === 'submitted' && report.submitted_at == null) {
      payload.submitted_at = new Date().toISOString();
    }

    const reviewComment = String(req.body.reviewComment || '').trim();
    if ((canReview || canApprove) && reviewComment) {
      payload.review_comment = reviewComment;
      payload.reviewer_id = req.authUser.id;
      payload.reviewer_email = req.authUser.email || null;
      payload.reviewed_at = new Date().toISOString();
    }

    const { data: updated, error: updateErr } = await supabase
      .from('teacher_reports')
      .update(payload)
      .eq('id', reportId)
      .select('*')
      .single();

    if (updateErr) {
      return res.status(400).json({ success: false, message: updateErr.message || 'Could not update report.' });
    }

    await logAudit(req, 'report.updated', 'teacher_report', reportId, {
      old_status: currentStatus,
      new_status: updated.status,
      owner_edit: isOwner,
      reviewer_action: !isOwner,
      has_review_comment: !!reviewComment,
    });

    res.json({ success: true, data: updated });
  } catch (error) {
    console.error('PATCH /api/reports/:id error:', error);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

module.exports = router;
