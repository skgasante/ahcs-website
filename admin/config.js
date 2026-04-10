// ── Supabase Admin Client ──────────────────────────────────────
// Fill in your project URL and anon (public) key.
// Found in: Supabase Dashboard → Project Settings → API
// ⚠️  Use the ANON key here (not the service role key).

const SUPABASE_URL      = 'https://okoyzvrtwwrrezfmefde.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_nI8d-xRtP3-cEfK5riMoKg_VOPq0Eb8';

const { createClient } = supabase;
const supabaseClient   = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
