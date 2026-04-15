const express = require('express');
const { supabase } = require('../supabase');
const {
  requireAuth,
  hasPermission,
  logAudit,
} = require('../authz');

const router = express.Router();

function normalizeDate(value) {
  const raw = String(value || '').trim();
  if (!raw) return null;
  const date = new Date(raw);
  if (Number.isNaN(date.getTime())) return null;
  return date.toISOString().slice(0, 10);
}

function normalizeRecords(records) {
  const payload = Array.isArray(records) ? records : [];
  return payload
    .map((entry) => ({
      student: String(entry?.student || '').trim(),
      status: String(entry?.status || '').trim().toLowerCase(),
      note: String(entry?.note || '').trim(),
    }))
    .filter((entry) => entry.student)
    .map((entry) => ({
      student: entry.student,
      status: ['present', 'absent', 'late', 'excused'].includes(entry.status) ? entry.status : 'present',
      note: entry.note || null,
    }));
}

router.get('/', requireAuth, async (req, res) => {
  try {
    if (!hasPermission(req, 'reports', 'view')) {
      return res.status(403).json({ success: false, message: 'You do not have permission to view attendance records.' });
    }

    const { data, error } = await supabase
      .from('attendance_records')
      .select('*')
      .order('attendance_on', { ascending: false })
      .order('updated_at', { ascending: false })
      .limit(150);

    if (error) {
      return res.status(500).json({ success: false, message: error.message || 'Could not load attendance records.' });
    }

    res.json({ success: true, data: data || [] });
  } catch (error) {
    console.error('GET /api/attendance error:', error);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

router.post('/', requireAuth, async (req, res) => {
  try {
    if (!hasPermission(req, 'reports', 'submit')) {
      return res.status(403).json({ success: false, message: 'You do not have permission to submit attendance.' });
    }

    const classLabel = String(req.body.classLabel || '').trim();
    const attendanceOn = normalizeDate(req.body.attendanceOn);
    const records = normalizeRecords(req.body.records);

    if (!classLabel) return res.status(400).json({ success: false, message: 'Class label is required.' });
    if (!attendanceOn) return res.status(400).json({ success: false, message: 'Valid attendance date is required.' });

    const { data, error } = await supabase
      .from('attendance_records')
      .insert([
        {
          class_label: classLabel,
          attendance_on: attendanceOn,
          records,
          submitted_by: req.authUser.id,
        },
      ])
      .select('*')
      .single();

    if (error) {
      return res.status(400).json({ success: false, message: error.message || 'Could not create attendance record.' });
    }

    await logAudit(req, 'attendance.created', 'attendance_record', data.id, {
      class_label: classLabel,
      attendance_on: attendanceOn,
      record_count: records.length,
    });

    res.status(201).json({ success: true, data });
  } catch (error) {
    console.error('POST /api/attendance error:', error);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

router.patch('/:id', requireAuth, async (req, res) => {
  try {
    const canSubmit = hasPermission(req, 'reports', 'submit');
    const canReview = hasPermission(req, 'reports', 'review');

    if (!canSubmit && !canReview) {
      return res.status(403).json({ success: false, message: 'You do not have permission to update attendance records.' });
    }

    const recordId = req.params.id;
    const { data: existing, error: existingErr } = await supabase
      .from('attendance_records')
      .select('*')
      .eq('id', recordId)
      .maybeSingle();

    if (existingErr || !existing) {
      return res.status(404).json({ success: false, message: 'Attendance record not found.' });
    }

    const isOwner = existing.submitted_by === req.authUser.id;
    if (!isOwner && !canReview) {
      return res.status(403).json({ success: false, message: 'You can only edit your own records.' });
    }

    const payload = {
      updated_at: new Date().toISOString(),
    };

    if (typeof req.body.classLabel === 'string') {
      const classLabel = req.body.classLabel.trim();
      if (!classLabel) return res.status(400).json({ success: false, message: 'Class label cannot be empty.' });
      payload.class_label = classLabel;
    }

    if (req.body.attendanceOn != null) {
      const attendanceOn = normalizeDate(req.body.attendanceOn);
      if (!attendanceOn) return res.status(400).json({ success: false, message: 'Invalid attendance date.' });
      payload.attendance_on = attendanceOn;
    }

    if (req.body.records != null) {
      payload.records = normalizeRecords(req.body.records);
    }

    const { data: updated, error: updateErr } = await supabase
      .from('attendance_records')
      .update(payload)
      .eq('id', recordId)
      .select('*')
      .single();

    if (updateErr) {
      return res.status(400).json({ success: false, message: updateErr.message || 'Could not update attendance record.' });
    }

    await logAudit(req, 'attendance.updated', 'attendance_record', recordId, {
      owner_edit: isOwner,
      reviewer_edit: !isOwner,
      updated_fields: Object.keys(payload),
    });

    res.json({ success: true, data: updated });
  } catch (error) {
    console.error('PATCH /api/attendance/:id error:', error);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

module.exports = router;
