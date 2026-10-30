// Initializes the browser Supabase client. Database access remains protected by RLS.
(() => {
  if (!window.supabase?.createClient) {
    console.error("Supabase SDK did not load. Check the network connection.");
    return;
  }
  window.doggoSupabase = window.supabase.createClient(
    window.DOGGO_SUPABASE_URL,
    window.DOGGO_SUPABASE_PUBLISHABLE_KEY,
    { auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true } }
  );
  window.dispatchEvent(new Event("doggo-supabase-ready"));
})();
