-- ==============================================================================
-- KORMO - SUPABASE AUTH ACCOUNTS FIX
-- Run this in Supabase SQL Editor to enable instant login for all seeded accounts
-- ==============================================================================

-- 1. Fix NULL string columns in auth.users (prevents GoTrue 500 error)
UPDATE auth.users
SET 
    confirmation_token = COALESCE(confirmation_token, ''),
    recovery_token = COALESCE(recovery_token, ''),
    email_change_token_new = COALESCE(email_change_token_new, ''),
    email_change = COALESCE(email_change, ''),
    email_change_token_current = COALESCE(email_change_token_current, ''),
    phone_change = COALESCE(phone_change, ''),
    phone_change_token = COALESCE(phone_change_token, ''),
    reauthentication_token = COALESCE(reauthentication_token, ''),
    email_confirmed_at = COALESCE(email_confirmed_at, NOW()),
    confirmed_at = COALESCE(confirmed_at, NOW()),
    last_sign_in_at = COALESCE(last_sign_in_at, NOW()),
    is_super_admin = COALESCE(is_super_admin, FALSE)
WHERE email LIKE '%@kormo.com' OR email = 'test_kormo_99@gmail.com';

-- 2. Ensure auth.identities are cleanly linked
INSERT INTO auth.identities (
    id,
    user_id,
    identity_data,
    provider,
    provider_id,
    last_sign_in_at,
    created_at,
    updated_at
)
SELECT 
    u.id::text,
    u.id,
    jsonb_build_object(
        'sub', u.id::text,
        'email', u.email,
        'email_verified', true,
        'phone_verified', false
    ),
    'email',
    u.id::text,
    NOW(),
    NOW(),
    NOW()
FROM auth.users u
WHERE u.email LIKE '%@kormo.com'
ON CONFLICT DO NOTHING;

-- 3. Verify the 6 role users
SELECT id, email, role, email_confirmed_at FROM auth.users WHERE email LIKE '%@kormo.com';
