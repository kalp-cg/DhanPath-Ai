import { createClient } from "@supabase/supabase-js";

function getEnv(name: string): string {
  return process.env[name] ?? "";
}

export function hasSupabaseEnv(): boolean {
  return Boolean(
    getEnv("NEXT_PUBLIC_SUPABASE_URL") &&
      getEnv("NEXT_PUBLIC_SUPABASE_ANON_KEY"),
  );
}

export function createSupabaseRlsClient(accessToken: string) {
  const supabaseUrl = getEnv("NEXT_PUBLIC_SUPABASE_URL");
  const supabaseAnonKey = getEnv("NEXT_PUBLIC_SUPABASE_ANON_KEY");

  if (!supabaseUrl || !supabaseAnonKey) {
    throw new Error("Supabase environment is not configured");
  }

  return createClient(supabaseUrl, supabaseAnonKey, {
    auth: { persistSession: false },
    global: {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    },
  });
}
