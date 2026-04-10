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

-- ──────────────────────────────────────────────────────────────
-- ADMIN DASHBOARD — Stage 3: News Articles
-- Run in Supabase SQL Editor
-- ──────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS news_articles (
  id           uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  title        TEXT        NOT NULL,
  category     TEXT,
  article_date TEXT,
  summary      TEXT,
  body         TEXT,
  status       TEXT        DEFAULT 'draft',
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE news_articles ENABLE ROW LEVEL SECURITY;

-- Public (anon) can only read published articles
CREATE POLICY "Public can read published news" ON news_articles
  FOR SELECT TO anon USING (status = 'published');

-- Authenticated admins can read all articles (including drafts)
CREATE POLICY "Authenticated can read all news" ON news_articles
  FOR SELECT TO authenticated USING (true);

-- Authenticated admins can create articles
CREATE POLICY "Authenticated can insert news" ON news_articles
  FOR INSERT TO authenticated WITH CHECK (true);

-- Authenticated admins can update articles
CREATE POLICY "Authenticated can update news" ON news_articles
  FOR UPDATE TO authenticated USING (true);

-- Authenticated admins can delete articles
CREATE POLICY "Authenticated can delete news" ON news_articles
  FOR DELETE TO authenticated USING (true);

-- ──────────────────────────────────────────────────────────────
-- ADMIN DASHBOARD — Stage 3.5: News Images
-- Run in Supabase SQL Editor
-- ──────────────────────────────────────────────────────────────

-- Add images column to store uploaded image URLs and captions as JSON
ALTER TABLE news_articles
  ADD COLUMN IF NOT EXISTS images JSONB DEFAULT '[]';

-- Create a "news-images" storage bucket in Supabase Storage (public bucket),
-- then run these policies:

-- Authenticated admins can upload images
CREATE POLICY "news-images authenticated upload" ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (bucket_id = 'news-images');

-- Anyone can read news images (they appear on the public article page)
CREATE POLICY "news-images public read" ON storage.objects
  FOR SELECT USING (bucket_id = 'news-images');

-- Authenticated admins can delete images
CREATE POLICY "news-images authenticated delete" ON storage.objects
  FOR DELETE TO authenticated USING (bucket_id = 'news-images');

-- ──────────────────────────────────────────────────────────────
-- ADMIN DASHBOARD — Stage 4: Vacancies
-- Run in Supabase SQL Editor
-- ──────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS vacancies (
  id          uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  title       TEXT        NOT NULL,
  department  TEXT,
  type        TEXT        DEFAULT 'Full-Time',
  description TEXT,
  status      TEXT        DEFAULT 'closed',
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE vacancies ENABLE ROW LEVEL SECURITY;

-- Public (anon) can only read open vacancies
CREATE POLICY "Public can read open vacancies" ON vacancies
  FOR SELECT TO anon USING (status = 'open');

-- Authenticated admins can read all vacancies
CREATE POLICY "Authenticated can read all vacancies" ON vacancies
  FOR SELECT TO authenticated USING (true);

-- Authenticated admins can create vacancies
CREATE POLICY "Authenticated can insert vacancies" ON vacancies
  FOR INSERT TO authenticated WITH CHECK (true);

-- Authenticated admins can update vacancies
CREATE POLICY "Authenticated can update vacancies" ON vacancies
  FOR UPDATE TO authenticated USING (true);

-- Authenticated admins can delete vacancies
CREATE POLICY "Authenticated can delete vacancies" ON vacancies
  FOR DELETE TO authenticated USING (true);

-- ──────────────────────────────────────────────────────────────
-- ADMIN DASHBOARD — Stage 4: Seed Vacancies
-- Run in Supabase SQL Editor to populate the initial vacancies
-- ──────────────────────────────────────────────────────────────

INSERT INTO vacancies (title, department, type, description, status) VALUES
  (
    'Primary Class Teacher',
    'Teaching',
    'Full-Time',
    'Lead a class of young learners with engaging lessons, strong classroom management, and a nurturing approach that brings out the best in every child.',
    'open'
  ),
  (
    'School Administrator',
    'Administration',
    'Full-Time',
    'Support daily office operations, coordinate admissions paperwork, and maintain clear communication between parents, staff, and leadership.',
    'open'
  ),
  (
    'ICT / Coding Coach',
    'Enrichment',
    'Part-Time',
    'Deliver after-school technology sessions that spark curiosity, develop coding skills, and build digital confidence in our pupils.',
    'open'
  );