import { createClient } from "@supabase/supabase-js";

function getEnv(name: string): string {
  return process.env[name] ?? "";
}

export function hasSupabaseStorageEnv(): boolean {
  return Boolean(
    getEnv("NEXT_PUBLIC_SUPABASE_URL") &&
      getEnv("SUPABASE_SERVICE_ROLE_KEY"),
  );
}

export function createSupabaseStorageClient() {
  const supabaseUrl = getEnv("NEXT_PUBLIC_SUPABASE_URL");
  const supabaseServiceRoleKey = getEnv("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !supabaseServiceRoleKey) {
    throw new Error("Supabase environment is not configured");
  }

  return createClient(supabaseUrl, supabaseServiceRoleKey, {
    auth: { persistSession: false },
  });
}
