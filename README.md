# FeriAPP — Tu Cuaderno Inteligente

PWA para microemprendedores. Registra ventas, analiza sobrantes y recibe recomendaciones con IA.

## Estructura

```
feriapp/
├── public/
│   ├── index.html      ← App completa (todo en un archivo)
│   ├── sw.js           ← Service Worker (modo offline)
│   ├── manifest.json   ← Configuración PWA
│   └── icons/          ← Iconos para todos los dispositivos
├── vercel.json         ← Configuración de deploy
└── README.md
```

## Deploy en Vercel (5 minutos)

1. Sube esta carpeta a GitHub
2. Importa el repo en vercel.com
3. Framework: **Other**
4. Root directory: `.\ (raíz)
5. Deploy ✓

## Variables de entorno en Vercel

Configura estas variables en Project Settings → Environment Variables:

```bash
SUPABASE_URL=https://tu-proyecto.supabase.co
SUPABASE_ANON_KEY=tu_anon_key_publica
SUPABASE_SERVICE_ROLE_KEY=tu_service_role_key_privada
ANTHROPIC_API_KEY=tu_api_key_privada
```

`SUPABASE_SERVICE_ROLE_KEY` y `ANTHROPIC_API_KEY` son privadas. Nunca deben ir dentro de `public/index.html`.

## Base de datos Supabase

Ejecuta `supabase/schema.sql` en el SQL Editor. La migración elimina policies duplicadas, crea tablas de administración y deja acceso admin por RLS.

Después, marca tu usuario como admin cambiando el email:

```sql
insert into public.admin_users (user_id)
select id from auth.users where email = 'TU_EMAIL@gmail.com'
on conflict (user_id) do nothing;

update public.perfiles
set es_admin = true
where id in (select user_id from public.admin_users);
```

El panel privado queda en:

```text
/admin
```

La app principal ahora funciona así:

- Sin sesión: guarda datos en el dispositivo con `localStorage`.
- Con Google OAuth: mantiene copia local y sincroniza productos, ventas, sobrantes y perfil con Supabase.
- Cada acción importante genera registros en `usage_events` para el panel admin.

En Supabase Auth agrega estas URLs de redirección:

```text
http://localhost:3000
https://TU-DOMINIO.vercel.app
https://TU-DOMINIO.vercel.app/admin.html
```

## Configurar IA

La usuaria no debe pegar llaves técnicas en FeriAPP.

La IA funciona desde la función privada `api/feriai.js`:

1. Crea una API key en Anthropic Console.
2. Agrégala en Vercel como variable privada:

```bash
ANTHROPIC_API_KEY=tu_api_key_privada
```

3. Redeploy en Vercel.

Si `ANTHROPIC_API_KEY` no existe, FeriAPP cae automáticamente a recomendaciones básicas por reglas.

FeriAI Plus valida la sesión del usuario con Supabase. Para habilitar IA a una cuenta durante el piloto:

```sql
update public.perfiles
set es_premium = true
where id in (
  select id from auth.users where email = 'CORREO_DEL_USUARIO@gmail.com'
);
```

Los usuarios admin también pueden usar FeriAI Plus.

## Desarrollo local

Cualquier servidor estático sirve:
```bash
cd public
npx serve .
# o
python3 -m http.server 3000
```

## Tech stack

- HTML + CSS + JS vanilla (sin frameworks)
- localStorage para persistencia
- Anthropic API vía serverless function para IA
- PWA con Service Worker

## Guia para usuarias piloto

Las instrucciones para instalar FeriAPP en Android/iPhone estan en:

```text
docs/guia-instalacion-y-piloto.md
```

El guion de demo, pauta de feedback y siguientes pasos del piloto estan en:

```text
docs/guion-demo-y-prueba.md
```

## Modelo de negocio

| Plan | Precio | Límites |
|------|--------|---------|
| FeriAPP Libre | Gratis | Productos ilimitados, 30 días historial, reglas inteligentes |
| FeriAPP Plus | $4.990 CLP/mes | IA, alertas, stock sugerido y resúmenes |
| FeriAPP Pro | Próximamente | Foto boleta, predicción demanda |

## Para editar en Cursor

Abre la carpeta `feriapp/` en Cursor.
El archivo principal es `public/index.html`.
Toda la lógica está en el `<script>` al final del archivo.
