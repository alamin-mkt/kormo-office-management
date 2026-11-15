-- ==============================================================================
-- KORMO - SUPABASE AUTH AUTO-PATCH (Foolproof NULL Column Fix)
-- Run this in Supabase SQL Editor: It patches ALL nullable string columns
-- in auth.users and auth.identities so GoTrue never crashes with a scan error.
-- ==============================================================================

DO $$
DECLARE
    r RECORD;
    v_sql TEXT;
BEGIN
    -- 1. Patch ALL nullable text/varchar columns in auth.users
    FOR r IN (
        SELECT column_name 
        FROM information_schema.columns 
        WHERE table_schema = 'auth' 
          AND table_name = 'users' 
          AND data_type IN ('text', 'character varying')
          AND is_nullable = 'YES'
          AND column_name NOT IN ('email', 'encrypted_password')
    ) LOOP
        v_sql := format('UPDATE auth.users SET %I = COALESCE(%I, '''') WHERE email LIKE ''%%@kormo.com'';', r.column_name, r.column_name);
        EXECUTE v_sql;
    END LOOP;

    -- 2. Ensure email_confirmed_at is set for all kormo users
    UPDATE auth.users
    SET email_confirmed_at = COALESCE(email_confirmed_at, NOW()),
        last_sign_in_at = COALESCE(last_sign_in_at, NOW())
    WHERE email LIKE '%@kormo.com';

    -- 3. Patch ALL nullable text/varchar columns in auth.identities
    FOR r IN (
        SELECT column_name 
        FROM information_schema.columns 
        WHERE table_schema = 'auth' 
          AND table_name = 'identities' 
          AND data_type IN ('text', 'character varying')
          AND is_nullable = 'YES'
          AND column_name NOT IN ('id', 'provider')
    ) LOOP
        v_sql := format('UPDATE auth.identities SET %I = COALESCE(%I, '''') WHERE user_id IN (SELECT id FROM auth.users WHERE email LIKE ''%%@kormo.com'');', r.column_name, r.column_name);
        EXECUTE v_sql;
    END LOOP;
END $$;

-- 4. Verify users
SELECT id, email, phone, role, email_confirmed_at FROM auth.users WHERE email LIKE '%@kormo.com';
