import { createClient } from "@supabase/supabase-js";

function getEnv(name: string): string {
  return process.env[name] ?? "";
}

export function hasSupabaseEnv(): boolean {
  return Boolean(
    getEnv("NEXT_PUBLIC_SUPABASE_URL") &&
      (getEnv("SUPABASE_SERVICE_ROLE_KEY") ||
        getEnv("NEXT_PUBLIC_SUPABASE_ANON_KEY")),
  );
}

export function createSupabaseServerClient() {
  const supabaseUrl = getEnv("NEXT_PUBLIC_SUPABASE_URL");
  const supabaseKey =
    getEnv("SUPABASE_SERVICE_ROLE_KEY") ||
    getEnv("NEXT_PUBLIC_SUPABASE_ANON_KEY");

  if (!supabaseUrl || !supabaseKey) {
    throw new Error("Supabase environment is not configured");
  }

  return createClient(supabaseUrl, supabaseKey, {
    auth: { persistSession: false },
  });
}
