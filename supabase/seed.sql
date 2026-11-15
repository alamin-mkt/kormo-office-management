-- ==============================================================================
-- KORMO - Seed Data: Master Configuration & Test Users (All 6 Roles)
-- Database: PostgreSQL (Supabase)
-- Timezone: Asia/Dhaka | Currency: BDT
-- ==============================================================================

-- 1. SETTINGS
INSERT INTO settings (
    company_name,
    company_code,
    company_address,
    contact_email,
    contact_phone,
    currency,
    timezone,
    weekend_days,
    allow_executive_add_user,
    require_selfie_attendance,
    require_wifi_attendance
) VALUES (
    'Kormo Enterprise Ltd.',
    'KORMO',
    'Plot 15, Road 11, Block D, Banani, Dhaka 1213, Bangladesh',
    'support@kormo.app',
    '+880 1711-223344',
    'BDT',
    'Asia/Dhaka',
    ARRAY['friday'],
    FALSE,
    FALSE,
    FALSE
) ON CONFLICT DO NOTHING;

-- 2. BRANCHES (Valid Hex UUIDs)
INSERT INTO branches (id, name, code, address, latitude, longitude, radius_meters)
VALUES 
    ('bbbbbbbb-0000-0000-0000-000000000001', 'Dhaka Head Office (Banani)', 'DHK-HQ', 'Plot 15, Road 11, Banani, Dhaka', 23.7925000, 90.4078000, 250),
    ('bbbbbbbb-0000-0000-0000-000000000002', 'Chattogram Branch (Agrabad)', 'CTG-01', 'Commercial Area, Agrabad, Chattogram', 22.3350000, 91.8120000, 300)
ON CONFLICT (code) DO NOTHING;

-- 3. DEPARTMENTS (Valid Hex UUIDs)
INSERT INTO departments (id, name, code, branch_id)
VALUES
    ('dddddddd-0000-0000-0000-000000000001', 'Executive Leadership', 'EXEC', 'bbbbbbbb-0000-0000-0000-000000000001'),
    ('dddddddd-0000-0000-0000-000000000002', 'Human Resources & Admin', 'HR', 'bbbbbbbb-0000-0000-0000-000000000001'),
    ('dddddddd-0000-0000-0000-000000000003', 'Software Engineering & IT', 'ENG', 'bbbbbbbb-0000-0000-0000-000000000001'),
    ('dddddddd-0000-0000-0000-000000000004', 'Finance & Accounts', 'FIN', 'bbbbbbbb-0000-0000-0000-000000000001'),
    ('dddddddd-0000-0000-0000-000000000005', 'Sales & Marketing', 'MKT', 'bbbbbbbb-0000-0000-0000-000000000001')
ON CONFLICT (code) DO NOTHING;

-- 4. SHIFTS (Valid Hex UUIDs)
INSERT INTO shifts (id, name, code, start_time, end_time, grace_period_mins, standard_hours, is_overnight)
VALUES
    ('aaaaaaaa-0000-0000-0000-000000000001', 'General Regular Shift', 'GEN-01', '09:00:00', '18:00:00', 15, 8.00, FALSE),
    ('aaaaaaaa-0000-0000-0000-000000000002', 'Morning Support Shift', 'MORN-01', '07:00:00', '15:30:00', 10, 8.00, FALSE),
    ('aaaaaaaa-0000-0000-0000-000000000003', 'Night Infrastructure Shift', 'NGHT-01', '22:00:00', '06:00:00', 15, 8.00, TRUE)
ON CONFLICT (code) DO NOTHING;

-- 5. LEAVE TYPES (Valid Hex UUIDs)
INSERT INTO leave_types (id, name, code, days_allowed, is_paid, requires_attachment, description)
VALUES
    ('eeeeeeee-0000-0000-0000-000000000001', 'Annual Leave', 'AL', 14.0, TRUE, FALSE, 'Paid annual statutory vacation leave.'),
    ('eeeeeeee-0000-0000-0000-000000000002', 'Casual Leave', 'CL', 10.0, TRUE, FALSE, 'Urgent or personal casual leave.'),
    ('eeeeeeee-0000-0000-0000-000000000003', 'Sick Leave', 'SL', 14.0, TRUE, TRUE, 'Medical sick leave. Medical cert required for >2 days.'),
    ('eeeeeeee-0000-0000-0000-000000000004', 'Maternity Leave', 'ML', 112.0, TRUE, TRUE, 'Maternity leave as per Bangladesh Labor Act.'),
    ('eeeeeeee-0000-0000-0000-000000000005', 'Unpaid Leave', 'UL', 30.0, FALSE, FALSE, 'Leave without pay for extended absence.')
ON CONFLICT (code) DO NOTHING;

-- 6. OFFICIAL HOLIDAYS (Bangladesh Standard)
INSERT INTO holidays (name, date, description)
VALUES
    ('Shaheed Day & International Mother Language Day', '2026-02-21', 'National Language Martyrs Day'),
    ('Independence & National Day', '2026-03-26', 'Bangladesh Independence Day'),
    ('Bengali New Year (Pohela Boishakh)', '2026-04-14', 'First day of Bengali calendar'),
    ('May Day', '2026-05-01', 'International Workers Day'),
    ('Eid-ul-Fitr (Day 1)', '2026-03-21', 'Eid Festival Holiday'),
    ('Eid-ul-Fitr (Day 2)', '2026-03-22', 'Eid Festival Holiday'),
    ('Eid-ul-Adha', '2026-05-28', 'Sacrifice Festival Holiday'),
    ('National Mourning Day', '2026-08-15', 'National Mourning Day'),
    ('Victory Day', '2026-12-16', 'Victory Day of Bangladesh')
ON CONFLICT (date) DO NOTHING;

-- 7. TEST USERS CREATION (Supabase auth.users, auth.identities + public.profiles)
-- Passwords for all test accounts: Kormo@2026!
DO $$
DECLARE
    v_director_id UUID := '11111111-0000-0000-0000-000000000001';
    v_admin_id    UUID := '22222222-0000-0000-0000-000000000002';
    v_hr_id       UUID := '33333333-0000-0000-0000-000000000003';
    v_manager_id  UUID := '44444444-0000-0000-0000-000000000004';
    v_exec_id     UUID := '55555555-0000-0000-0000-000000000005';
    v_emp_id      UUID := '66666666-0000-0000-0000-000000000006';
    v_hash TEXT := crypt('Kormo@2026!', gen_salt('bf'));
BEGIN
    -- 7.1 Director User
    INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, role, aud)
    VALUES (
        v_director_id,
        '00000000-0000-0000-0000-000000000000',
        'director@kormo.com',
        v_hash,
        NOW(),
        '{"provider":"email","providers":["email"]}',
        '{"full_name":"Syed Rahman (Director)"}',
        'authenticated',
        'authenticated'
    ) ON CONFLICT (id) DO NOTHING;

    INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
    VALUES (
        v_director_id,
        v_director_id,
        jsonb_build_object('sub', v_director_id, 'email', 'director@kormo.com'),
        'email',
        'director@kormo.com',
        NOW(), NOW(), NOW()
    ) ON CONFLICT (provider, provider_id) DO NOTHING;

    INSERT INTO profiles (
        id, employee_id, email, full_name, phone, role,
        department_id, branch_id, shift_id, designation, must_change_password
    ) VALUES (
        v_director_id, 'KORMO-001', 'director@kormo.com', 'Syed Rahman', '+880 1711-000001', 'director',
        'dddddddd-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'Managing Director', FALSE
    ) ON CONFLICT (id) DO NOTHING;

    -- 7.2 Admin User
    INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, role, aud)
    VALUES (
        v_admin_id,
        '00000000-0000-0000-0000-000000000000',
        'admin@kormo.com',
        v_hash,
        NOW(),
        '{"provider":"email","providers":["email"]}',
        '{"full_name":"Tariq Hasan (System Admin)"}',
        'authenticated',
        'authenticated'
    ) ON CONFLICT (id) DO NOTHING;

    INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
    VALUES (
        v_admin_id,
        v_admin_id,
        jsonb_build_object('sub', v_admin_id, 'email', 'admin@kormo.com'),
        'email',
        'admin@kormo.com',
        NOW(), NOW(), NOW()
    ) ON CONFLICT (provider, provider_id) DO NOTHING;

    INSERT INTO profiles (
        id, employee_id, email, full_name, phone, role,
        department_id, branch_id, shift_id, manager_id, designation, must_change_password
    ) VALUES (
        v_admin_id, 'KORMO-002', 'admin@kormo.com', 'Tariq Hasan', '+880 1711-000002', 'admin',
        'dddddddd-0000-0000-0000-000000000003', 'bbbbbbbb-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', v_director_id, 'Head of IT & Systems', FALSE
    ) ON CONFLICT (id) DO NOTHING;

    -- 7.3 HR User
    INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, role, aud)
    VALUES (
        v_hr_id,
        '00000000-0000-0000-0000-000000000000',
        'hr@kormo.com',
        v_hash,
        NOW(),
        '{"provider":"email","providers":["email"]}',
        '{"full_name":"Nasreen Akter (HR Lead)"}',
        'authenticated',
        'authenticated'
    ) ON CONFLICT (id) DO NOTHING;

    INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
    VALUES (
        v_hr_id,
        v_hr_id,
        jsonb_build_object('sub', v_hr_id, 'email', 'hr@kormo.com'),
        'email',
        'hr@kormo.com',
        NOW(), NOW(), NOW()
    ) ON CONFLICT (provider, provider_id) DO NOTHING;

    INSERT INTO profiles (
        id, employee_id, email, full_name, phone, role,
        department_id, branch_id, shift_id, manager_id, designation, must_change_password
    ) VALUES (
        v_hr_id, 'KORMO-003', 'hr@kormo.com', 'Nasreen Akter', '+880 1711-000003', 'hr',
        'dddddddd-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', v_director_id, 'Lead HR Manager', FALSE
    ) ON CONFLICT (id) DO NOTHING;

    -- 7.4 Manager User (Engineering Dept)
    INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, role, aud)
    VALUES (
        v_manager_id,
        '00000000-0000-0000-0000-000000000000',
        'manager@kormo.com',
        v_hash,
        NOW(),
        '{"provider":"email","providers":["email"]}',
        '{"full_name":"Mahmudul Haque (Eng Manager)"}',
        'authenticated',
        'authenticated'
    ) ON CONFLICT (id) DO NOTHING;

    INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
    VALUES (
        v_manager_id,
        v_manager_id,
        jsonb_build_object('sub', v_manager_id, 'email', 'manager@kormo.com'),
        'email',
        'manager@kormo.com',
        NOW(), NOW(), NOW()
    ) ON CONFLICT (provider, provider_id) DO NOTHING;

    INSERT INTO profiles (
        id, employee_id, email, full_name, phone, role,
        department_id, branch_id, shift_id, manager_id, designation, must_change_password
    ) VALUES (
        v_manager_id, 'KORMO-004', 'manager@kormo.com', 'Mahmudul Haque', '+880 1711-000004', 'manager',
        'dddddddd-0000-0000-0000-000000000003', 'bbbbbbbb-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', v_admin_id, 'Engineering Manager', FALSE
    ) ON CONFLICT (id) DO NOTHING;

    -- 7.5 Executive User (Engineering Dept)
    INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, role, aud)
    VALUES (
        v_exec_id,
        '00000000-0000-0000-0000-000000000000',
        'executive@kormo.com',
        v_hash,
        NOW(),
        '{"provider":"email","providers":["email"]}',
        '{"full_name":"Tanvir Ahmed (Senior Exec)"}',
        'authenticated',
        'authenticated'
    ) ON CONFLICT (id) DO NOTHING;

    INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
    VALUES (
        v_exec_id,
        v_exec_id,
        jsonb_build_object('sub', v_exec_id, 'email', 'executive@kormo.com'),
        'email',
        'executive@kormo.com',
        NOW(), NOW(), NOW()
    ) ON CONFLICT (provider, provider_id) DO NOTHING;

    INSERT INTO profiles (
        id, employee_id, email, full_name, phone, role,
        department_id, branch_id, shift_id, manager_id, designation, must_change_password
    ) VALUES (
        v_exec_id, 'KORMO-005', 'executive@kormo.com', 'Tanvir Ahmed', '+880 1711-000005', 'executive',
        'dddddddd-0000-0000-0000-000000000003', 'bbbbbbbb-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', v_manager_id, 'Senior Software Executive', FALSE
    ) ON CONFLICT (id) DO NOTHING;

    -- 7.6 Employee User (Engineering Dept)
    INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, role, aud)
    VALUES (
        v_emp_id,
        '00000000-0000-0000-0000-000000000000',
        'employee@kormo.com',
        v_hash,
        NOW(),
        '{"provider":"email","providers":["email"]}',
        '{"full_name":"Fatima Zohra (Software Engineer)"}',
        'authenticated',
        'authenticated'
    ) ON CONFLICT (id) DO NOTHING;

    INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at)
    VALUES (
        v_emp_id,
        v_emp_id,
        jsonb_build_object('sub', v_emp_id, 'email', 'employee@kormo.com'),
        'email',
        'employee@kormo.com',
        NOW(), NOW(), NOW()
    ) ON CONFLICT (provider, provider_id) DO NOTHING;

    INSERT INTO profiles (
        id, employee_id, email, full_name, phone, role,
        department_id, branch_id, shift_id, manager_id, designation, must_change_password
    ) VALUES (
        v_emp_id, 'KORMO-006', 'employee@kormo.com', 'Fatima Zohra', '+880 1711-000006', 'employee',
        'dddddddd-0000-0000-0000-000000000003', 'bbbbbbbb-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', v_manager_id, 'Software Engineer', FALSE
    ) ON CONFLICT (id) DO NOTHING;

    -- 8. SEED SALARY STRUCTURES & LEAVE BALANCES FOR ALL 6 TEST USERS
    INSERT INTO leave_balances (user_id, leave_type_id, year, allocated_days, used_days)
    SELECT u.id, lt.id, 2026, lt.days_allowed, 0.0
    FROM (
        VALUES (v_director_id), (v_admin_id), (v_hr_id), (v_manager_id), (v_exec_id), (v_emp_id)
    ) AS u(id)
    CROSS JOIN leave_types lt
    ON CONFLICT (user_id, leave_type_id, year) DO NOTHING;

    INSERT INTO salary_structures (user_id, base_salary, house_rent, medical_allowance, conveyance_allowance, other_allowances, tax_deduction, other_deductions)
    VALUES
        (v_director_id, 150000.00, 60000.00, 15000.00, 10000.00, 15000.00, 25000.00, 0.00),
        (v_admin_id,    95000.00,  38000.00, 10000.00,  8000.00,  5000.00, 12000.00, 0.00),
        (v_hr_id,       85000.00,  34000.00, 10000.00,  8000.00,  5000.00, 10000.00, 0.00),
        (v_manager_id,  90000.00,  36000.00, 10000.00,  8000.00,  5000.00, 11000.00, 0.00),
        (v_exec_id,     60000.00,  24000.00,  8000.00,  6000.00,  3000.00,  5000.00, 0.00),
        (v_emp_id,      45000.00,  18000.00,  6000.00,  5000.00,  2000.00,  3000.00, 0.00)
    ON CONFLICT (user_id) DO NOTHING;

END $$;
