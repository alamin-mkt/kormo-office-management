-- ==============================================================================
-- KORMO - Migration 20261116000001: Admin Self-Signup & Auto Profile Creation
-- Supports Admin Registration Portal via Supabase Auth
-- ==============================================================================

-- 1. RPC Function to handle Admin Signup Profile Provisioning
CREATE OR REPLACE FUNCTION public.handle_admin_signup(
    p_full_name TEXT,
    p_company_name TEXT DEFAULT NULL,
    p_phone TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_email TEXT;
    v_emp_id TEXT;
    v_dept_id UUID;
    v_branch_id UUID;
    v_shift_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated.';
    END IF;

    -- Check if profile already exists
    IF EXISTS (SELECT 1 FROM profiles WHERE id = v_user_id) THEN
        RETURN jsonb_build_object('success', true, 'message', 'Profile already exists.');
    END IF;

    SELECT email INTO v_email FROM auth.users WHERE id = v_user_id;

    -- Generate unique employee ID (ADM-XXXXXX)
    v_emp_id := 'ADM-' || upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));

    -- Assign default department, branch, and shift
    SELECT id INTO v_dept_id FROM departments WHERE name ILIKE '%Executive%' OR name ILIKE '%IT%' LIMIT 1;
    IF v_dept_id IS NULL THEN
        SELECT id INTO v_dept_id FROM departments LIMIT 1;
    END IF;

    SELECT id INTO v_branch_id FROM branches LIMIT 1;
    SELECT id INTO v_shift_id FROM shifts LIMIT 1;

    -- Insert admin profile
    INSERT INTO profiles (
        id, employee_id, email, full_name, phone, role,
        department_id, branch_id, shift_id, designation,
        is_active, must_change_password
    ) VALUES (
        v_user_id,
        v_emp_id,
        v_email,
        COALESCE(NULLIF(trim(p_full_name), ''), split_part(v_email, '@', 1)),
        NULLIF(trim(p_phone), ''),
        'admin',
        v_dept_id,
        v_branch_id,
        v_shift_id,
        'System Administrator',
        TRUE,
        FALSE
    );

    -- Update company name in settings if provided
    IF p_company_name IS NOT NULL AND length(trim(p_company_name)) > 0 THEN
        UPDATE settings SET company_name = trim(p_company_name) WHERE company_name IS NOT NULL;
    END IF;

    -- Audit log entry
    INSERT INTO audit_logs (
        user_id, action, entity, entity_id, new_data, platform
    ) VALUES (
        v_user_id,
        'ADMIN_REGISTRATION',
        'profiles',
        v_user_id,
        jsonb_build_object(
            'role', 'admin',
            'email', v_email,
            'full_name', p_full_name,
            'company_name', p_company_name
        ),
        'web'
    );

    RETURN jsonb_build_object('success', true, 'employee_id', v_emp_id, 'role', 'admin');
END;
$$;

-- Allow authenticated users to call handle_admin_signup
GRANT EXECUTE ON FUNCTION public.handle_admin_signup(TEXT, TEXT, TEXT) TO authenticated;

-- 2. Automatic Trigger on auth.users for any new Admin/Director Signup
CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_dept_id UUID;
    v_branch_id UUID;
    v_shift_id UUID;
    v_role user_role := 'admin';
    v_full_name TEXT;
    v_emp_id TEXT;
    v_role_meta TEXT;
BEGIN
    -- Check requested role from raw_user_meta_data
    v_role_meta := NEW.raw_user_meta_data->>'role';
    IF v_role_meta = 'director' THEN
        v_role := 'director';
    ELSIF v_role_meta = 'admin' THEN
        v_role := 'admin';
    ELSIF v_role_meta = 'hr' THEN
        v_role := 'hr';
    ELSIF v_role_meta = 'manager' THEN
        v_role := 'manager';
    ELSE
        v_role := 'admin'; -- Default to admin for portal signups
    END IF;

    v_full_name := COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1));
    v_emp_id := 'ADM-' || upper(substr(md5(NEW.id::text || clock_timestamp()::text), 1, 6));

    SELECT id INTO v_dept_id FROM departments LIMIT 1;
    SELECT id INTO v_branch_id FROM branches LIMIT 1;
    SELECT id INTO v_shift_id FROM shifts LIMIT 1;

    INSERT INTO public.profiles (
        id, employee_id, email, full_name, phone, role,
        department_id, branch_id, shift_id, designation,
        is_active, must_change_password
    ) VALUES (
        NEW.id,
        v_emp_id,
        NEW.email,
        v_full_name,
        COALESCE(NEW.phone, ''),
        v_role,
        v_dept_id,
        v_branch_id,
        v_shift_id,
        'System Administrator',
        TRUE,
        FALSE
    )
    ON CONFLICT (id) DO NOTHING;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_auth_user();
