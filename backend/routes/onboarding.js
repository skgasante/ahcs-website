const express = require('express');
const { supabase } = require('../supabase');
const { requireAuth, requirePermission, logAudit } = require('../authz');

const router = express.Router();

router.post('/student', requireAuth, requirePermission('admissions', 'update', 'Permission denied'), async (req, res) => {
  const {
    enquiryId,
    studentName,
    parentName,
    parentEmail,
    assignedClass,
    studentId,
    parentId
  } = req.body;

  try {
    // 1. Create Parent Auth Account
    const { data: authUser, error: authError } = await supabase.auth.admin.createUser({
      email: parentEmail,
      password: parentId, // Temporary password is the Parent ID
      email_confirm: true,
      user_metadata: {
        name: parentName,
        role: 'parent'
      }
    });

    if (authError) throw authError;

    const parentUid = authUser.user.id;

    // 2. Create Parent Profile
    const { error: parentError } = await supabase
      .from('parent_profiles')
      .insert([{
        id: parentUid,
        school_id: parentId,
        display_name: parentName,
        email: parentEmail
      }]);

    if (parentError) throw parentError;

    // 3. Create Student Profile
    // Split name into first and last
    const nameParts = studentName.trim().split(' ');
    const firstName = nameParts[0];
    const lastName = nameParts.length > 1 ? nameParts.slice(1).join(' ') : '—';

    const { data: studentData, error: studentError } = await supabase
      .from('students')
      .insert([{
        school_id: studentId,
        first_name: firstName,
        last_name: lastName,
        class_name: assignedClass,
        status: 'active'
      }])
      .select()
      .single();

    if (studentError) throw studentError;

    const studentUuid = studentData.id;

    // 4. Link Parent to Student
    const { error: linkError } = await supabase
      .from('parent_student_links')
      .insert([{
        parent_id: parentUid,
        student_id: studentUuid,
        relationship: 'Parent'
      }]);

    if (linkError) throw linkError;

    // 5. Update Enquiry Status
    const { error: enquiryError } = await supabase
      .from('admission_enquiries')
      .update({ status: 'Enrolled' })
      .eq('id', enquiryId);

    if (enquiryError) throw enquiryError;

    // 6. Log Audit
    await logAudit(req, 'ONBOARD_STUDENT', 'admission_enquiries', enquiryId, {
      student_id: studentId,
      parent_id: parentId,
      class: assignedClass
    });

    res.json({ success: true, message: 'Student onboarded successfully' });
  } catch (error) {
    console.error('Onboarding Error:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
