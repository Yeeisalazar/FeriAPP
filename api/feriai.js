export default async function handler(request, response) {
  if (request.method !== "POST") {
    response.setHeader("Allow", "POST");
    response.status(405).json({ message: "Metodo no permitido" });
    return;
  }

  const apiKey = cleanKey(process.env.ANTHROPIC_API_KEY);
  if (!apiKey) {
    response.status(501).json({ message: "FeriAI Plus aun no esta configurado" });
    return;
  }

  const supabase = getSupabaseConfig();
  if (!supabase) {
    response.status(500).json({ message: "Falta configurar Supabase en el servidor" });
    return;
  }

  const token = getBearerToken(request);
  if (!token) {
    response.status(401).json({ message: "Debes iniciar sesion para usar FeriAI Plus" });
    return;
  }

  try {
    const user = await getSupabaseUser(supabase, token);
    if (!user?.id) {
      response.status(401).json({ message: "Sesion no valida" });
      return;
    }

    const allowed = await canUsePlus(supabase, user.id);
    if (!allowed) {
      response.status(403).json({ message: "FeriAI con IA es parte de FeriAPP Plus" });
      return;
    }

    const body = await readJson(request);
    const prompt = buildPrompt(body);

    const anthropicResponse = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: process.env.ANTHROPIC_MODEL || "claude-sonnet-4-20250514",
        max_tokens: 500,
        messages: [{ role: "user", content: prompt }],
      }),
    });

    const data = await anthropicResponse.json();
    if (!anthropicResponse.ok || data.error) {
      response.status(502).json({ message: "No pudimos generar recomendaciones con IA" });
      return;
    }

    const text = data.content?.map((block) => block.text || "").join("").trim() || "";
    const recs = parseRecommendations(text);

    if (!recs.length) {
      response.status(502).json({ message: "La IA no devolvio recomendaciones claras" });
      return;
    }

    response.setHeader("Cache-Control", "no-store");
    response.status(200).json({ recs });
  } catch {
    response.status(500).json({ message: "No pudimos procesar la recomendacion" });
  }
}

function cleanKey(value = "") {
  return String(value).replace(/\s/g, "");
}

function cleanUrl(value = "") {
  const cleaned = String(value).trim().replace(/\/+$/, "");
  if (!cleaned) return "";

  try {
    return new URL(cleaned).origin;
  } catch {
    return cleaned;
  }
}

function getSupabaseConfig() {
  const url = cleanUrl(process.env.SUPABASE_URL);
  const anonKey = cleanKey(process.env.SUPABASE_ANON_KEY);
  const serviceRoleKey = cleanKey(process.env.SUPABASE_SERVICE_ROLE_KEY);

  if (!url || !anonKey || !serviceRoleKey) return null;
  return { url, anonKey, serviceRoleKey };
}

function getBearerToken(request) {
  const header = request.headers.authorization || request.headers.Authorization || "";
  return String(header).replace(/^Bearer\s+/i, "").trim();
}

async function getSupabaseUser(supabase, token) {
  const result = await fetch(`${supabase.url}/auth/v1/user`, {
    headers: {
      apikey: supabase.anonKey,
      Authorization: `Bearer ${token}`,
    },
  });

  if (!result.ok) return null;
  return result.json();
}

async function canUsePlus(supabase, userId) {
  const [profile, admin] = await Promise.all([
    fetchSingle(supabase, `perfiles?id=eq.${encodeURIComponent(userId)}&select=es_premium`),
    fetchSingle(supabase, `admin_users?user_id=eq.${encodeURIComponent(userId)}&select=user_id`),
  ]);

  return !!profile?.es_premium || !!admin?.user_id;
}

async function fetchSingle(supabase, path) {
  const result = await fetch(`${supabase.url}/rest/v1/${path}&limit=1`, {
    headers: {
      apikey: supabase.serviceRoleKey,
      Authorization: `Bearer ${supabase.serviceRoleKey}`,
      Accept: "application/json",
    },
  });

  if (!result.ok) return null;
  const rows = await result.json();
  return Array.isArray(rows) ? rows[0] : null;
}

async function readJson(request) {
  if (request.body) {
    return typeof request.body === "string" ? JSON.parse(request.body) : request.body;
  }

  let raw = "";
  for await (const chunk of request) raw += chunk;
  return raw ? JSON.parse(raw) : {};
}

function buildPrompt(body) {
  const tipo = body?.tipo || "feria";
  const energia = body?.energia || "Normal";
  const productos = Array.isArray(body?.productos) ? body.productos : [];
  const resumen =
    productos
      .map((producto) => {
        const costo = producto.sinCosto || producto.costo == null ? "costo pendiente" : `costo ${clp(producto.costo)}`;
        return `- ${producto.nombre}: precio ${clp(producto.precio)}, ${costo}, ${producto.vendidas || 0} vendidas, ${producto.sobro || 0} sobrantes, ${producto.vecesSobro || 0} veces con sobrantes`;
      })
      .join("\n") || "Sin productos registrados todavia";

  return `Eres FeriAI, asistente de FeriAPP para microemprendedoras en Chile.
Habla en espanol chileno cercano, simple y accionable. Evita tecnicismos.

La usuaria prepara una ${tipo} y tiene energia/tiempo: ${energia}.

Datos del negocio:
${resumen}

Devuelve 4 recomendaciones concretas para decidir que preparar, que llevar, que evitar o que precio/costo revisar.
Responde solo JSON valido, sin markdown ni explicaciones extra:
{"recs":[{"emoji":"...","texto":"..."},{"emoji":"...","texto":"..."},{"emoji":"...","texto":"..."},{"emoji":"...","texto":"..."}]}`;
}

function parseRecommendations(text) {
  const cleaned = text.replace(/```json|```/g, "").trim();
  const parsed = JSON.parse(cleaned);
  const recs = Array.isArray(parsed.recs) ? parsed.recs : [];

  return recs
    .map((rec) => ({
      emoji: String(rec.emoji || "✨").slice(0, 4),
      texto: String(rec.texto || "").trim().slice(0, 220),
    }))
    .filter((rec) => rec.texto);
}

function clp(value) {
  return `$${Math.round(Number(value || 0)).toLocaleString("es-CL")}`;
}
