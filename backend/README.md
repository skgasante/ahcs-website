# AHCS Backend Server

Node.js/Express backend server for Annan House Community School website, handling form submissions and connecting to Supabase database.

## Quick Start (Windows)

1. **Install Node.js** (if not already installed)
   - Download from https://nodejs.org
   - Install the LTS version

2. **Run the backend server**
   ```bash
   # Double-click the start-backend.bat file in the root directory
   # OR run these commands manually:
   cd backend
   npm install
   npm start
   ```

3. **Set up the database**
   - Open your Supabase project dashboard
   - Go to SQL Editor
   - Copy and run the contents of `database-setup.sql`
   - Create a storage bucket called `cv-uploads` (make it public)

4. **Test the server**
   - Visit `http://localhost:3001/api/health` to check if it's running

## Features

- **Admission Enquiries**: Handle admission form submissions
- **Job Applications**: Process job applications with CV uploads
- **Staff Onboarding**: Create staff accounts with temporary passwords and first-login reset
- **Teacher Reports Workflow**: Draft, submit, review, approve/needs-changes, archive
- **Audit Logging**: Track critical role/permission/content/status updates
- **Emergency Recovery**: Owner-only lockout and role-repair controls
- **Supabase Integration**: Database storage and file uploads
- **CORS Support**: Cross-origin requests enabled
- **File Upload**: CV uploads with validation (PDF, DOC, DOCX, max 5MB)

## API Endpoints

### Admission Enquiries
- `POST /api/admissions` - Submit admission enquiry
- `GET /api/admissions` - Get all enquiries (admin)

### Job Applications
- `POST /api/jobs` - Submit job application with CV
- `GET /api/jobs` - Get all applications (admin)

### Health Check
- `GET /api/health` - Server health status

### Staff and Access
- `POST /api/staff/create` - Create staff account (permission: settings.manage_staff)

### Teacher Reports
- `GET /api/reports` - List reports (own reports for teachers, all for reviewers)
- `POST /api/reports` - Create report draft/submit
- `PATCH /api/reports/:id` - Update report content, status, and review comments

### Owner Emergency Controls
- `POST /api/admin/emergency/unlock-account` - Reset lockout flags
- `POST /api/admin/emergency/repair-role` - Repair user role mapping

## Frontend Integration

Your HTML forms are already configured to submit to the backend API. Make sure the backend server is running when testing form submissions.

## Database Tables

The backend expects these tables in your Supabase database:

**admission_enquiries**:
- id (SERIAL PRIMARY KEY)
- parent_name, phone_number, email, child_name (TEXT NOT NULL)
- date_of_birth (DATE NOT NULL)
- year_group, preferred_term, additional_notes (TEXT)
- submitted_at (TIMESTAMP)
- status (TEXT DEFAULT 'pending')

**job_applications**:
- id (SERIAL PRIMARY KEY)
- full_name, email, phone_number, position_applied, motivation (TEXT NOT NULL)
- cv_file_url, cv_file_name (TEXT NOT NULL)
- submitted_at (TIMESTAMP)
- status (TEXT DEFAULT 'pending')

## Security Notes

- File uploads are limited to 5MB
- Only PDF, DOC, and DOCX files are accepted for CVs
- Input validation is implemented on the server
- Admin APIs enforce role/permission checks via backend middleware
- Database RLS should mirror UI/backend authorization for direct Supabase access