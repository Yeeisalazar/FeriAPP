export default function handler(request, response) {
  response.setHeader("Cache-Control", "no-store");
  response.status(200).json({
    supabaseUrl: cleanSupabaseUrl(process.env.SUPABASE_URL),
    supabaseAnonKey: cleanKey(process.env.SUPABASE_ANON_KEY),
  });
}

function cleanKey(value = "") {
  return String(value).replace(/\s/g, "");
}

function cleanSupabaseUrl(value = "") {
  const cleaned = String(value).trim().replace(/\/+$/, "");
  if (!cleaned) return "";

  try {
    const url = new URL(cleaned);
    return url.origin;
  } catch {
    return cleaned;
  }
}
