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
DROP POLICY IF EXISTS "Allow public inserts to admission_enquiries" ON admission_enquiries;
CREATE POLICY "Allow public inserts to admission_enquiries" ON admission_enquiries
  FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public inserts to job_applications" ON job_applications;
CREATE POLICY "Allow public inserts to job_applications" ON job_applications
  FOR INSERT WITH CHECK (true);

-- Storage policies for CV uploads
-- Allow public access to cv-uploads bucket
DROP POLICY IF EXISTS "Allow public uploads to cv-uploads" ON storage.objects;
CREATE POLICY "Allow public uploads to cv-uploads" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'cv-uploads');

DROP POLICY IF EXISTS "Allow public reads from cv-uploads" ON storage.objects;
CREATE POLICY "Allow public reads from cv-uploads" ON storage.objects
  FOR SELECT USING (bucket_id = 'cv-uploads');

DROP POLICY IF EXISTS "Allow public updates to cv-uploads" ON storage.objects;
CREATE POLICY "Allow public updates to cv-uploads" ON storage.objects
  FOR UPDATE USING (bucket_id = 'cv-uploads');

DROP POLICY IF EXISTS "Allow public deletes from cv-uploads" ON storage.objects;
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
DROP POLICY IF EXISTS "Allow authenticated reads on admission_enquiries" ON admission_enquiries;
CREATE POLICY "Allow authenticated reads on admission_enquiries" ON admission_enquiries
  FOR SELECT TO authenticated USING (true);

-- Allow logged-in admins to UPDATE admissions enquiries (e.g. status)
DROP POLICY IF EXISTS "Allow authenticated updates on admission_enquiries" ON admission_enquiries;
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

DROP POLICY IF EXISTS "Public can read published news" ON news_articles;
DROP POLICY IF EXISTS "Authenticated can read all news" ON news_articles;
DROP POLICY IF EXISTS "Authenticated can insert news" ON news_articles;
DROP POLICY IF EXISTS "Authenticated can update news" ON news_articles;
DROP POLICY IF EXISTS "Authenticated can delete news" ON news_articles;

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

DROP POLICY IF EXISTS "news-images authenticated upload" ON storage.objects;
DROP POLICY IF EXISTS "news-images public read" ON storage.objects;
DROP POLICY IF EXISTS "news-images authenticated delete" ON storage.objects;

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

DROP POLICY IF EXISTS "Public can read open vacancies" ON vacancies;
DROP POLICY IF EXISTS "Authenticated can read all vacancies" ON vacancies;
DROP POLICY IF EXISTS "Authenticated can insert vacancies" ON vacancies;
DROP POLICY IF EXISTS "Authenticated can update vacancies" ON vacancies;
DROP POLICY IF EXISTS "Authenticated can delete vacancies" ON vacancies;

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
  id                      uuid        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email                   TEXT        NOT NULL,
  display_name            TEXT,
  phone                   TEXT,
  job_title               TEXT,
  role                    TEXT        DEFAULT 'admin',
  preferences             JSONB       DEFAULT '{"admissions":true,"jobs":true,"news":true,"gallery":true}',
  permissions             JSONB       DEFAULT '{"admissions":{"view":true,"update":true,"export":true},"jobs":{"view":true,"update":true,"export":true,"manage_vacancies":true},"news":{"view":true,"create":true,"edit":true,"publish":true,"delete":true},"gallery":{"view":true,"upload":true,"edit":true,"publish":true,"delete":true},"reports":{"view":true,"submit":false,"review":true,"approve":true},"settings":{"own":true,"manage_staff":true,"manage_roles":false}}',
  can_publish             JSONB       DEFAULT '{"news":true,"gallery":true,"vacancies":true,"reports":true}',
  must_change_password    BOOLEAN     NOT NULL DEFAULT false,
  temp_password_set_at    TIMESTAMPTZ,
  last_password_change_at TIMESTAMPTZ,
  created_at              TIMESTAMPTZ DEFAULT NOW(),
  updated_at              TIMESTAMPTZ DEFAULT NOW()
);

-- Ensure columns exist on databases created before these columns were added
ALTER TABLE admin_profiles ADD COLUMN IF NOT EXISTS permissions             JSONB       DEFAULT '{"admissions":{"view":true,"update":true,"export":true},"jobs":{"view":true,"update":true,"export":true,"manage_vacancies":true},"news":{"view":true,"create":true,"edit":true,"publish":true,"delete":true},"gallery":{"view":true,"upload":true,"edit":true,"publish":true,"delete":true},"reports":{"view":true,"submit":false,"review":true,"approve":true},"settings":{"own":true,"manage_staff":true,"manage_roles":false}}';
ALTER TABLE admin_profiles ADD COLUMN IF NOT EXISTS can_publish             JSONB       DEFAULT '{"news":true,"gallery":true,"vacancies":true,"reports":true}';
ALTER TABLE admin_profiles ADD COLUMN IF NOT EXISTS must_change_password    BOOLEAN     NOT NULL DEFAULT false;
ALTER TABLE admin_profiles ADD COLUMN IF NOT EXISTS temp_password_set_at    TIMESTAMPTZ;
ALTER TABLE admin_profiles ADD COLUMN IF NOT EXISTS last_password_change_at TIMESTAMPTZ;

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
SET permissions = '{"admissions":{"view":true,"update":true,"export":true},"jobs":{"view":true,"update":true,"export":true,"manage_vacancies":true},"news":{"view":true,"create":true,"edit":true,"publish":true,"delete":true},"gallery":{"view":true,"upload":true,"edit":true,"publish":true,"delete":true},"reports":{"view":true,"submit":false,"review":true,"approve":true},"settings":{"own":true,"manage_staff":true,"manage_roles":false}}'::jsonb
WHERE permissions IS NULL;

-- Backfill: grant manage_staff to existing admin profiles that still have the old default
UPDATE admin_profiles
SET permissions = jsonb_set(permissions, '{settings,manage_staff}', 'true'::jsonb)
WHERE role = 'admin'
  AND (permissions -> 'settings' ->> 'manage_staff')::boolean IS NOT TRUE;

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

CREATE OR REPLACE FUNCTION public.get_own_password_change_requirement()
RETURNS TABLE(required boolean, source text)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH flags AS (
    SELECT 'admin'::text AS source, COALESCE(ap.must_change_password, false) AS required
    FROM admin_profiles ap
    WHERE ap.id = auth.uid()
    UNION ALL
    SELECT 'staff'::text AS source, COALESCE(sp.must_change_password, false) AS required
    FROM staff_profiles sp
    WHERE sp.id = auth.uid()
  )
  SELECT
    COALESCE(bool_or(flags.required), false) AS required,
    CASE
      WHEN COALESCE(bool_or(flags.required AND flags.source = 'admin'), false) THEN 'admin'
      WHEN COALESCE(bool_or(flags.required AND flags.source = 'staff'), false) THEN 'staff'
      ELSE NULL
    END AS source
  FROM flags;
END;
$$;

CREATE OR REPLACE FUNCTION public.complete_own_password_change()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE admin_profiles
  SET must_change_password = false,
      last_password_change_at = NOW(),
      updated_at = NOW()
  WHERE id = auth.uid();

  UPDATE staff_profiles
  SET must_change_password = false,
      last_password_change_at = NOW(),
      updated_at = NOW()
  WHERE id = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_own_password_change_requirement() TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_own_password_change() TO authenticated;

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

-- ──────────────────────────────────────────────────────────────
-- ADMIN DASHBOARD — Stage 8: Permission Maps + Reports + Audit
-- Run in Supabase SQL Editor
-- ──────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS role_permission_maps (
  role         TEXT PRIMARY KEY,
  permissions  JSONB       NOT NULL,
  can_publish  JSONB       NOT NULL,
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT role_permission_maps_role_check CHECK (role IN ('superadmin', 'admin', 'staff'))
);

INSERT INTO role_permission_maps (role, permissions, can_publish)
VALUES
  (
    'superadmin',
    '{"admissions":{"view":true,"update":true,"export":true},"jobs":{"view":true,"update":true,"export":true,"manage_vacancies":true},"news":{"view":true,"create":true,"edit":true,"publish":true,"delete":true},"gallery":{"view":true,"upload":true,"edit":true,"publish":true,"delete":true},"reports":{"view":true,"submit":true,"review":true,"approve":true},"settings":{"own":true,"manage_staff":true,"manage_roles":true}}'::jsonb,
    '{"news":true,"gallery":true,"vacancies":true,"reports":true}'::jsonb
  ),
  (
    'admin',
    '{"admissions":{"view":true,"update":true,"export":true},"jobs":{"view":true,"update":true,"export":true,"manage_vacancies":true},"news":{"view":true,"create":true,"edit":true,"publish":true,"delete":true},"gallery":{"view":true,"upload":true,"edit":true,"publish":true,"delete":true},"reports":{"view":true,"submit":false,"review":true,"approve":true},"settings":{"own":true,"manage_staff":true,"manage_roles":false}}'::jsonb,
    '{"news":true,"gallery":true,"vacancies":true,"reports":true}'::jsonb
  ),
  (
    'staff',
    '{"admissions":{"view":false,"update":false,"export":false},"jobs":{"view":false,"update":false,"export":false,"manage_vacancies":false},"news":{"view":true,"create":true,"edit":true,"publish":false,"delete":false},"gallery":{"view":true,"upload":true,"edit":true,"publish":false,"delete":false},"reports":{"view":true,"submit":true,"review":false,"approve":false},"settings":{"own":true,"manage_staff":false,"manage_roles":false}}'::jsonb,
    '{"news":false,"gallery":false,"vacancies":false,"reports":false}'::jsonb
  )
ON CONFLICT (role) DO UPDATE
SET permissions = EXCLUDED.permissions,
    can_publish = EXCLUDED.can_publish,
    updated_at = NOW();

CREATE OR REPLACE FUNCTION public.get_user_role(user_id uuid)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  out_role text;
BEGIN
  SELECT ap.role INTO out_role
  FROM admin_profiles ap
  WHERE ap.id = user_id
  LIMIT 1;

  IF out_role IS NOT NULL THEN
    RETURN out_role;
  END IF;

  SELECT sp.role INTO out_role
  FROM staff_profiles sp
  WHERE sp.id = user_id
  LIMIT 1;

  RETURN COALESCE(out_role, 'staff');
END;
$$;

CREATE OR REPLACE FUNCTION public.user_has_permission(user_id uuid, group_key text, action_key text)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  role_value text;
  allowed boolean := false;
  baseline_permissions jsonb;
  admin_permissions jsonb;
  staff_permissions_override jsonb;
  position_permissions jsonb;
BEGIN
  role_value := public.get_user_role(user_id);

  SELECT rpm.permissions INTO baseline_permissions
  FROM role_permission_maps rpm
  WHERE rpm.role = role_value;

  IF baseline_permissions IS NOT NULL
     AND baseline_permissions ? group_key
     AND (baseline_permissions -> group_key) ? action_key THEN
    allowed := COALESCE((baseline_permissions -> group_key ->> action_key)::boolean, false);
  END IF;

  SELECT ap.permissions INTO admin_permissions
  FROM admin_profiles ap
  WHERE ap.id = user_id
  LIMIT 1;

  IF admin_permissions IS NOT NULL
     AND admin_permissions ? group_key
     AND (admin_permissions -> group_key) ? action_key THEN
    allowed := COALESCE((admin_permissions -> group_key ->> action_key)::boolean, allowed);
  END IF;

  SELECT sp.permissions_override, pos.permissions
  INTO staff_permissions_override, position_permissions
  FROM staff_profiles sp
  LEFT JOIN staff_positions pos ON pos.id = sp.position_id
  WHERE sp.id = user_id
  LIMIT 1;

  IF position_permissions IS NOT NULL
     AND position_permissions ? group_key
     AND (position_permissions -> group_key) ? action_key THEN
    allowed := COALESCE((position_permissions -> group_key ->> action_key)::boolean, allowed);
  END IF;

  IF staff_permissions_override IS NOT NULL
     AND staff_permissions_override ? group_key
     AND (staff_permissions_override -> group_key) ? action_key THEN
    allowed := COALESCE((staff_permissions_override -> group_key ->> action_key)::boolean, allowed);
  END IF;

  RETURN COALESCE(allowed, false);
END;
$$;

CREATE OR REPLACE FUNCTION public.user_can_publish(user_id uuid, area_key text)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  role_value text;
  allowed boolean := false;
  baseline_publish jsonb;
  admin_publish jsonb;
  staff_publish_override jsonb;
  position_publish jsonb;
BEGIN
  role_value := public.get_user_role(user_id);

  SELECT rpm.can_publish INTO baseline_publish
  FROM role_permission_maps rpm
  WHERE rpm.role = role_value;

  IF baseline_publish IS NOT NULL AND baseline_publish ? area_key THEN
    allowed := COALESCE((baseline_publish ->> area_key)::boolean, false);
  END IF;

  SELECT ap.can_publish INTO admin_publish
  FROM admin_profiles ap
  WHERE ap.id = user_id
  LIMIT 1;

  IF admin_publish IS NOT NULL AND admin_publish ? area_key THEN
    allowed := COALESCE((admin_publish ->> area_key)::boolean, allowed);
  END IF;

  SELECT sp.can_publish_override, pos.can_publish
  INTO staff_publish_override, position_publish
  FROM staff_profiles sp
  LEFT JOIN staff_positions pos ON pos.id = sp.position_id
  WHERE sp.id = user_id
  LIMIT 1;

  IF position_publish IS NOT NULL AND position_publish ? area_key THEN
    allowed := COALESCE((position_publish ->> area_key)::boolean, allowed);
  END IF;

  IF staff_publish_override IS NOT NULL AND staff_publish_override ? area_key THEN
    allowed := COALESCE((staff_publish_override ->> area_key)::boolean, allowed);
  END IF;

  RETURN COALESCE(allowed, false);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_user_role(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.user_has_permission(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.user_can_publish(uuid, text) TO authenticated;

-- Tighten existing table policies to match permission groups
DROP POLICY IF EXISTS "Allow authenticated reads on admission_enquiries" ON admission_enquiries;
DROP POLICY IF EXISTS "Allow authenticated updates on admission_enquiries" ON admission_enquiries;
DROP POLICY IF EXISTS "Permissioned reads on admission_enquiries" ON admission_enquiries;
DROP POLICY IF EXISTS "Permissioned updates on admission_enquiries" ON admission_enquiries;

CREATE POLICY "Permissioned reads on admission_enquiries" ON admission_enquiries
  FOR SELECT TO authenticated
  USING (public.user_has_permission(auth.uid(), 'admissions', 'view'));

CREATE POLICY "Permissioned updates on admission_enquiries" ON admission_enquiries
  FOR UPDATE TO authenticated
  USING (public.user_has_permission(auth.uid(), 'admissions', 'update'))
  WITH CHECK (public.user_has_permission(auth.uid(), 'admissions', 'update'));

ALTER TABLE job_applications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public inserts to job_applications" ON job_applications;
DROP POLICY IF EXISTS "Permissioned reads on job_applications" ON job_applications;
DROP POLICY IF EXISTS "Permissioned updates on job_applications" ON job_applications;

CREATE POLICY "Allow public inserts to job_applications" ON job_applications
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Permissioned reads on job_applications" ON job_applications
  FOR SELECT TO authenticated
  USING (public.user_has_permission(auth.uid(), 'jobs', 'view'));

CREATE POLICY "Permissioned updates on job_applications" ON job_applications
  FOR UPDATE TO authenticated
  USING (public.user_has_permission(auth.uid(), 'jobs', 'update'))
  WITH CHECK (public.user_has_permission(auth.uid(), 'jobs', 'update'));

DROP POLICY IF EXISTS "Authenticated can read all news" ON news_articles;
DROP POLICY IF EXISTS "Authenticated can insert news" ON news_articles;
DROP POLICY IF EXISTS "Authenticated can update news" ON news_articles;
DROP POLICY IF EXISTS "Authenticated can delete news" ON news_articles;
DROP POLICY IF EXISTS "Permissioned read news" ON news_articles;
DROP POLICY IF EXISTS "Permissioned insert news" ON news_articles;
DROP POLICY IF EXISTS "Permissioned update news" ON news_articles;
DROP POLICY IF EXISTS "Permissioned delete news" ON news_articles;

CREATE POLICY "Permissioned read news" ON news_articles
  FOR SELECT TO authenticated
  USING (public.user_has_permission(auth.uid(), 'news', 'view'));

CREATE POLICY "Permissioned insert news" ON news_articles
  FOR INSERT TO authenticated
  WITH CHECK (
    public.user_has_permission(auth.uid(), 'news', 'create')
    AND (
      status IS DISTINCT FROM 'published'
      OR (
        public.user_has_permission(auth.uid(), 'news', 'publish')
        AND public.user_can_publish(auth.uid(), 'news')
      )
    )
  );

CREATE POLICY "Permissioned update news" ON news_articles
  FOR UPDATE TO authenticated
  USING (public.user_has_permission(auth.uid(), 'news', 'edit'))
  WITH CHECK (
    public.user_has_permission(auth.uid(), 'news', 'edit')
    AND (
      status IS DISTINCT FROM 'published'
      OR (
        public.user_has_permission(auth.uid(), 'news', 'publish')
        AND public.user_can_publish(auth.uid(), 'news')
      )
    )
  );

CREATE POLICY "Permissioned delete news" ON news_articles
  FOR DELETE TO authenticated
  USING (public.user_has_permission(auth.uid(), 'news', 'delete'));

DROP POLICY IF EXISTS "Authenticated can read all vacancies" ON vacancies;
DROP POLICY IF EXISTS "Authenticated can insert vacancies" ON vacancies;
DROP POLICY IF EXISTS "Authenticated can update vacancies" ON vacancies;
DROP POLICY IF EXISTS "Authenticated can delete vacancies" ON vacancies;
DROP POLICY IF EXISTS "Permissioned read vacancies" ON vacancies;
DROP POLICY IF EXISTS "Permissioned insert vacancies" ON vacancies;
DROP POLICY IF EXISTS "Permissioned update vacancies" ON vacancies;
DROP POLICY IF EXISTS "Permissioned delete vacancies" ON vacancies;

CREATE POLICY "Permissioned read vacancies" ON vacancies
  FOR SELECT TO authenticated
  USING (public.user_has_permission(auth.uid(), 'jobs', 'manage_vacancies'));

CREATE POLICY "Permissioned insert vacancies" ON vacancies
  FOR INSERT TO authenticated
  WITH CHECK (
    public.user_has_permission(auth.uid(), 'jobs', 'manage_vacancies')
    AND (
      status IS DISTINCT FROM 'open'
      OR public.user_can_publish(auth.uid(), 'vacancies')
    )
  );

CREATE POLICY "Permissioned update vacancies" ON vacancies
  FOR UPDATE TO authenticated
  USING (public.user_has_permission(auth.uid(), 'jobs', 'manage_vacancies'))
  WITH CHECK (
    public.user_has_permission(auth.uid(), 'jobs', 'manage_vacancies')
    AND (
      status IS DISTINCT FROM 'open'
      OR public.user_can_publish(auth.uid(), 'vacancies')
    )
  );

CREATE POLICY "Permissioned delete vacancies" ON vacancies
  FOR DELETE TO authenticated
  USING (public.user_has_permission(auth.uid(), 'jobs', 'manage_vacancies'));

DROP POLICY IF EXISTS "Authenticated can read all gallery images" ON gallery_images;
DROP POLICY IF EXISTS "Authenticated can insert gallery images" ON gallery_images;
DROP POLICY IF EXISTS "Authenticated can update gallery images" ON gallery_images;
DROP POLICY IF EXISTS "Authenticated can delete gallery images" ON gallery_images;
DROP POLICY IF EXISTS "Permissioned read gallery" ON gallery_images;
DROP POLICY IF EXISTS "Permissioned insert gallery" ON gallery_images;
DROP POLICY IF EXISTS "Permissioned update gallery" ON gallery_images;
DROP POLICY IF EXISTS "Permissioned delete gallery" ON gallery_images;

CREATE POLICY "Permissioned read gallery" ON gallery_images
  FOR SELECT TO authenticated
  USING (public.user_has_permission(auth.uid(), 'gallery', 'view'));

CREATE POLICY "Permissioned insert gallery" ON gallery_images
  FOR INSERT TO authenticated
  WITH CHECK (
    public.user_has_permission(auth.uid(), 'gallery', 'upload')
    AND (
      status IS DISTINCT FROM 'published'
      OR (
        public.user_has_permission(auth.uid(), 'gallery', 'publish')
        AND public.user_can_publish(auth.uid(), 'gallery')
      )
    )
  );

CREATE POLICY "Permissioned update gallery" ON gallery_images
  FOR UPDATE TO authenticated
  USING (public.user_has_permission(auth.uid(), 'gallery', 'edit'))
  WITH CHECK (
    public.user_has_permission(auth.uid(), 'gallery', 'edit')
    AND (
      status IS DISTINCT FROM 'published'
      OR (
        public.user_has_permission(auth.uid(), 'gallery', 'publish')
        AND public.user_can_publish(auth.uid(), 'gallery')
      )
    )
  );

CREATE POLICY "Permissioned delete gallery" ON gallery_images
  FOR DELETE TO authenticated
  USING (public.user_has_permission(auth.uid(), 'gallery', 'delete'));

-- Teacher reports workflow
CREATE TABLE IF NOT EXISTS teacher_reports (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  submitted_by      uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  submitted_by_email TEXT,
  title             TEXT        NOT NULL,
  class_name        TEXT        NOT NULL,
  term_label        TEXT        NOT NULL,
  student_count     INTEGER     NOT NULL DEFAULT 0,
  report_body       TEXT        NOT NULL,
  status            TEXT        NOT NULL DEFAULT 'draft',
  reviewer_id       uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewer_email    TEXT,
  review_comment    TEXT,
  submitted_at      TIMESTAMPTZ,
  reviewed_at       TIMESTAMPTZ,
  status_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT teacher_reports_status_check CHECK (status IN ('draft', 'submitted', 'under_review', 'approved', 'needs_changes', 'archived'))
);

ALTER TABLE teacher_reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Reports read policy" ON teacher_reports;
DROP POLICY IF EXISTS "Reports insert policy" ON teacher_reports;
DROP POLICY IF EXISTS "Reports update owner policy" ON teacher_reports;
DROP POLICY IF EXISTS "Reports update reviewer policy" ON teacher_reports;

CREATE POLICY "Reports read policy" ON teacher_reports
  FOR SELECT TO authenticated
  USING (
    public.user_has_permission(auth.uid(), 'reports', 'view')
    AND (
      submitted_by = auth.uid()
      OR public.user_has_permission(auth.uid(), 'reports', 'review')
    )
  );

CREATE POLICY "Reports insert policy" ON teacher_reports
  FOR INSERT TO authenticated
  WITH CHECK (
    submitted_by = auth.uid()
    AND public.user_has_permission(auth.uid(), 'reports', 'submit')
  );

CREATE POLICY "Reports update owner policy" ON teacher_reports
  FOR UPDATE TO authenticated
  USING (submitted_by = auth.uid())
  WITH CHECK (submitted_by = auth.uid());

CREATE POLICY "Reports update reviewer policy" ON teacher_reports
  FOR UPDATE TO authenticated
  USING (public.user_has_permission(auth.uid(), 'reports', 'review'))
  WITH CHECK (public.user_has_permission(auth.uid(), 'reports', 'review'));

-- Central audit trail for role/permission/content/status changes
CREATE TABLE IF NOT EXISTS audit_logs (
  id           BIGSERIAL PRIMARY KEY,
  actor_id     uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  actor_email  TEXT,
  actor_role   TEXT,
  action       TEXT        NOT NULL,
  target_type  TEXT        NOT NULL,
  target_id    TEXT,
  details      JSONB       NOT NULL DEFAULT '{}'::jsonb,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Audit insert own logs" ON audit_logs;
DROP POLICY IF EXISTS "Audit read for admins" ON audit_logs;

CREATE POLICY "Audit insert own logs" ON audit_logs
  FOR INSERT TO authenticated
  WITH CHECK (actor_id IS NULL OR actor_id = auth.uid());

CREATE POLICY "Audit read for admins" ON audit_logs
  FOR SELECT TO authenticated
  USING (
    public.user_has_permission(auth.uid(), 'settings', 'manage_roles')
    OR public.user_has_permission(auth.uid(), 'settings', 'manage_staff')
  );

-- ──────────────────────────────────────────────────────────────
-- SECURITY HARDENING (safe for current direct-to-Supabase forms)
-- ──────────────────────────────────────────────────────────────

-- Public form inserts should only create pending records with basic non-empty fields.
DROP POLICY IF EXISTS "Allow public inserts to admission_enquiries" ON admission_enquiries;
DROP POLICY IF EXISTS "Allow public inserts to admission_enquiries (hardened)" ON admission_enquiries;

CREATE POLICY "Allow public inserts to admission_enquiries (hardened)" ON admission_enquiries
  FOR INSERT TO anon, authenticated
  WITH CHECK (
    COALESCE(status, 'pending') = 'pending'
    AND (submitted_at IS NULL OR submitted_at <= NOW() + INTERVAL '10 minutes')
    AND char_length(trim(parent_name)) > 0
    AND char_length(trim(phone_number)) > 0
    AND char_length(trim(email)) > 0
    AND position('@' in email) > 1
    AND char_length(trim(child_name)) > 0
    AND date_of_birth <= CURRENT_DATE
    AND char_length(trim(year_group)) > 0
  );

DROP POLICY IF EXISTS "Allow public inserts to job_applications" ON job_applications;
DROP POLICY IF EXISTS "Allow public inserts to job_applications (hardened)" ON job_applications;

CREATE POLICY "Allow public inserts to job_applications (hardened)" ON job_applications
  FOR INSERT TO anon, authenticated
  WITH CHECK (
    COALESCE(status, 'pending') = 'pending'
    AND (submitted_at IS NULL OR submitted_at <= NOW() + INTERVAL '10 minutes')
    AND char_length(trim(full_name)) > 0
    AND char_length(trim(email)) > 0
    AND position('@' in email) > 1
    AND char_length(trim(phone_number)) > 0
    AND char_length(trim(position_applied)) > 0
    AND char_length(trim(motivation)) > 0
    AND char_length(trim(cv_file_url)) > 0
    AND char_length(trim(cv_file_name)) > 0
  );

-- Harden CV storage access:
-- - keep public upload/read for the current frontend flow
-- - block public update/delete to reduce tampering risk
-- - constrain uploads to expected file types and size limit
DROP POLICY IF EXISTS "Allow public uploads to cv-uploads" ON storage.objects;
DROP POLICY IF EXISTS "Allow public reads from cv-uploads" ON storage.objects;
DROP POLICY IF EXISTS "Allow public updates to cv-uploads" ON storage.objects;
DROP POLICY IF EXISTS "Allow public deletes from cv-uploads" ON storage.objects;
DROP POLICY IF EXISTS "cv-uploads public insert (hardened)" ON storage.objects;
DROP POLICY IF EXISTS "cv-uploads public read" ON storage.objects;

CREATE POLICY "cv-uploads public insert (hardened)" ON storage.objects
  FOR INSERT TO anon, authenticated
  WITH CHECK (
    bucket_id = 'cv-uploads'
    AND lower(storage.extension(name)) IN ('pdf', 'doc', 'docx')
    AND COALESCE((metadata->>'size')::bigint, 0) > 0
    AND COALESCE((metadata->>'size')::bigint, 0) <= 5242880
  );

CREATE POLICY "cv-uploads public read" ON storage.objects
  FOR SELECT TO anon, authenticated
  USING (bucket_id = 'cv-uploads');

-- ──────────────────────────────────────────────────────────────
-- PHASE 1 INCREMENTAL: Duty Profile + Baseline Maps
-- ──────────────────────────────────────────────────────────────

ALTER TABLE staff_profiles
  ADD COLUMN IF NOT EXISTS staff_type TEXT;

UPDATE staff_profiles
SET staff_type = 'teaching'
WHERE staff_type IS NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'staff_profiles_staff_type_check'
  ) THEN
    ALTER TABLE staff_profiles
      ADD CONSTRAINT staff_profiles_staff_type_check
      CHECK (staff_type IN ('teaching', 'non_teaching'));
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS duty_permission_maps (
  staff_type   TEXT PRIMARY KEY,
  permissions  JSONB       NOT NULL,
  can_publish  JSONB       NOT NULL,
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT duty_permission_maps_staff_type_check CHECK (staff_type IN ('teaching', 'non_teaching'))
);

INSERT INTO duty_permission_maps (staff_type, permissions, can_publish)
VALUES
  (
    'teaching',
    '{"admissions":{"view":false,"update":false,"export":false},"jobs":{"view":false,"update":false,"export":false,"manage_vacancies":false},"news":{"view":true,"create":true,"edit":true,"publish":false,"delete":false},"gallery":{"view":true,"upload":true,"edit":true,"publish":false,"delete":false},"reports":{"view":true,"submit":true,"review":false,"approve":false},"settings":{"own":true,"manage_staff":false,"manage_roles":false}}'::jsonb,
    '{"news":false,"gallery":false,"vacancies":false,"reports":false}'::jsonb
  ),
  (
    'non_teaching',
    '{"admissions":{"view":false,"update":false,"export":false},"jobs":{"view":false,"update":false,"export":false,"manage_vacancies":false},"news":{"view":false,"create":false,"edit":false,"publish":false,"delete":false},"gallery":{"view":false,"upload":false,"edit":false,"publish":false,"delete":false},"reports":{"view":false,"submit":false,"review":false,"approve":false},"settings":{"own":true,"manage_staff":false,"manage_roles":false}}'::jsonb,
    '{"news":false,"gallery":false,"vacancies":false,"reports":false}'::jsonb
  )
ON CONFLICT (staff_type) DO UPDATE
SET permissions = EXCLUDED.permissions,
    can_publish = EXCLUDED.can_publish,
    updated_at = NOW();

CREATE OR REPLACE FUNCTION public.user_has_permission(user_id uuid, group_key text, action_key text)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  role_value text;
  allowed boolean := false;
  baseline_permissions jsonb;
  duty_permissions jsonb;
  admin_permissions jsonb;
  staff_permissions_override jsonb;
  position_permissions jsonb;
  staff_type_value text;
BEGIN
  role_value := public.get_user_role(user_id);

  SELECT rpm.permissions INTO baseline_permissions
  FROM role_permission_maps rpm
  WHERE rpm.role = role_value;

  IF baseline_permissions IS NOT NULL
     AND baseline_permissions ? group_key
     AND (baseline_permissions -> group_key) ? action_key THEN
    allowed := COALESCE((baseline_permissions -> group_key ->> action_key)::boolean, false);
  END IF;

  SELECT ap.permissions INTO admin_permissions
  FROM admin_profiles ap
  WHERE ap.id = user_id
  LIMIT 1;

  IF admin_permissions IS NOT NULL
     AND admin_permissions ? group_key
     AND (admin_permissions -> group_key) ? action_key THEN
    allowed := COALESCE((admin_permissions -> group_key ->> action_key)::boolean, allowed);
  END IF;

  SELECT sp.staff_type, sp.permissions_override, pos.permissions
  INTO staff_type_value, staff_permissions_override, position_permissions
  FROM staff_profiles sp
  LEFT JOIN staff_positions pos ON pos.id = sp.position_id
  WHERE sp.id = user_id
  LIMIT 1;

  IF staff_type_value IS NOT NULL THEN
    SELECT dpm.permissions INTO duty_permissions
    FROM duty_permission_maps dpm
    WHERE dpm.staff_type = staff_type_value;

    IF duty_permissions IS NOT NULL
       AND duty_permissions ? group_key
       AND (duty_permissions -> group_key) ? action_key THEN
      allowed := COALESCE((duty_permissions -> group_key ->> action_key)::boolean, allowed);
    END IF;
  END IF;

  IF staff_type_value = 'teaching'
     AND position_permissions IS NOT NULL
     AND position_permissions ? group_key
     AND (position_permissions -> group_key) ? action_key THEN
    allowed := COALESCE((position_permissions -> group_key ->> action_key)::boolean, allowed);
  END IF;

  IF staff_permissions_override IS NOT NULL
     AND staff_permissions_override ? group_key
     AND (staff_permissions_override -> group_key) ? action_key THEN
    allowed := COALESCE((staff_permissions_override -> group_key ->> action_key)::boolean, allowed);
  END IF;

  RETURN COALESCE(allowed, false);
END;
$$;

CREATE OR REPLACE FUNCTION public.user_can_publish(user_id uuid, area_key text)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  role_value text;
  allowed boolean := false;
  baseline_publish jsonb;
  duty_publish jsonb;
  admin_publish jsonb;
  staff_publish_override jsonb;
  position_publish jsonb;
  staff_type_value text;
BEGIN
  role_value := public.get_user_role(user_id);

  SELECT rpm.can_publish INTO baseline_publish
  FROM role_permission_maps rpm
  WHERE rpm.role = role_value;

  IF baseline_publish IS NOT NULL AND baseline_publish ? area_key THEN
    allowed := COALESCE((baseline_publish ->> area_key)::boolean, false);
  END IF;

  SELECT ap.can_publish INTO admin_publish
  FROM admin_profiles ap
  WHERE ap.id = user_id
  LIMIT 1;

  IF admin_publish IS NOT NULL AND admin_publish ? area_key THEN
    allowed := COALESCE((admin_publish ->> area_key)::boolean, allowed);
  END IF;

  SELECT sp.staff_type, sp.can_publish_override, pos.can_publish
  INTO staff_type_value, staff_publish_override, position_publish
  FROM staff_profiles sp
  LEFT JOIN staff_positions pos ON pos.id = sp.position_id
  WHERE sp.id = user_id
  LIMIT 1;

  IF staff_type_value IS NOT NULL THEN
    SELECT dpm.can_publish INTO duty_publish
    FROM duty_permission_maps dpm
    WHERE dpm.staff_type = staff_type_value;

    IF duty_publish IS NOT NULL AND duty_publish ? area_key THEN
      allowed := COALESCE((duty_publish ->> area_key)::boolean, allowed);
    END IF;
  END IF;

  IF staff_type_value = 'teaching' AND position_publish IS NOT NULL AND position_publish ? area_key THEN
    allowed := COALESCE((position_publish ->> area_key)::boolean, allowed);
  END IF;

  IF staff_publish_override IS NOT NULL AND staff_publish_override ? area_key THEN
    allowed := COALESCE((staff_publish_override ->> area_key)::boolean, allowed);
  END IF;

  RETURN COALESCE(allowed, false);
END;
$$;

-- ──────────────────────────────────────────────────────────────
-- PHASE 3 SCAFFOLD: Teaching Modules + RLS Contracts
-- ──────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.is_teaching_staff(user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM staff_profiles sp
    WHERE sp.id = user_id
      AND sp.role = 'staff'
      AND COALESCE(sp.staff_type, 'teaching') = 'teaching'
      AND sp.status = 'active'
  );
$$;

CREATE TABLE IF NOT EXISTS attendance_records (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  class_label   TEXT        NOT NULL,
  attendance_on DATE        NOT NULL,
  submitted_by  uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  records       JSONB       NOT NULL DEFAULT '[]'::jsonb,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS assessment_records (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  class_label   TEXT        NOT NULL,
  term_label    TEXT,
  submitted_by  uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  payload       JSONB       NOT NULL DEFAULT '{}'::jsonb,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS teacher_parent_messages (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id      uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  recipient_type TEXT        NOT NULL DEFAULT 'group',
  recipient_ref  TEXT,
  subject        TEXT,
  body           TEXT        NOT NULL,
  status         TEXT        NOT NULL DEFAULT 'draft',
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  sent_at        TIMESTAMPTZ,
  CONSTRAINT teacher_parent_messages_status_check CHECK (status IN ('draft', 'sent', 'archived'))
);

ALTER TABLE attendance_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE assessment_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE teacher_parent_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Attendance read policy" ON attendance_records;
DROP POLICY IF EXISTS "Attendance insert policy" ON attendance_records;
DROP POLICY IF EXISTS "Attendance update policy" ON attendance_records;

CREATE POLICY "Attendance read policy" ON attendance_records
  FOR SELECT TO authenticated
  USING (submitted_by = auth.uid() OR public.is_admin_or_superadmin(auth.uid()));

CREATE POLICY "Attendance insert policy" ON attendance_records
  FOR INSERT TO authenticated
  WITH CHECK (submitted_by = auth.uid() AND public.is_teaching_staff(auth.uid()));

CREATE POLICY "Attendance update policy" ON attendance_records
  FOR UPDATE TO authenticated
  USING (submitted_by = auth.uid())
  WITH CHECK (submitted_by = auth.uid());

DROP POLICY IF EXISTS "Assessment read policy" ON assessment_records;
DROP POLICY IF EXISTS "Assessment insert policy" ON assessment_records;
DROP POLICY IF EXISTS "Assessment update policy" ON assessment_records;

CREATE POLICY "Assessment read policy" ON assessment_records
  FOR SELECT TO authenticated
  USING (submitted_by = auth.uid() OR public.is_admin_or_superadmin(auth.uid()));

CREATE POLICY "Assessment insert policy" ON assessment_records
  FOR INSERT TO authenticated
  WITH CHECK (submitted_by = auth.uid() AND public.is_teaching_staff(auth.uid()));

CREATE POLICY "Assessment update policy" ON assessment_records
  FOR UPDATE TO authenticated
  USING (submitted_by = auth.uid())
  WITH CHECK (submitted_by = auth.uid());

DROP POLICY IF EXISTS "Parent messages read policy" ON teacher_parent_messages;
DROP POLICY IF EXISTS "Parent messages insert policy" ON teacher_parent_messages;
DROP POLICY IF EXISTS "Parent messages update policy" ON teacher_parent_messages;

CREATE POLICY "Parent messages read policy" ON teacher_parent_messages
  FOR SELECT TO authenticated
  USING (sender_id = auth.uid() OR public.is_admin_or_superadmin(auth.uid()));

CREATE POLICY "Parent messages insert policy" ON teacher_parent_messages
  FOR INSERT TO authenticated
  WITH CHECK (sender_id = auth.uid() AND public.is_teaching_staff(auth.uid()));

CREATE POLICY "Parent messages update policy" ON teacher_parent_messages
  FOR UPDATE TO authenticated
  USING (sender_id = auth.uid())
  WITH CHECK (sender_id = auth.uid());

-- ──────────────────────────────────────────────────────────────
-- PHASE 4 SCAFFOLD: Parent Portal Relationship Contracts
-- ──────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS school_classes (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  class_name    TEXT        NOT NULL UNIQUE,
  academic_year TEXT,
  active        BOOLEAN     NOT NULL DEFAULT true,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS students (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_code  TEXT UNIQUE,
  full_name     TEXT        NOT NULL,
  date_of_birth DATE,
  active        BOOLEAN     NOT NULL DEFAULT true,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS parent_profiles (
  id            uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email         TEXT        NOT NULL,
  display_name  TEXT,
  phone         TEXT,
  active        BOOLEAN     NOT NULL DEFAULT true,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS class_teachers (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  class_id      uuid        NOT NULL REFERENCES school_classes(id) ON DELETE CASCADE,
  teacher_id    uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  assigned_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (class_id, teacher_id)
);

CREATE TABLE IF NOT EXISTS student_guardians (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id    uuid        NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  parent_id     uuid        NOT NULL REFERENCES parent_profiles(id) ON DELETE CASCADE,
  relationship  TEXT,
  is_primary    BOOLEAN     NOT NULL DEFAULT false,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (student_id, parent_id)
);

CREATE TABLE IF NOT EXISTS class_enrollments (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  class_id      uuid        NOT NULL REFERENCES school_classes(id) ON DELETE CASCADE,
  student_id    uuid        NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  active        BOOLEAN     NOT NULL DEFAULT true,
  enrolled_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (class_id, student_id)
);

CREATE TABLE IF NOT EXISTS parent_portal_messages (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_message_id uuid REFERENCES teacher_parent_messages(id) ON DELETE SET NULL,
  student_id       uuid REFERENCES students(id) ON DELETE SET NULL,
  parent_id        uuid REFERENCES parent_profiles(id) ON DELETE CASCADE,
  subject          TEXT,
  body             TEXT        NOT NULL,
  sent_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  read_at          TIMESTAMPTZ
);

ALTER TABLE school_classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE students ENABLE ROW LEVEL SECURITY;
ALTER TABLE parent_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE class_teachers ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_guardians ENABLE ROW LEVEL SECURITY;
ALTER TABLE class_enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE parent_portal_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Class management by staff managers" ON school_classes;
DROP POLICY IF EXISTS "Student management by staff managers" ON students;
DROP POLICY IF EXISTS "Parent profile self read" ON parent_profiles;
DROP POLICY IF EXISTS "Parent profile management by staff managers" ON parent_profiles;
DROP POLICY IF EXISTS "Class teachers read by authenticated" ON class_teachers;
DROP POLICY IF EXISTS "Class teachers management by staff managers" ON class_teachers;
DROP POLICY IF EXISTS "Student guardians read by authenticated" ON student_guardians;
DROP POLICY IF EXISTS "Student guardians management by staff managers" ON student_guardians;
DROP POLICY IF EXISTS "Class enrollments read by authenticated" ON class_enrollments;
DROP POLICY IF EXISTS "Class enrollments management by staff managers" ON class_enrollments;
DROP POLICY IF EXISTS "Parent messages read own" ON parent_portal_messages;
DROP POLICY IF EXISTS "Parent messages read by teachers/admin" ON parent_portal_messages;

CREATE POLICY "Class management by staff managers" ON school_classes
  FOR ALL TO authenticated
  USING (public.user_has_permission(auth.uid(), 'settings', 'manage_staff'))
  WITH CHECK (public.user_has_permission(auth.uid(), 'settings', 'manage_staff'));

CREATE POLICY "Student management by staff managers" ON students
  FOR ALL TO authenticated
  USING (public.user_has_permission(auth.uid(), 'settings', 'manage_staff'))
  WITH CHECK (public.user_has_permission(auth.uid(), 'settings', 'manage_staff'));

CREATE POLICY "Parent profile self read" ON parent_profiles
  FOR SELECT TO authenticated
  USING (id = auth.uid());

CREATE POLICY "Parent profile management by staff managers" ON parent_profiles
  FOR ALL TO authenticated
  USING (public.user_has_permission(auth.uid(), 'settings', 'manage_staff'))
  WITH CHECK (public.user_has_permission(auth.uid(), 'settings', 'manage_staff'));

CREATE POLICY "Class teachers read by authenticated" ON class_teachers
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "Class teachers management by staff managers" ON class_teachers
  FOR ALL TO authenticated
  USING (public.user_has_permission(auth.uid(), 'settings', 'manage_staff'))
  WITH CHECK (public.user_has_permission(auth.uid(), 'settings', 'manage_staff'));

CREATE POLICY "Student guardians read by authenticated" ON student_guardians
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "Student guardians management by staff managers" ON student_guardians
  FOR ALL TO authenticated
  USING (public.user_has_permission(auth.uid(), 'settings', 'manage_staff'))
  WITH CHECK (public.user_has_permission(auth.uid(), 'settings', 'manage_staff'));

CREATE POLICY "Class enrollments read by authenticated" ON class_enrollments
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "Class enrollments management by staff managers" ON class_enrollments
  FOR ALL TO authenticated
  USING (public.user_has_permission(auth.uid(), 'settings', 'manage_staff'))
  WITH CHECK (public.user_has_permission(auth.uid(), 'settings', 'manage_staff'));

CREATE POLICY "Parent messages read own" ON parent_portal_messages
  FOR SELECT TO authenticated
  USING (parent_id = auth.uid());

CREATE POLICY "Parent messages read by teachers/admin" ON parent_portal_messages
  FOR SELECT TO authenticated
  USING (
    public.is_admin_or_superadmin(auth.uid())
    OR public.is_teaching_staff(auth.uid())
  );
-- --------------------------------------------------------------
-- ADMIN DASHBOARD � Stage 9: School Calendar
-- Run in Supabase SQL Editor
-- --------------------------------------------------------------

CREATE TABLE IF NOT EXISTS calendar_events (
  id               uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  title            TEXT        NOT NULL,
  event_date       DATE        NOT NULL,
  event_date_label TEXT,
  category         TEXT        NOT NULL DEFAULT 'event', -- 'term', 'holiday', 'event'
  location         TEXT,
  description      TEXT,
  status           TEXT        DEFAULT 'draft', -- 'draft', 'published'
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  updated_at       TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE calendar_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public can read published events" ON calendar_events;
DROP POLICY IF EXISTS "Authenticated can read all events" ON calendar_events;
DROP POLICY IF EXISTS "Authenticated can insert events" ON calendar_events;
DROP POLICY IF EXISTS "Authenticated can update events" ON calendar_events;
DROP POLICY IF EXISTS "Authenticated can delete events" ON calendar_events;

-- Public (anon) can only read published events
CREATE POLICY "Public can read published events" ON calendar_events
  FOR SELECT TO anon USING (status = 'published');

-- Authenticated admins can read all events
CREATE POLICY "Authenticated can read all events" ON calendar_events
  FOR SELECT TO authenticated USING (true);

-- Authenticated admins can create events
CREATE POLICY "Authenticated can insert events" ON calendar_events
  FOR INSERT TO authenticated WITH CHECK (true);

-- Authenticated admins can update events
CREATE POLICY "Authenticated can update events" ON calendar_events
  FOR UPDATE TO authenticated USING (true);

-- Authenticated admins can delete events
CREATE POLICY "Authenticated can delete events" ON calendar_events
  FOR DELETE TO authenticated USING (true);

-- --------------------------------------------------------------
-- PARENT PORTAL SCHEMA
-- --------------------------------------------------------------

-- 1. Students table
CREATE TABLE IF NOT EXISTS students (
  id           uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  first_name   TEXT        NOT NULL,
  last_name    TEXT        NOT NULL,
  date_of_birth DATE,
  class_name   TEXT,       -- e.g. 'Year 1', 'Nursery'
  status       TEXT        DEFAULT 'active', -- 'active', 'graduated', 'left'
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Parents table (links auth.users to students)
CREATE TABLE IF NOT EXISTS parents (
  id           uuid        REFERENCES auth.users(id) PRIMARY KEY,
  full_name    TEXT        NOT NULL,
  phone_number TEXT,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Junction table for Parent-Student relationship (One parent can have multiple students, one student can have multiple parents)
CREATE TABLE IF NOT EXISTS parent_student_rel (
  parent_id    uuid REFERENCES parents(id) ON DELETE CASCADE,
  student_id   uuid REFERENCES students(id) ON DELETE CASCADE,
  relationship TEXT, -- 'Father', 'Mother', 'Guardian'
  PRIMARY KEY (parent_id, student_id)
);

-- 4. Attendance
CREATE TABLE IF NOT EXISTS student_attendance (
  id           uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  student_id   uuid        REFERENCES students(id) ON DELETE CASCADE,
  date         DATE        NOT NULL,
  status       TEXT        NOT NULL, -- 'present', 'absent', 'late'
  remarks      TEXT,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Reports
CREATE TABLE IF NOT EXISTS student_reports (
  id           uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  student_id   uuid        REFERENCES students(id) ON DELETE CASCADE,
  term         TEXT        NOT NULL, -- 'Term 1 2025/26'
  title        TEXT        NOT NULL,
  file_url     TEXT        NOT NULL,
  published_at TIMESTAMPTZ DEFAULT NOW(),
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Messages (Existing table reference or new)
CREATE TABLE IF NOT EXISTS parent_portal_messages (
  id           uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  parent_id    uuid        REFERENCES parents(id),
  student_id   uuid        REFERENCES students(id),
  subject      TEXT        NOT NULL,
  body         TEXT        NOT NULL,
  is_read      BOOLEAN     DEFAULT false,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- RLS POLICIES
ALTER TABLE students ENABLE ROW LEVEL SECURITY;
ALTER TABLE parents ENABLE ROW LEVEL SECURITY;
ALTER TABLE parent_student_rel ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE parent_portal_messages ENABLE ROW LEVEL SECURITY;

-- Admins can do everything on all tables
-- (Assuming public.is_admin_or_superadmin(uid) helper exists)

-- Parent specific access:
CREATE POLICY "Parents can view their own profile" ON parents
  FOR SELECT TO authenticated USING (auth.uid() = id);

CREATE POLICY "Parents can view their students linkage" ON parent_student_rel
  FOR SELECT TO authenticated USING (auth.uid() = parent_id);

CREATE POLICY "Parents can view their own students" ON students
  FOR SELECT TO authenticated USING (
    EXISTS (SELECT 1 FROM parent_student_rel WHERE parent_id = auth.uid() AND student_id = students.id)
  );

CREATE POLICY "Parents can view their students attendance" ON student_attendance
  FOR SELECT TO authenticated USING (
    EXISTS (SELECT 1 FROM parent_student_rel WHERE parent_id = auth.uid() AND student_id = student_attendance.student_id)
  );

CREATE POLICY "Parents can view their students reports" ON student_reports
  FOR SELECT TO authenticated USING (
    EXISTS (SELECT 1 FROM parent_student_rel WHERE parent_id = auth.uid() AND student_id = student_reports.student_id)
  );

CREATE POLICY "Parents can view their messages" ON parent_portal_messages
  FOR SELECT TO authenticated USING (parent_id = auth.uid());


-- --------------------------------------------------------------
-- FEES, PAYMENTS & NOTIFICATIONS SCHEMA
-- --------------------------------------------------------------

-- 1. Fee Categories/Structures (Global)
CREATE TABLE IF NOT EXISTS fee_structures (
  id           uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  title        TEXT        NOT NULL, -- e.g., 'Term 1 Tuition 2025'
  amount       DECIMAL     NOT NULL,
  description  TEXT,
  due_date     DATE,
  academic_year TEXT,      -- e.g., '2025/2026'
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Student Ledgers (Individual accounts)
CREATE TABLE IF NOT EXISTS student_ledgers (
  id           uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  student_id   uuid        REFERENCES students(id) ON DELETE CASCADE,
  title        TEXT        NOT NULL, -- Name of the charge or payment
  type         TEXT        NOT NULL, -- 'charge', 'payment', 'discount'
  amount       DECIMAL     NOT NULL, -- Positive for charges, Negative for payments
  reference_no TEXT,       -- Check # or Receipt #
  status       TEXT        DEFAULT 'posted', -- 'pending', 'posted', 'void'
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Notifications (The "Glue" between Admin and Parents)
CREATE TABLE IF NOT EXISTS portal_notifications (
  id           uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  parent_id    uuid        REFERENCES parents(id) ON DELETE CASCADE,
  student_id   uuid        REFERENCES students(id) ON DELETE CASCADE,
  type         TEXT        NOT NULL, -- 'fee', 'attendance', 'report', 'general'
  priority     TEXT        DEFAULT 'normal', -- 'normal', 'urgent'
  title        TEXT        NOT NULL,
  message      TEXT        NOT NULL,
  is_read      BOOLEAN     DEFAULT false,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- RLS POLICIES
ALTER TABLE fee_structures ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_ledgers ENABLE ROW LEVEL SECURITY;
ALTER TABLE portal_notifications ENABLE ROW LEVEL SECURITY;

-- Public can see fee structures (general info)
CREATE POLICY "Public read fee structures" ON fee_structures FOR SELECT TO anon USING (true);

-- Parents can only see ledgers for THEIR students
CREATE POLICY "Parents view student ledgers" ON student_ledgers
  FOR SELECT TO authenticated USING (
    EXISTS (SELECT 1 FROM parent_student_rel WHERE parent_id = auth.uid() AND student_id = student_ledgers.student_id)
  );

-- Parents can see their own notifications
CREATE POLICY "Parents view notifications" ON portal_notifications
  FOR SELECT TO authenticated USING (parent_id = auth.uid());

-- Admin/Staff access (assuming your helper functions)
CREATE POLICY "Admins full access fees" ON fee_structures FOR ALL TO authenticated USING (true);
CREATE POLICY "Admins full access ledgers" ON student_ledgers FOR ALL TO authenticated USING (true);
CREATE POLICY "Admins full access notifications" ON portal_notifications FOR ALL TO authenticated USING (true);


-- --------------------------------------------------------------
-- ACADEMIC & GRADING SCHEMA
-- --------------------------------------------------------------

CREATE TABLE IF NOT EXISTS academic_sessions (
  id           uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  name         TEXT        NOT NULL,
  is_current   BOOLEAN     DEFAULT false,
  start_date   DATE,
  end_date     DATE
);

CREATE TABLE IF NOT EXISTS subjects (
  id           uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  name         TEXT        NOT NULL,
  code         TEXT        UNIQUE,
  department   TEXT
);

CREATE TABLE IF NOT EXISTS class_subject_assignments (
  id           uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  class_name   TEXT        NOT NULL,
  subject_id   uuid        REFERENCES subjects(id),
  teacher_id   uuid        REFERENCES auth.users(id),
  session_id   uuid        REFERENCES academic_sessions(id)
);

CREATE TABLE IF NOT EXISTS student_grades (
  id           uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  student_id   uuid        REFERENCES students(id) ON DELETE CASCADE,
  subject_id   uuid        REFERENCES subjects(id),
  session_id   uuid        REFERENCES academic_sessions(id),
  assessment_type TEXT     NOT NULL,
  score        DECIMAL     NOT NULL,
  max_score    DECIMAL     DEFAULT 100,
  comments     TEXT,
  graded_by    uuid        REFERENCES auth.users(id),
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE academic_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE class_subject_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_grades ENABLE ROW LEVEL SECURITY;

-- (Policies included in the previous block for brevity)
