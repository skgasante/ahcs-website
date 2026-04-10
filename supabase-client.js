// ── Public Supabase client — used by public-facing pages ──────
// Uses the anon (public) key. This key is safe to expose in browser code.
// To update credentials, change both values here and in admin/config.js.

const SUPABASE_PUBLIC_URL  = 'https://okoyzvrtwwrrezfmefde.supabase.co';
const SUPABASE_PUBLIC_ANON = 'sb_publishable_nI8d-xRtP3-cEfK5riMoKg_VOPq0Eb8';

const { createClient } = supabase;
const supabasePublic   = createClient(SUPABASE_PUBLIC_URL, SUPABASE_PUBLIC_ANON);
