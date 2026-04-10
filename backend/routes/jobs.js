const express = require('express');
const { supabase } = require('../supabase');
const { Resend } = require('resend');
const router = express.Router();

const resend = new Resend(process.env.RESEND_API_KEY);

// POST /api/jobs - Handle job application form submissions
router.post('/', async (req, res) => {
  try {
    const {
      fullName,
      email,
      phoneNumber,
      positionApplied,
      motivation
    } = req.body;

    // Validate required fields
    if (!fullName || !email || !phoneNumber || !positionApplied || !motivation) {
      return res.status(400).json({
        success: false,
        message: 'Missing required fields'
      });
    }

    // Check if CV file was uploaded
    if (!req.files || !req.files.cvFile) {
      return res.status(400).json({
        success: false,
        message: 'CV file is required'
      });
    }

    const cvFile = req.files.cvFile;

    // Validate file type
    const allowedTypes = ['application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'];
    if (!allowedTypes.includes(cvFile.mimetype)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid file type. Please upload PDF, DOC, or DOCX files only.'
      });
    }

    // Upload CV to Supabase Storage
    const fileName = `${Date.now()}_${fullName.replace(/\s+/g, '_')}_${cvFile.name}`;
    const fileBuffer = Buffer.isBuffer(cvFile.data) ? cvFile.data : Buffer.from(cvFile.data);
    
    const { data: uploadData, error: uploadError } = await supabase.storage
      .from('cv-uploads')
      .upload(fileName, fileBuffer, {
        contentType: cvFile.mimetype,
        upsert: false
      });

    if (uploadError) {
      console.error('File upload error:', uploadError);
      return res.status(500).json({
        success: false,
        message: `Failed to upload CV file: ${uploadError.message || uploadError}`
      });
    }

    // Get public URL for the uploaded file
    const { data: { publicUrl } } = supabase.storage
      .from('cv-uploads')
      .getPublicUrl(fileName);

    // Insert application data into database
    const { data, error } = await supabase
      .from('job_applications')
      .insert([
        {
          full_name: fullName,
          email: email,
          phone_number: phoneNumber,
          position_applied: positionApplied,
          motivation: motivation,
          cv_file_url: publicUrl,
          cv_file_name: cvFile.name,
          submitted_at: new Date().toISOString(),
          status: 'pending'
        }
      ])
      .select();

    if (error) {
      console.error('Database insert error:', error);
      // If database insert fails, try to delete the uploaded file
      await supabase.storage
        .from('cv-uploads')
        .remove([fileName]);

      return res.status(500).json({
        success: false,
        message: `Failed to save job application: ${error.message || error}`
      });
    }

    res.status(201).json({
      success: true,
      message: 'Application received. We will review it carefully and contact you within 5 working days if your qualifications align with our needs.',
      data: data[0]
    });

    // Send notification email to school admin (non-blocking — failure does not affect the response)
    resend.emails.send({
      from: 'onboarding@resend.dev',
      to: 'skgasante@gmail.com',
      subject: `New Job Application — ${positionApplied}`,
      html: `
        <div style="font-family:'Helvetica Neue',Arial,sans-serif;max-width:600px;margin:0 auto;color:#0E2841;">
          <div style="background:#ffffff;padding:28px 40px 24px;border-radius:8px 8px 0 0;border:1px solid #E5E7EB;border-bottom:none;text-align:center;">
            <table cellpadding="0" cellspacing="0" style="border-collapse:collapse;margin:0 auto 12px;">
              <tr>
                <td style="vertical-align:middle;padding-right:12px;">
                  <table cellpadding="0" cellspacing="3" style="border-collapse:separate;">
                    <tr>
                      <td style="width:13px;height:13px;background:#7B4FAF;border-radius:3px;font-size:0;line-height:0;">&nbsp;</td>
                      <td style="width:13px;height:13px;background:#196B24;border-radius:3px;font-size:0;line-height:0;">&nbsp;</td>
                    </tr>
                    <tr>
                      <td style="width:13px;height:13px;background:#E97132;border-radius:3px;font-size:0;line-height:0;">&nbsp;</td>
                      <td style="width:13px;height:13px;background:#0F9ED5;border-radius:3px;font-size:0;line-height:0;">&nbsp;</td>
                    </tr>
                  </table>
                </td>
                <td style="vertical-align:middle;text-align:left;">
                  <p style="margin:0;font-size:17px;font-weight:800;color:#0E2841;letter-spacing:-.3px;line-height:1.2;">Annan House</p>
                  <p style="margin:2px 0 0;font-size:11px;font-weight:400;color:#9CA3AF;">Community School</p>
                </td>
              </tr>
            </table>
            <div style="padding-top:18px;border-top:1px solid #E5E7EB;">
              <p style="margin:0;font-size:17px;font-weight:700;color:#0E2841;">New Job Application</p>
              <p style="margin:4px 0 0;font-size:12px;color:#9CA3AF;">Staff Recruitment</p>
            </div>
          </div>
          <div style="background:#ffffff;padding:36px 40px;border:1px solid #E5E7EB;border-top:none;">
            <p style="font-size:15px;line-height:1.7;margin:0 0 24px;color:#374151;">A new job application has been submitted via the website. Details are below.</p>
            <table style="width:100%;border-collapse:collapse;font-size:14px;">
              <tr style="border-bottom:1px solid #E5E7EB;"><td style="padding:10px 0;color:#6B7280;width:38%;">Position Applied For</td><td style="padding:10px 0;font-weight:700;color:#0E2841;">${positionApplied}</td></tr>
              <tr style="border-bottom:1px solid #E5E7EB;"><td style="padding:10px 0;color:#6B7280;">Applicant Name</td><td style="padding:10px 0;color:#0E2841;">${fullName}</td></tr>
              <tr style="border-bottom:1px solid #E5E7EB;"><td style="padding:10px 0;color:#6B7280;">Email Address</td><td style="padding:10px 0;"><a href="mailto:${email}" style="color:#0F9ED5;">${email}</a></td></tr>
              <tr style="border-bottom:1px solid #E5E7EB;"><td style="padding:10px 0;color:#6B7280;">Phone Number</td><td style="padding:10px 0;"><a href="tel:${phoneNumber}" style="color:#0F9ED5;">${phoneNumber}</a></td></tr>
              <tr style="border-bottom:1px solid #E5E7EB;"><td style="padding:10px 0;color:#6B7280;">CV File</td><td style="padding:10px 0;"><a href="${publicUrl}" style="color:#0F9ED5;">Download CV</a></td></tr>
              <tr style="border-bottom:1px solid #E5E7EB;"><td style="padding:10px 0;color:#6B7280;">Submitted At</td><td style="padding:10px 0;color:#0E2841;">${new Date().toLocaleString('en-GB', { dateStyle: 'full', timeStyle: 'short' })}</td></tr>
            </table>
            <div style="margin-top:24px;background:#F8F9FA;border-radius:6px;padding:16px 20px;">
              <p style="margin:0 0 8px;font-size:13px;font-weight:700;color:#0E2841;">Motivation Statement</p>
              <p style="margin:0;font-size:14px;line-height:1.7;color:#374151;white-space:pre-wrap;">${motivation}</p>
            </div>
          </div>
          <div style="background:#F8F9FA;padding:16px 40px;border:1px solid #E5E7EB;border-top:none;border-radius:0 0 8px 8px;">
            <p style="margin:0;font-size:12px;color:#9CA3AF;text-align:center;">8 Dr Amilcar Cabral Road, Airport Residential, Accra &middot; GA-085-8565</p>
          </div>
        </div>
      `
    }).catch(err => console.error('Job application notification email failed:', err));

  } catch (error) {
    console.error('Server error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// GET /api/jobs - Get all job applications (for admin use)
router.get('/', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('job_applications')
      .select('*')
      .order('submitted_at', { ascending: false });

    if (error) {
      console.error('Supabase error:', error);
      return res.status(500).json({
        success: false,
        message: 'Failed to fetch job applications'
      });
    }

    res.json({
      success: true,
      data: data
    });

  } catch (error) {
    console.error('Server error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

module.exports = router;