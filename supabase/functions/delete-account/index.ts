import { createClient } from "npm:@supabase/supabase-js@2";

const responseHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json; charset=utf-8",
};

function jsonResponse(
  status: number,
  body: Record<string, unknown>,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: responseHeaders,
  });
}

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: responseHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse(405, {
      error: "method_not_allowed",
      message: "Utilisez une requête POST.",
    });
  }

  const authorization = request.headers.get("Authorization") ?? "";
  const token = /^Bearer\s+(\S+)$/i.exec(authorization)?.[1];
  if (!token) {
    return jsonResponse(401, {
      error: "unauthorized",
      message: "Une session valide est nécessaire.",
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse(503, {
      error: "configuration_unavailable",
      message: "Le service de suppression est temporairement indisponible.",
    });
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  let userId: string;
  try {
    const { data, error } = await adminClient.auth.getUser(token);
    if (error || !data.user) {
      return jsonResponse(401, {
        error: "unauthorized",
        message: "La session est invalide ou a expiré.",
      });
    }
    userId = data.user.id;
  } catch {
    return jsonResponse(503, {
      error: "auth_unavailable",
      message: "La vérification de session est temporairement indisponible.",
    });
  }

  try {
    const { error } = await adminClient.rpc("delete_account_data", {
      p_user_id: userId,
    });
    if (error) {
      return jsonResponse(500, {
        error: "data_deletion_failed",
        message: "Les données du compte n’ont pas pu être supprimées.",
      });
    }
  } catch {
    return jsonResponse(500, {
      error: "data_deletion_failed",
      message: "Les données du compte n’ont pas pu être supprimées.",
    });
  }

  try {
    const { error } = await adminClient.auth.admin.deleteUser(userId);
    if (error) {
      return jsonResponse(500, {
        error: "account_deletion_failed",
        message: "Le compte n’a pas pu être supprimé.",
      });
    }
  } catch {
    return jsonResponse(500, {
      error: "account_deletion_failed",
      message: "Le compte n’a pas pu être supprimé.",
    });
  }

  return jsonResponse(200, { success: true });
});
