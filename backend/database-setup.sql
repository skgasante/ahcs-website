-- AHCS Database Setup
-- Run these SQL commands in your Supabase SQL Editor

-- Create admission_enquiries table
CREATE TABLE IF NOT EXISTS admission_enquiries (
  id SERIAL PRIMARY KEY,
  parent_name TEXT NOT NULL,
  phone_number TEXT NOT NULL,
  email TEXT NOT NULL,
  child_name TEXT NOT NULL,
  date_of_birth DATE NOT NULL,
  year_group TEXT NOT NULL,
  preferred_term TEXT,
  additional_notes TEXT,
  submitted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  status TEXT DEFAULT 'pending'
);

-- Create job_applications table
CREATE TABLE IF NOT EXISTS job_applications (
  id SERIAL PRIMARY KEY,
  full_name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone_number TEXT NOT NULL,
  position_applied TEXT NOT NULL,
  motivation TEXT NOT NULL,
  cv_file_url TEXT NOT NULL,
  cv_file_name TEXT NOT NULL,
  submitted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  status TEXT DEFAULT 'pending'
);

-- Enable Row Level Security (optional, for production)
ALTER TABLE admission_enquiries ENABLE ROW LEVEL SECURITY;
-- Disable RLS for job_applications to allow public submissions
ALTER TABLE job_applications DISABLE ROW LEVEL SECURITY;

-- Create policies to allow inserts (adjust as needed for your security requirements)
CREATE POLICY "Allow public inserts to admission_enquiries" ON admission_enquiries
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow public inserts to job_applications" ON job_applications
  FOR INSERT WITH CHECK (true);

-- Storage policies for CV uploads
-- Allow public access to cv-uploads bucket
CREATE POLICY "Allow public uploads to cv-uploads" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'cv-uploads');

CREATE POLICY "Allow public reads from cv-uploads" ON storage.objects
  FOR SELECT USING (bucket_id = 'cv-uploads');

CREATE POLICY "Allow public updates to cv-uploads" ON storage.objects
  FOR UPDATE USING (bucket_id = 'cv-uploads');

CREATE POLICY "Allow public deletes from cv-uploads" ON storage.objects
  FOR DELETE USING (bucket_id = 'cv-uploads');

-- Create storage bucket for CV uploads (run this in Supabase Storage)
-- Bucket name: cv-uploads
-- Make it public for file access

-- ──────────────────────────────────────────────────────────────
-- ADMIN DASHBOARD — Stage 2
-- Run these additional policies so the admin dashboard can read
-- and update records using the anon key for authenticated users.
-- ──────────────────────────────────────────────────────────────

-- Allow logged-in admins to READ admissions enquiries
CREATE POLICY "Allow authenticated reads on admission_enquiries" ON admission_enquiries
  FOR SELECT TO authenticated USING (true);

-- Allow logged-in admins to UPDATE admissions enquiries (e.g. status)
CREATE POLICY "Allow authenticated updates on admission_enquiries" ON admission_enquiries
  FOR UPDATE TO authenticated USING (true);

-- job_applications has RLS disabled so no extra policies are needed.
-- If you re-enable RLS on job_applications, add equivalent policies: