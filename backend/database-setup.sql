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

-- ──────────────────────────────────────────────────────────────
-- ADMIN DASHBOARD — Stage 5: Gallery Images
-- Run in Supabase SQL Editor
-- ──────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS gallery_images (
  id           uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  title        TEXT,
  caption      TEXT,
  alt_text     TEXT,
  album        TEXT,
  image_url    TEXT        NOT NULL,
  storage_path TEXT,
  status       TEXT        DEFAULT 'draft',
  featured     BOOLEAN     DEFAULT false,
  taken_on     DATE,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE gallery_images ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public can read published gallery images" ON gallery_images;
DROP POLICY IF EXISTS "Authenticated can read all gallery images" ON gallery_images;
DROP POLICY IF EXISTS "Authenticated can insert gallery images" ON gallery_images;
DROP POLICY IF EXISTS "Authenticated can update gallery images" ON gallery_images;
DROP POLICY IF EXISTS "Authenticated can delete gallery images" ON gallery_images;

-- Public (anon) can only read published gallery images
CREATE POLICY "Public can read published gallery images" ON gallery_images
  FOR SELECT TO anon USING (status = 'published');

-- Authenticated admins can read all gallery images
CREATE POLICY "Authenticated can read all gallery images" ON gallery_images
  FOR SELECT TO authenticated USING (true);

-- Authenticated admins can insert gallery images
CREATE POLICY "Authenticated can insert gallery images" ON gallery_images
  FOR INSERT TO authenticated WITH CHECK (true);

-- Authenticated admins can update gallery images
CREATE POLICY "Authenticated can update gallery images" ON gallery_images
  FOR UPDATE TO authenticated USING (true);

-- Authenticated admins can delete gallery images
CREATE POLICY "Authenticated can delete gallery images" ON gallery_images
  FOR DELETE TO authenticated USING (true);

-- Create a "gallery-images" storage bucket in Supabase Storage (public bucket),
-- then run these policies:

DROP POLICY IF EXISTS "gallery-images authenticated upload" ON storage.objects;
DROP POLICY IF EXISTS "gallery-images public read" ON storage.objects;
DROP POLICY IF EXISTS "gallery-images authenticated delete" ON storage.objects;

-- Authenticated admins can upload gallery images
CREATE POLICY "gallery-images authenticated upload" ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (bucket_id = 'gallery-images');

-- Anyone can read gallery images
CREATE POLICY "gallery-images public read" ON storage.objects
  FOR SELECT USING (bucket_id = 'gallery-images');

-- Authenticated admins can delete gallery images
CREATE POLICY "gallery-images authenticated delete" ON storage.objects
  FOR DELETE TO authenticated USING (bucket_id = 'gallery-images');

-- ──────────────────────────────────────────────────────────────
-- ADMIN DASHBOARD — Stage 6: Admin Account Settings
-- Run in Supabase SQL Editor
-- ──────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS admin_profiles (
  id           uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email        TEXT        NOT NULL,
  display_name TEXT,
  phone        TEXT,
  job_title    TEXT,
  role         TEXT        DEFAULT 'admin',
  preferences  JSONB       DEFAULT '{"admissions":true,"jobs":true,"news":true,"gallery":true}',
  permissions  JSONB       DEFAULT '{"admissions":{"view":true,"update":true,"export":true},"jobs":{"view":true,"update":true,"export":true,"manage_vacancies":true},"news":{"view":true,"create":true,"edit":true,"publish":true,"delete":true},"gallery":{"view":true,"upload":true,"edit":true,"publish":true,"delete":true},"reports":{"view":true,"submit":false,"review":true,"approve":true},"settings":{"own":true,"manage_staff":false,"manage_roles":false}}',
  can_publish  JSONB       DEFAULT '{"news":true,"gallery":true,"vacancies":true,"reports":true}',
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at   TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE admin_profiles
  ADD COLUMN IF NOT EXISTS permissions JSONB DEFAULT '{"admissions":{"view":true,"update":true,"export":true},"jobs":{"view":true,"update":true,"export":true,"manage_vacancies":true},"news":{"view":true,"create":true,"edit":true,"publish":true,"delete":true},"gallery":{"view":true,"upload":true,"edit":true,"publish":true,"delete":true},"reports":{"view":true,"submit":false,"review":true,"approve":true},"settings":{"own":true,"manage_staff":false,"manage_roles":false}}';

ALTER TABLE admin_profiles
  ADD COLUMN IF NOT EXISTS can_publish JSONB DEFAULT '{"news":true,"gallery":true,"vacancies":true,"reports":true}';

-- Phase 1 role baseline: superadmin, admin, staff
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'admin_profiles_role_check'
  ) THEN
    ALTER TABLE admin_profiles
      ADD CONSTRAINT admin_profiles_role_check
      CHECK (role IN ('superadmin', 'admin', 'staff'));
  END IF;
END $$;

-- Backfill missing values for existing rows
UPDATE admin_profiles
SET role = 'admin'
WHERE role IS NULL OR role NOT IN ('superadmin', 'admin', 'staff');

UPDATE admin_profiles
SET permissions = '{"admissions":{"view":true,"update":true,"export":true},"jobs":{"view":true,"update":true,"export":true,"manage_vacancies":true},"news":{"view":true,"create":true,"edit":true,"publish":true,"delete":true},"gallery":{"view":true,"upload":true,"edit":true,"publish":true,"delete":true},"reports":{"view":true,"submit":false,"review":true,"approve":true},"settings":{"own":true,"manage_staff":false,"manage_roles":false}}'::jsonb
WHERE permissions IS NULL;

UPDATE admin_profiles
SET can_publish = '{"news":true,"gallery":true,"vacancies":true,"reports":true}'::jsonb
WHERE can_publish IS NULL;

-- Seed the primary superadmin profile from an existing Supabase Auth user.
-- This is idempotent and will update the role if the account already has a profile.
INSERT INTO admin_profiles (id, email, role, preferences, permissions, can_publish)
SELECT
  au.id,
  au.email,
  'superadmin',
  '{"admissions":true,"jobs":true,"news":true,"gallery":true}'::jsonb,
  '{"admissions":{"view":true,"update":true,"export":true},"jobs":{"view":true,"update":true,"export":true,"manage_vacancies":true},"news":{"view":true,"create":true,"edit":true,"publish":true,"delete":true},"gallery":{"view":true,"upload":true,"edit":true,"publish":true,"delete":true},"reports":{"view":true,"submit":true,"review":true,"approve":true},"settings":{"own":true,"manage_staff":true,"manage_roles":true}}'::jsonb,
  '{"news":true,"gallery":true,"vacancies":true,"reports":true}'::jsonb
FROM auth.users au
WHERE lower(au.email) = 'shad@admin.com'
ON CONFLICT (id) DO UPDATE
SET email = EXCLUDED.email,
    role = 'superadmin',
    preferences = EXCLUDED.preferences,
    permissions = EXCLUDED.permissions,
    can_publish = EXCLUDED.can_publish,
    updated_at = NOW();

ALTER TABLE admin_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated can read own admin profile" ON admin_profiles;
DROP POLICY IF EXISTS "Authenticated can insert own admin profile" ON admin_profiles;
DROP POLICY IF EXISTS "Authenticated can update own admin profile" ON admin_profiles;

-- Authenticated users can read their own admin profile
CREATE POLICY "Authenticated can read own admin profile" ON admin_profiles
  FOR SELECT TO authenticated USING (auth.uid() = id);

-- Authenticated users can insert their own admin profile
CREATE POLICY "Authenticated can insert own admin profile" ON admin_profiles
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);

-- Authenticated users can update their own admin profile
CREATE POLICY "Authenticated can update own admin profile" ON admin_profiles
  FOR UPDATE TO authenticated USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- ──────────────────────────────────────────────────────────────
-- ADMIN DASHBOARD — Stage 7: Positions & Staff Roles (Phase 2)
-- Run in Supabase SQL Editor
-- ──────────────────────────────────────────────────────────────

-- Helper: identify admins/superadmins from admin_profiles
CREATE OR REPLACE FUNCTION public.is_admin_or_superadmin(user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM admin_profiles ap
    WHERE ap.id = user_id
      AND ap.role IN ('admin', 'superadmin')
  );
$$;

-- Position templates with permission matrix
CREATE TABLE IF NOT EXISTS staff_positions (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name         TEXT        NOT NULL UNIQUE,
  description  TEXT,
  permissions  JSONB       NOT NULL DEFAULT '{"admissions":{"view":false,"update":false,"export":false},"jobs":{"view":false,"update":false,"export":false,"manage_vacancies":false},"news":{"view":true,"create":true,"edit":true,"publish":false,"delete":false},"gallery":{"view":true,"upload":true,"edit":true,"publish":false,"delete":false},"reports":{"view":true,"submit":true,"review":false,"approve":false},"settings":{"own":true,"manage_staff":false,"manage_roles":false}}',
  can_publish  JSONB       NOT NULL DEFAULT '{"news":false,"gallery":false,"vacancies":false,"reports":false}',
  active       BOOLEAN     NOT NULL DEFAULT true,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE staff_positions ENABLE ROW LEVEL SECURITY;

-- Staff user profile and assignment
CREATE TABLE IF NOT EXISTS staff_profiles (
  id                     uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email                  TEXT        NOT NULL,
  display_name           TEXT,
  role                   TEXT        NOT NULL DEFAULT 'staff',
  position_id            uuid REFERENCES staff_positions(id) ON DELETE SET NULL,
  permissions_override   JSONB,
  can_publish_override   JSONB,
  must_change_password   BOOLEAN     NOT NULL DEFAULT true,
  status                 TEXT        NOT NULL DEFAULT 'active',
  created_by             uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  temp_password_set_at   TIMESTAMPTZ,
  last_password_change_at TIMESTAMPTZ,
  created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT staff_profiles_role_check CHECK (role IN ('staff', 'admin', 'superadmin')),
  CONSTRAINT staff_profiles_status_check CHECK (status IN ('active', 'suspended', 'inactive'))
);

ALTER TABLE staff_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated can read staff positions" ON staff_positions;
DROP POLICY IF EXISTS "Admin can insert staff positions" ON staff_positions;
DROP POLICY IF EXISTS "Admin can update staff positions" ON staff_positions;
DROP POLICY IF EXISTS "Admin can delete staff positions" ON staff_positions;

DROP POLICY IF EXISTS "Users can read own staff profile" ON staff_profiles;
DROP POLICY IF EXISTS "Admin can read all staff profiles" ON staff_profiles;
DROP POLICY IF EXISTS "Admin can insert staff profiles" ON staff_profiles;
DROP POLICY IF EXISTS "Users can update own staff profile" ON staff_profiles;
DROP POLICY IF EXISTS "Admin can update all staff profiles" ON staff_profiles;
DROP POLICY IF EXISTS "Admin can delete staff profiles" ON staff_profiles;

-- staff_positions policies
CREATE POLICY "Authenticated can read staff positions" ON staff_positions
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Admin can insert staff positions" ON staff_positions
  FOR INSERT TO authenticated WITH CHECK (public.is_admin_or_superadmin(auth.uid()));

CREATE POLICY "Admin can update staff positions" ON staff_positions
  FOR UPDATE TO authenticated
  USING (public.is_admin_or_superadmin(auth.uid()))
  WITH CHECK (public.is_admin_or_superadmin(auth.uid()));

CREATE POLICY "Admin can delete staff positions" ON staff_positions
  FOR DELETE TO authenticated USING (public.is_admin_or_superadmin(auth.uid()));

-- staff_profiles policies
CREATE POLICY "Users can read own staff profile" ON staff_profiles
  FOR SELECT TO authenticated USING (auth.uid() = id);

CREATE POLICY "Admin can read all staff profiles" ON staff_profiles
  FOR SELECT TO authenticated USING (public.is_admin_or_superadmin(auth.uid()));

CREATE POLICY "Admin can insert staff profiles" ON staff_profiles
  FOR INSERT TO authenticated WITH CHECK (public.is_admin_or_superadmin(auth.uid()));

CREATE POLICY "Users can update own staff profile" ON staff_profiles
  FOR UPDATE TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Admin can update all staff profiles" ON staff_profiles
  FOR UPDATE TO authenticated
  USING (public.is_admin_or_superadmin(auth.uid()))
  WITH CHECK (public.is_admin_or_superadmin(auth.uid()));

CREATE POLICY "Admin can delete staff profiles" ON staff_profiles
  FOR DELETE TO authenticated USING (public.is_admin_or_superadmin(auth.uid()));

-- Seed baseline staff position templates
INSERT INTO staff_positions (name, description, permissions, can_publish)
VALUES
  (
    'Class Teacher',
    'Default teacher role with report submission and draft content capabilities.',
    '{"admissions":{"view":false,"update":false,"export":false},"jobs":{"view":false,"update":false,"export":false,"manage_vacancies":false},"news":{"view":true,"create":true,"edit":true,"publish":false,"delete":false},"gallery":{"view":true,"upload":true,"edit":true,"publish":false,"delete":false},"reports":{"view":true,"submit":true,"review":false,"approve":false},"settings":{"own":true,"manage_staff":false,"manage_roles":false}}',
    '{"news":false,"gallery":false,"vacancies":false,"reports":false}'
  ),
  (
    'Admissions Officer',
    'Admissions and enquiry workflow management.',
    '{"admissions":{"view":true,"update":true,"export":true},"jobs":{"view":false,"update":false,"export":false,"manage_vacancies":false},"news":{"view":false,"create":false,"edit":false,"publish":false,"delete":false},"gallery":{"view":false,"upload":false,"edit":false,"publish":false,"delete":false},"reports":{"view":true,"submit":false,"review":true,"approve":false},"settings":{"own":true,"manage_staff":false,"manage_roles":false}}',
    '{"news":false,"gallery":false,"vacancies":false,"reports":false}'
  ),
  (
    'Content Editor',
    'Content creation role with publishing restricted.',
    '{"admissions":{"view":false,"update":false,"export":false},"jobs":{"view":false,"update":false,"export":false,"manage_vacancies":false},"news":{"view":true,"create":true,"edit":true,"publish":false,"delete":false},"gallery":{"view":true,"upload":true,"edit":true,"publish":false,"delete":false},"reports":{"view":false,"submit":false,"review":false,"approve":false},"settings":{"own":true,"manage_staff":false,"manage_roles":false}}',
    '{"news":false,"gallery":false,"vacancies":false,"reports":false}'
  )
ON CONFLICT (name) DO NOTHING;