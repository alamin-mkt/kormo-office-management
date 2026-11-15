// ==============================================================================
// KORMO - Edge Function: send-fcm-notification
// Android Push Notification Dispatcher via Firebase Cloud Messaging (FCM)
// ==============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const fcmServerKey = Deno.env.get("FCM_SERVER_KEY") ?? "";

    const { user_id, title, message, type = "general", reference_id = null } = await req.json();

    if (!user_id || !title || !message) {
      return new Response(JSON.stringify({ error: "Missing user_id, title, or message" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const adminClient = createClient(supabaseUrl, supabaseServiceKey);

    // 1. Insert in-app notification (triggers Supabase Realtime channel)
    const { data: notif, error: notifError } = await adminClient
      .from("notifications")
      .insert({
        user_id,
        title,
        message,
        type,
        reference_id,
        is_read: false,
      })
      .select()
      .single();

    if (notifError) {
      console.error("Failed to store in-app notification:", notifError);
    }

    // 2. Dispatch FCM push notification if FCM_SERVER_KEY is configured
    let fcmDispatched = false;
    if (fcmServerKey) {
      // Look up user's active mobile device tokens (if stored in device_tokens or login_events)
      const fcmPayload = {
        to: `/topics/user_${user_id}`,
        notification: {
          title,
          body: message,
          sound: "default",
          color: "#1A7E96",
        },
        data: {
          type,
          reference_id: reference_id || "",
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
      };

      const fcmRes = await fetch("https://fcm.googleapis.com/fcm/send", {
        method: "POST",
        headers: {
          Authorization: `key=${fcmServerKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(fcmPayload),
      });

      if (fcmRes.ok) {
        fcmDispatched = true;
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        notification_id: notif?.id,
        fcm_dispatched: fcmDispatched,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
