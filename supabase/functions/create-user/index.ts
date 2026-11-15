// ==============================================================================
// KORMO - Edge Function: create-user
// Secure User Creation with Delegated Authority Hierarchy Enforcement
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
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing Authorization header" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 1. Authenticate caller
    const callerClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user: callerUser }, error: userError } = await callerClient.auth.getUser();

    if (userError || !callerUser) {
      return new Response(JSON.stringify({ error: "Invalid caller session or token expired" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const adminClient = createClient(supabaseUrl, supabaseServiceKey);

    // 2. Parse request payload
    const body = await req.json();
    const {
      email,
      password,
      full_name,
      phone,
      role,
      department_id,
      branch_id,
      shift_id,
      designation,
      employment_type,
      employee_id,
      send_invite = false,
    } = body;

    if (!email || !full_name || !role || !employee_id) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: email, full_name, role, employee_id" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 3. Verify permissions via can_create RPC
    const { data: canCreate, error: canCreateError } = await callerClient.rpc("can_create", {
      p_target_role: role,
      p_target_dept_id: department_id || null,
    });

    if (canCreateError || !canCreate) {
      return new Response(
        JSON.stringify({
          error: "Permission denied: You do not have permission to create this role in this department.",
        }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 4. Duplicate checks
    const { data: existingProfiles } = await adminClient
      .from("profiles")
      .select("id, email, employee_id")
      .or(`email.eq.${email},employee_id.eq.${employee_id}`);

    if (existingProfiles && existingProfiles.length > 0) {
      const match = existingProfiles[0];
      const field = match.email.toLowerCase() === email.toLowerCase() ? "Email" : "Employee ID";
      return new Response(
        JSON.stringify({ error: `${field} "${field === 'Email' ? email : employee_id}" is already registered.` }),
        { status: 409, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 5. Generate secure temporary password if none provided
    const userPassword = password || `Kormo#${Math.random().toString(36).substring(2, 8)}!`;

    // 6. Create auth user
    const { data: createdAuth, error: authCreateError } = await adminClient.auth.admin.createUser({
      email,
      password: userPassword,
      email_confirm: true,
      user_metadata: { full_name },
    });

    if (authCreateError || !createdAuth.user) {
      return new Response(
        JSON.stringify({ error: authCreateError?.message || "Failed to create user in auth system" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const newUserId = createdAuth.user.id;

    // 7. Insert profile
    const { data: newProfile, error: profileError } = await adminClient
      .from("profiles")
      .insert({
        id: newUserId,
        employee_id,
        email,
        full_name,
        phone: phone || null,
        role,
        department_id: department_id || null,
        branch_id: branch_id || null,
        shift_id: shift_id || null,
        designation: designation || null,
        employment_type: employment_type || "full_time",
        must_change_password: true,
        is_active: true,
      })
      .select()
      .single();

    if (profileError) {
      // Rollback auth user if profile insertion failed
      await adminClient.auth.admin.deleteUser(newUserId);
      return new Response(
        JSON.stringify({ error: `Failed to create profile: ${profileError.message}` }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 8. Initialize leave balances for current year
    const currentYear = new Date().getFullYear();
    const { data: leaveTypes } = await adminClient.from("leave_types").select("id, days_allowed");
    if (leaveTypes && leaveTypes.length > 0) {
      const balancesToInsert = leaveTypes.map((lt) => ({
        user_id: newUserId,
        leave_type_id: lt.id,
        year: currentYear,
        allocated_days: lt.days_allowed,
        used_days: 0.0,
      }));
      await adminClient.from("leave_balances").insert(balancesToInsert);
    }

    // 9. Record immutable audit log
    await adminClient.from("audit_logs").insert({
      actor_id: callerUser.id,
      action: "CREATE_USER",
      table_name: "profiles",
      record_id: newUserId,
      new_data: {
        employee_id,
        email,
        role,
        department_id,
        branch_id,
      },
      platform: "web",
    });

    return new Response(
      JSON.stringify({
        success: true,
        user: newProfile,
        temporary_password: userPassword,
        message: "User successfully created.",
      }),
      { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message || "Internal server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
