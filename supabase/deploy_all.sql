-- ==============================================================================
-- KORMO - Migration 01: Initial Core Schema
-- Database: PostgreSQL (Supabase)
-- Timezone: Asia/Dhaka | Currency: BDT
-- ==============================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 2. ENUMS
CREATE TYPE user_role AS ENUM (
    'director',
    'admin',
    'hr',
    'manager',
    'executive',
    'employee'
);

CREATE TYPE attendance_status AS ENUM (
    'present',
    'late',
    'half_day',
    'early_leave',
    'absent',
    'on_leave',
    'holiday',
    'weekend'
);

CREATE TYPE leave_status AS ENUM (
    'pending',
    'approved',
    'rejected',
    'cancelled'
);

CREATE TYPE task_priority AS ENUM (
    'low',
    'medium',
    'high',
    'urgent'
);

CREATE TYPE task_status AS ENUM (
    'todo',
    'in_progress',
    'under_review',
    'completed'
);

CREATE TYPE payroll_status AS ENUM (
    'draft',
    'approved',
    'locked',
    'paid'
);

CREATE TYPE employment_type AS ENUM (
    'full_time',
    'part_time',
    'contract',
    'intern'
);

-- 3. UPDATED_AT TRIGGER FUNCTION
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. SYSTEM SETTINGS TABLE
CREATE TABLE settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_name TEXT NOT NULL DEFAULT 'Kormo Enterprise Ltd.',
    company_code TEXT NOT NULL DEFAULT 'KORMO',
    company_logo_url TEXT,
    company_address TEXT DEFAULT 'Gulshan-2, Dhaka 1212, Bangladesh',
    contact_email TEXT DEFAULT 'contact@kormo.com',
    contact_phone TEXT DEFAULT '+880 1700-000000',
    currency TEXT NOT NULL DEFAULT 'BDT',
    timezone TEXT NOT NULL DEFAULT 'Asia/Dhaka',
    weekend_days TEXT[] NOT NULL DEFAULT ARRAY['friday'],
    allow_executive_add_user BOOLEAN NOT NULL DEFAULT FALSE,
    require_selfie_attendance BOOLEAN NOT NULL DEFAULT FALSE,
    require_wifi_attendance BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER update_settings_updated_at
BEFORE UPDATE ON settings
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 5. BRANCHES TABLE (with GPS coordinates and geofence radius)
CREATE TABLE branches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    code TEXT NOT NULL UNIQUE,
    address TEXT NOT NULL,
    latitude NUMERIC(10, 7) NOT NULL,
    longitude NUMERIC(10, 7) NOT NULL,
    radius_meters INTEGER NOT NULL DEFAULT 150 CHECK (radius_meters > 0),
    wifi_bssid TEXT,
    allowed_ip TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER update_branches_updated_at
BEFORE UPDATE ON branches
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 6. DEPARTMENTS TABLE
CREATE TABLE departments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    code TEXT NOT NULL UNIQUE,
    branch_id UUID REFERENCES branches(id) ON DELETE SET NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER update_departments_updated_at
BEFORE UPDATE ON departments
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 7. SHIFTS TABLE (Supports overnight/midnight shifts & grace periods)
CREATE TABLE shifts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    code TEXT NOT NULL UNIQUE,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    grace_period_mins INTEGER NOT NULL DEFAULT 15 CHECK (grace_period_mins >= 0),
    half_day_late_threshold_mins INTEGER NOT NULL DEFAULT 120,
    is_overnight BOOLEAN NOT NULL DEFAULT FALSE,
    standard_hours NUMERIC(4, 2) NOT NULL DEFAULT 8.00,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER update_shifts_updated_at
BEFORE UPDATE ON shifts
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 8. PROFILES TABLE (Mirrors auth.users with company organizational data)
CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    employee_id TEXT NOT NULL UNIQUE,
    email TEXT NOT NULL UNIQUE,
    full_name TEXT NOT NULL,
    phone TEXT,
    photo_url TEXT,
    role user_role NOT NULL DEFAULT 'employee',
    department_id UUID REFERENCES departments(id) ON DELETE SET NULL,
    branch_id UUID REFERENCES branches(id) ON DELETE SET NULL,
    shift_id UUID REFERENCES shifts(id) ON DELETE SET NULL,
    manager_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    designation TEXT,
    employment_type employment_type NOT NULL DEFAULT 'full_time',
    joining_date DATE NOT NULL DEFAULT CURRENT_DATE,
    exit_date DATE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    must_change_password BOOLEAN NOT NULL DEFAULT TRUE,
    emergency_contact_name TEXT,
    emergency_contact_phone TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_profiles_role ON profiles(role);
CREATE INDEX idx_profiles_dept ON profiles(department_id);
CREATE INDEX idx_profiles_branch ON profiles(branch_id);
CREATE INDEX idx_profiles_active ON profiles(is_active);
CREATE INDEX idx_profiles_manager ON profiles(manager_id);

CREATE TRIGGER update_profiles_updated_at
BEFORE UPDATE ON profiles
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 9. LOGIN EVENTS AUDIT TABLE
CREATE TABLE login_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    platform TEXT NOT NULL CHECK (platform IN ('web', 'android', 'ios')),
    ip_address TEXT,
    user_agent TEXT,
    device_info TEXT,
    logged_in_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_login_events_user ON login_events(user_id);
CREATE INDEX idx_login_events_time ON login_events(logged_in_at DESC);

-- 10. ATTENDANCE TABLE (One punch row per user per calendar work-day)
CREATE TABLE attendance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    branch_id UUID REFERENCES branches(id) ON DELETE SET NULL,
    date DATE NOT NULL,
    check_in TIMESTAMPTZ,
    check_out TIMESTAMPTZ,
    status attendance_status NOT NULL DEFAULT 'present',
    check_in_lat NUMERIC(10, 7),
    check_in_lng NUMERIC(10, 7),
    check_in_selfie_url TEXT,
    check_in_ip TEXT,
    check_in_wifi TEXT,
    check_out_lat NUMERIC(10, 7),
    check_out_lng NUMERIC(10, 7),
    work_minutes INTEGER NOT NULL DEFAULT 0,
    break_minutes INTEGER NOT NULL DEFAULT 0,
    overtime_minutes INTEGER NOT NULL DEFAULT 0,
    is_offline_sync BOOLEAN NOT NULL DEFAULT FALSE,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_user_attendance_date UNIQUE (user_id, date)
);

CREATE INDEX idx_attendance_user_date ON attendance(user_id, date DESC);
CREATE INDEX idx_attendance_branch_date ON attendance(branch_id, date);
CREATE INDEX idx_attendance_status ON attendance(status);
CREATE INDEX idx_attendance_date ON attendance(date);

CREATE TRIGGER update_attendance_updated_at
BEFORE UPDATE ON attendance
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 11. ATTENDANCE BREAKS TABLE
CREATE TABLE attendance_breaks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    attendance_id UUID NOT NULL REFERENCES attendance(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    start_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    end_time TIMESTAMPTZ,
    duration_minutes INTEGER NOT NULL DEFAULT 0,
    reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_attendance_breaks_attendance ON attendance_breaks(attendance_id);
CREATE INDEX idx_attendance_breaks_user ON attendance_breaks(user_id);

-- 12. ATTENDANCE CORRECTIONS TABLE
CREATE TABLE attendance_corrections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    attendance_id UUID REFERENCES attendance(id) ON DELETE SET NULL,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    request_date DATE NOT NULL,
    proposed_check_in TIMESTAMPTZ,
    proposed_check_out TIMESTAMPTZ,
    reason TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    reviewed_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    review_comment TEXT,
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_attendance_corrections_user ON attendance_corrections(user_id);
CREATE INDEX idx_attendance_corrections_status ON attendance_corrections(status);

CREATE TRIGGER update_attendance_corrections_updated_at
BEFORE UPDATE ON attendance_corrections
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 13. LEAVE TYPES TABLE
CREATE TABLE leave_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    code TEXT NOT NULL UNIQUE,
    days_allowed NUMERIC(4, 1) NOT NULL DEFAULT 14.0,
    is_paid BOOLEAN NOT NULL DEFAULT TRUE,
    requires_attachment BOOLEAN NOT NULL DEFAULT FALSE,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 14. LEAVE BALANCES TABLE (Enforces non-negative balances via CHECK constraint)
CREATE TABLE leave_balances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    leave_type_id UUID NOT NULL REFERENCES leave_types(id) ON DELETE CASCADE,
    year INTEGER NOT NULL,
    allocated_days NUMERIC(4, 1) NOT NULL DEFAULT 14.0 CHECK (allocated_days >= 0),
    used_days NUMERIC(4, 1) NOT NULL DEFAULT 0.0 CHECK (used_days >= 0),
    remaining_days NUMERIC(4, 1) GENERATED ALWAYS AS (allocated_days - used_days) STORED,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_user_leave_year UNIQUE (user_id, leave_type_id, year),
    CONSTRAINT chk_balance_non_negative CHECK (allocated_days >= used_days)
);

CREATE INDEX idx_leave_balances_user ON leave_balances(user_id, year);

CREATE TRIGGER update_leave_balances_updated_at
BEFORE UPDATE ON leave_balances
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 15. LEAVE REQUESTS TABLE
CREATE TABLE leave_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    leave_type_id UUID NOT NULL REFERENCES leave_types(id) ON DELETE CASCADE,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    total_days NUMERIC(4, 1) NOT NULL CHECK (total_days > 0),
    is_half_day BOOLEAN NOT NULL DEFAULT FALSE,
    half_day_type TEXT CHECK (half_day_type IN ('first_half', 'second_half')),
    reason TEXT NOT NULL,
    attachment_url TEXT,
    status leave_status NOT NULL DEFAULT 'pending',
    decided_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    decision_comment TEXT,
    decided_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_leave_dates CHECK (end_date >= start_date)
);

CREATE INDEX idx_leave_requests_user ON leave_requests(user_id);
CREATE INDEX idx_leave_requests_status ON leave_requests(status);
CREATE INDEX idx_leave_requests_dates ON leave_requests(start_date, end_date);

CREATE TRIGGER update_leave_requests_updated_at
BEFORE UPDATE ON leave_requests
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 16. HOLIDAYS TABLE
CREATE TABLE holidays (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    date DATE NOT NULL UNIQUE,
    description TEXT,
    is_optional BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_holidays_date ON holidays(date);

-- 17. TASKS TABLE
CREATE TABLE tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT,
    assigned_to UUID REFERENCES profiles(id) ON DELETE SET NULL,
    created_by UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    department_id UUID REFERENCES departments(id) ON DELETE SET NULL,
    priority task_priority NOT NULL DEFAULT 'medium',
    status task_status NOT NULL DEFAULT 'todo',
    due_date TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_tasks_assigned ON tasks(assigned_to);
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_dept ON tasks(department_id);

CREATE TRIGGER update_tasks_updated_at
BEFORE UPDATE ON tasks
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 18. TASK COMMENTS TABLE
CREATE TABLE task_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    attachment_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_task_comments_task ON task_comments(task_id);

-- 19. NOTICES TABLE
CREATE TABLE notices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    published_by UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    target_type TEXT NOT NULL DEFAULT 'all' CHECK (target_type IN ('all', 'branch', 'department')),
    target_branch_id UUID REFERENCES branches(id) ON DELETE CASCADE,
    target_department_id UUID REFERENCES departments(id) ON DELETE CASCADE,
    is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notices_target ON notices(target_type, target_branch_id, target_department_id);

CREATE TRIGGER update_notices_updated_at
BEFORE UPDATE ON notices
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 20. NOTICE READS TABLE
CREATE TABLE notice_reads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    notice_id UUID NOT NULL REFERENCES notices(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    read_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_notice_user_read UNIQUE (notice_id, user_id)
);

CREATE INDEX idx_notice_reads_notice ON notice_reads(notice_id);

-- 21. NOTIFICATIONS TABLE
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT NOT NULL,
    reference_id TEXT,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notifications_user_unread ON notifications(user_id, is_read);

-- 22. SALARY STRUCTURES TABLE (BDT Currency)
CREATE TABLE salary_structures (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,
    base_salary NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (base_salary >= 0),
    house_rent NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (house_rent >= 0),
    medical_allowance NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (medical_allowance >= 0),
    conveyance_allowance NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (conveyance_allowance >= 0),
    other_allowances NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (other_allowances >= 0),
    tax_deduction NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (tax_deduction >= 0),
    other_deductions NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (other_deductions >= 0),
    gross_salary NUMERIC(12, 2) GENERATED ALWAYS AS (
        base_salary + house_rent + medical_allowance + conveyance_allowance + other_allowances
    ) STORED,
    net_salary NUMERIC(12, 2) GENERATED ALWAYS AS (
        base_salary + house_rent + medical_allowance + conveyance_allowance + other_allowances - tax_deduction - other_deductions
    ) STORED,
    effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER update_salary_structures_updated_at
BEFORE UPDATE ON salary_structures
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 23. PAYROLL RUNS TABLE
CREATE TABLE payroll_runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    month INTEGER NOT NULL CHECK (month BETWEEN 1 AND 12),
    year INTEGER NOT NULL CHECK (year >= 2020),
    status payroll_status NOT NULL DEFAULT 'draft',
    total_gross NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    total_deductions NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    total_net NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    approved_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    approved_at TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_payroll_run_month_year UNIQUE (month, year)
);

CREATE INDEX idx_payroll_runs_year_month ON payroll_runs(year, month);

CREATE TRIGGER update_payroll_runs_updated_at
BEFORE UPDATE ON payroll_runs
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 24. PAYSLIPS TABLE
CREATE TABLE payslips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payroll_run_id UUID NOT NULL REFERENCES payroll_runs(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    base_salary NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    allowances NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    overtime_pay NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    unpaid_leave_deductions NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    late_deductions NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    tax_deductions NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    other_deductions NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    net_pay NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    payment_status TEXT NOT NULL DEFAULT 'unpaid' CHECK (payment_status IN ('unpaid', 'paid')),
    pdf_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_payslip_run_user UNIQUE (payroll_run_id, user_id)
);

CREATE INDEX idx_payslips_user ON payslips(user_id);
CREATE INDEX idx_payslips_run ON payslips(payroll_run_id);

-- 25. DOCUMENTS TABLE
CREATE TABLE documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('contract', 'nid_passport', 'certificate', 'policy', 'other')),
    file_url TEXT NOT NULL,
    file_size_bytes BIGINT,
    mime_type TEXT,
    uploaded_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_documents_user ON documents(user_id);

-- 26. ONBOARDING & OFFBOARDING ITEMS TABLE
CREATE TABLE onboarding_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('onboarding', 'offboarding')),
    is_completed BOOLEAN NOT NULL DEFAULT FALSE,
    completed_at TIMESTAMPTZ,
    assigned_to UUID REFERENCES profiles(id) ON DELETE SET NULL,
    due_date DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_onboarding_items_user ON onboarding_items(user_id, type);

-- 27. IMMUTABLE AUDIT LOGS TABLE (Zero UPDATE or DELETE allowed)
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    action TEXT NOT NULL,
    table_name TEXT NOT NULL,
    record_id TEXT,
    old_data JSONB,
    new_data JSONB,
    platform TEXT NOT NULL DEFAULT 'web' CHECK (platform IN ('web', 'android', 'system')),
    ip_address TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_logs_actor ON audit_logs(actor_id);
CREATE INDEX idx_audit_logs_table ON audit_logs(table_name, record_id);
CREATE INDEX idx_audit_logs_created ON audit_logs(created_at DESC);

-- Trigger to prevent any mutation or deletion on audit_logs
CREATE OR REPLACE FUNCTION prevent_audit_log_modification()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'audit_logs entries are strictly immutable. UPDATE and DELETE are prohibited by security policy.';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_immutable_audit_logs
BEFORE UPDATE OR DELETE ON audit_logs
FOR EACH ROW EXECUTE FUNCTION prevent_audit_log_modification();
-- ==============================================================================
-- KORMO - Migration 02: Row Level Security (RLS) & Security Definer Helpers
-- Database: PostgreSQL (Supabase)
-- ==============================================================================

-- 1. SECURITY DEFINER HELPER FUNCTIONS (fixed search_path = public)
CREATE OR REPLACE FUNCTION public.current_role()
RETURNS user_role
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT role FROM public.profiles WHERE id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.current_dept()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT department_id FROM public.profiles WHERE id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.current_branch()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT branch_id FROM public.profiles WHERE id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.is_active()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT COALESCE((SELECT is_active FROM public.profiles WHERE id = auth.uid()), FALSE);
$$;

-- Hierarchy check: returns true if the authenticated user has authority over target_role and dept
CREATE OR REPLACE FUNCTION public.can_create(p_target_role user_role, p_target_dept_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_actor_role user_role;
    v_actor_dept UUID;
    v_allow_exec BOOLEAN;
BEGIN
    -- Disabled users have no permissions
    IF NOT public.is_active() THEN
        RETURN FALSE;
    END IF;

    v_actor_role := public.current_role();
    v_actor_dept := public.current_dept();

    -- Director can create any role beneath director for any department
    IF v_actor_role = 'director' THEN
        RETURN p_target_role IN ('admin', 'hr', 'manager', 'executive', 'employee');
    END IF;

    -- Admin can create hr, manager, executive, employee for any department
    IF v_actor_role = 'admin' THEN
        RETURN p_target_role IN ('hr', 'manager', 'executive', 'employee');
    END IF;

    -- HR can create manager, executive, employee for any department
    IF v_actor_role = 'hr' THEN
        RETURN p_target_role IN ('manager', 'executive', 'employee');
    END IF;

    -- Manager can create executive and employee for OWN department only
    IF v_actor_role = 'manager' THEN
        RETURN p_target_role IN ('executive', 'employee') AND (p_target_dept_id = v_actor_dept);
    END IF;

    -- Executive can create employee for OWN department only, IF allow_executive_add_user toggle is ON
    IF v_actor_role = 'executive' THEN
        SELECT allow_executive_add_user INTO v_allow_exec FROM public.settings LIMIT 1;
        RETURN COALESCE(v_allow_exec, FALSE) AND (p_target_role = 'employee') AND (p_target_dept_id = v_actor_dept);
    END IF;

    -- Employee cannot create anyone
    RETURN FALSE;
END;
$$;

-- 2. ENABLE RLS ON ALL TABLES
ALTER TABLE settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE login_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance_breaks ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance_corrections ENABLE ROW LEVEL SECURITY;
ALTER TABLE leave_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE leave_balances ENABLE ROW LEVEL SECURITY;
ALTER TABLE leave_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE holidays ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE notices ENABLE ROW LEVEL SECURITY;
ALTER TABLE notice_reads ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE salary_structures ENABLE ROW LEVEL SECURITY;
ALTER TABLE payroll_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE payslips ENABLE ROW LEVEL SECURITY;
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE onboarding_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- 3. POLICIES: SETTINGS, BRANCHES, DEPARTMENTS, SHIFTS, HOLIDAYS
-- Everyone active can view organization metadata
CREATE POLICY "Active users can view settings" ON settings
    FOR SELECT TO authenticated USING (public.is_active());

CREATE POLICY "Admin and Director can update settings" ON settings
    FOR UPDATE TO authenticated USING (public.current_role() IN ('director', 'admin'));

CREATE POLICY "Active users can view branches" ON branches
    FOR SELECT TO authenticated USING (public.is_active());

CREATE POLICY "Admin and Director manage branches" ON branches
    FOR ALL TO authenticated USING (public.current_role() IN ('director', 'admin'));

CREATE POLICY "Active users can view departments" ON departments
    FOR SELECT TO authenticated USING (public.is_active());

CREATE POLICY "Admin and Director manage departments" ON departments
    FOR ALL TO authenticated USING (public.current_role() IN ('director', 'admin'));

CREATE POLICY "Active users can view shifts" ON shifts
    FOR SELECT TO authenticated USING (public.is_active());

CREATE POLICY "Admin and Director manage shifts" ON shifts
    FOR ALL TO authenticated USING (public.current_role() IN ('director', 'admin'));

CREATE POLICY "Active users can view holidays" ON holidays
    FOR SELECT TO authenticated USING (public.is_active());

CREATE POLICY "Admin and HR and Director manage holidays" ON holidays
    FOR ALL TO authenticated USING (public.current_role() IN ('director', 'admin', 'hr'));

-- 4. POLICIES: PROFILES
-- Active users can view profiles (coworkers)
CREATE POLICY "Active users can view active profiles" ON profiles
    FOR SELECT TO authenticated
    USING (public.is_active() AND (is_active = TRUE OR public.current_role() IN ('director', 'admin', 'hr')));

-- Users can update basic self profile info (photo, phone, emergency contacts)
CREATE POLICY "Users can update self contact profile" ON profiles
    FOR UPDATE TO authenticated
    USING (auth.uid() = id)
    WITH CHECK (
        auth.uid() = id
        -- Direct role or department modification by regular users is blocked
        AND role = (SELECT p.role FROM profiles p WHERE p.id = auth.uid())
        AND department_id IS NOT DISTINCT FROM (SELECT p.department_id FROM profiles p WHERE p.id = auth.uid())
    );

-- Admins, HR, Directors can update profiles
CREATE POLICY "Management can update profiles" ON profiles
    FOR UPDATE TO authenticated
    USING (public.current_role() IN ('director', 'admin', 'hr'));

-- Direct INSERT is blocked for regular users; performed by create-user Edge Function or database seeds
CREATE POLICY "Service role can insert profiles" ON profiles
    FOR INSERT TO service_role WITH CHECK (TRUE);

-- 5. POLICIES: LOGIN_EVENTS
CREATE POLICY "Users and management can view login events" ON login_events
    FOR SELECT TO authenticated
    USING (
        user_id = auth.uid()
        OR public.current_role() IN ('director', 'admin')
    );

CREATE POLICY "Authenticated users can record their own login event" ON login_events
    FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());

-- 6. POLICIES: ATTENDANCE & BREAKS
CREATE POLICY "View attendance policy" ON attendance
    FOR SELECT TO authenticated
    USING (
        public.is_active() AND (
            user_id = auth.uid()
            OR (public.current_role() = 'manager' AND user_id IN (
                SELECT id FROM profiles WHERE department_id = public.current_dept()
            ))
            OR public.current_role() IN ('director', 'admin', 'hr')
        )
    );

CREATE POLICY "Users can insert own attendance punch" ON attendance
    FOR INSERT TO authenticated
    WITH CHECK (public.is_active() AND user_id = auth.uid());

CREATE POLICY "Users can update own check_out punch" ON attendance
    FOR UPDATE TO authenticated
    USING (public.is_active() AND (user_id = auth.uid() OR public.current_role() IN ('director', 'admin', 'hr')))
    WITH CHECK (public.is_active() AND (user_id = auth.uid() OR public.current_role() IN ('director', 'admin', 'hr')));

CREATE POLICY "View breaks policy" ON attendance_breaks
    FOR SELECT TO authenticated
    USING (
        public.is_active() AND (
            user_id = auth.uid()
            OR (public.current_role() = 'manager' AND user_id IN (
                SELECT id FROM profiles WHERE department_id = public.current_dept()
            ))
            OR public.current_role() IN ('director', 'admin', 'hr')
        )
    );

CREATE POLICY "Users can manage own breaks" ON attendance_breaks
    FOR ALL TO authenticated
    USING (public.is_active() AND user_id = auth.uid())
    WITH CHECK (public.is_active() AND user_id = auth.uid());

-- 7. POLICIES: ATTENDANCE CORRECTIONS
CREATE POLICY "View corrections policy" ON attendance_corrections
    FOR SELECT TO authenticated
    USING (
        public.is_active() AND (
            user_id = auth.uid()
            OR (public.current_role() = 'manager' AND user_id IN (
                SELECT id FROM profiles WHERE department_id = public.current_dept()
            ))
            OR public.current_role() IN ('director', 'admin', 'hr')
        )
    );

CREATE POLICY "Employees can submit correction requests" ON attendance_corrections
    FOR INSERT TO authenticated
    WITH CHECK (public.is_active() AND user_id = auth.uid());

CREATE POLICY "Managers and HR can review corrections" ON attendance_corrections
    FOR UPDATE TO authenticated
    USING (
        public.is_active() AND (
            (public.current_role() = 'manager' AND user_id IN (
                SELECT id FROM profiles WHERE department_id = public.current_dept()
            ))
            OR public.current_role() IN ('director', 'admin', 'hr')
        )
    );

-- 8. POLICIES: LEAVE TYPES, BALANCES & REQUESTS
CREATE POLICY "Active users view leave types" ON leave_types
    FOR SELECT TO authenticated USING (public.is_active());

CREATE POLICY "HR and Admin manage leave types" ON leave_types
    FOR ALL TO authenticated USING (public.current_role() IN ('director', 'admin', 'hr'));

CREATE POLICY "View leave balances policy" ON leave_balances
    FOR SELECT TO authenticated
    USING (
        public.is_active() AND (
            user_id = auth.uid()
            OR (public.current_role() = 'manager' AND user_id IN (
                SELECT id FROM profiles WHERE department_id = public.current_dept()
            ))
            OR public.current_role() IN ('director', 'admin', 'hr')
        )
    );

CREATE POLICY "HR and Admin manage leave balances" ON leave_balances
    FOR ALL TO authenticated USING (public.current_role() IN ('director', 'admin', 'hr'));

CREATE POLICY "View leave requests policy" ON leave_requests
    FOR SELECT TO authenticated
    USING (
        public.is_active() AND (
            user_id = auth.uid()
            OR (public.current_role() = 'manager' AND user_id IN (
                SELECT id FROM profiles WHERE department_id = public.current_dept()
            ))
            OR public.current_role() IN ('director', 'admin', 'hr')
        )
    );

CREATE POLICY "Employees can apply for leave" ON leave_requests
    FOR INSERT TO authenticated
    WITH CHECK (public.is_active() AND user_id = auth.uid());

CREATE POLICY "Users can cancel pending or Managers/HR can decide" ON leave_requests
    FOR UPDATE TO authenticated
    USING (
        public.is_active() AND (
            (user_id = auth.uid() AND status = 'pending')
            OR (public.current_role() = 'manager' AND user_id IN (
                SELECT id FROM profiles WHERE department_id = public.current_dept()
            ))
            OR public.current_role() IN ('director', 'admin', 'hr')
        )
    );

-- 9. POLICIES: TASKS & TASK COMMENTS
CREATE POLICY "View tasks policy" ON tasks
    FOR SELECT TO authenticated
    USING (
        public.is_active() AND (
            assigned_to = auth.uid()
            OR created_by = auth.uid()
            OR (department_id IS NOT NULL AND department_id = public.current_dept())
            OR public.current_role() IN ('director', 'admin', 'hr')
        )
    );

CREATE POLICY "Create tasks policy" ON tasks
    FOR INSERT TO authenticated
    WITH CHECK (
        public.is_active() AND (
            public.current_role() IN ('director', 'admin', 'hr')
            OR (public.current_role() = 'manager' AND (department_id = public.current_dept() OR department_id IS NULL))
            OR (public.current_role() IN ('executive', 'employee') AND created_by = auth.uid())
        )
    );

CREATE POLICY "Update tasks policy" ON tasks
    FOR UPDATE TO authenticated
    USING (
        public.is_active() AND (
            assigned_to = auth.uid()
            OR created_by = auth.uid()
            OR (public.current_role() = 'manager' AND department_id = public.current_dept())
            OR public.current_role() IN ('director', 'admin', 'hr')
        )
    );

CREATE POLICY "View task comments" ON task_comments
    FOR SELECT TO authenticated
    USING (
        public.is_active() AND EXISTS (
            SELECT 1 FROM tasks t WHERE t.id = task_id AND (
                t.assigned_to = auth.uid()
                OR t.created_by = auth.uid()
                OR (t.department_id IS NOT NULL AND t.department_id = public.current_dept())
                OR public.current_role() IN ('director', 'admin', 'hr')
            )
        )
    );

CREATE POLICY "Insert task comments" ON task_comments
    FOR INSERT TO authenticated
    WITH CHECK (public.is_active() AND user_id = auth.uid());

-- 10. POLICIES: NOTICES & NOTICE READS
CREATE POLICY "View notices policy" ON notices
    FOR SELECT TO authenticated
    USING (
        public.is_active() AND (
            target_type = 'all'
            OR (target_type = 'branch' AND target_branch_id = public.current_branch())
            OR (target_type = 'department' AND target_department_id = public.current_dept())
            OR public.current_role() IN ('director', 'admin', 'hr')
        )
    );

CREATE POLICY "Publish notices policy" ON notices
    FOR ALL TO authenticated
    USING (public.current_role() IN ('director', 'admin', 'hr'));

CREATE POLICY "Notice reads self manage" ON notice_reads
    FOR ALL TO authenticated
    USING (public.is_active() AND user_id = auth.uid())
    WITH CHECK (public.is_active() AND user_id = auth.uid());

-- 11. POLICIES: NOTIFICATIONS
CREATE POLICY "Notifications self manage" ON notifications
    FOR ALL TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- 12. POLICIES: SALARY STRUCTURES (Strict Role Privacy)
CREATE POLICY "View salary structures policy" ON salary_structures
    FOR SELECT TO authenticated
    USING (
        public.is_active() AND (
            user_id = auth.uid()
            OR public.current_role() IN ('director', 'admin', 'hr')
        )
    );

CREATE POLICY "Manage salary structures policy" ON salary_structures
    FOR ALL TO authenticated
    USING (public.current_role() IN ('director', 'admin', 'hr'));

-- 13. POLICIES: PAYROLL RUNS & PAYSLIPS
CREATE POLICY "View payroll runs policy" ON payroll_runs
    FOR SELECT TO authenticated
    USING (public.current_role() IN ('director', 'admin', 'hr'));

CREATE POLICY "Admin and HR manage payroll draft" ON payroll_runs
    FOR ALL TO authenticated
    USING (public.current_role() IN ('director', 'admin', 'hr'));

CREATE POLICY "View payslips policy" ON payslips
    FOR SELECT TO authenticated
    USING (
        public.is_active() AND (
            user_id = auth.uid()
            OR public.current_role() IN ('director', 'admin', 'hr')
        )
    );

CREATE POLICY "HR and Admin manage payslips" ON payslips
    FOR ALL TO authenticated
    USING (
        public.current_role() IN ('director', 'admin', 'hr')
        AND (
            SELECT status FROM payroll_runs WHERE id = payroll_run_id
        ) != 'locked'
    );

-- 14. POLICIES: DOCUMENTS & ONBOARDING
CREATE POLICY "View documents policy" ON documents
    FOR SELECT TO authenticated
    USING (
        public.is_active() AND (
            user_id = auth.uid()
            OR category = 'policy'
            OR public.current_role() IN ('director', 'admin', 'hr')
        )
    );

CREATE POLICY "Upload documents policy" ON documents
    FOR INSERT TO authenticated
    WITH CHECK (
        public.is_active() AND (
            user_id = auth.uid()
            OR public.current_role() IN ('director', 'admin', 'hr')
        )
    );

CREATE POLICY "View onboarding items" ON onboarding_items
    FOR SELECT TO authenticated
    USING (
        public.is_active() AND (
            user_id = auth.uid()
            OR assigned_to = auth.uid()
            OR public.current_role() IN ('director', 'admin', 'hr')
        )
    );

CREATE POLICY "Manage onboarding items" ON onboarding_items
    FOR ALL TO authenticated
    USING (
        public.is_active() AND (
            assigned_to = auth.uid()
            OR public.current_role() IN ('director', 'admin', 'hr')
        )
    );

-- 15. POLICIES: AUDIT LOGS (Immutable & Scoped)
CREATE POLICY "View audit logs policy" ON audit_logs
    FOR SELECT TO authenticated
    USING (public.current_role() IN ('director', 'admin'));

-- Direct INSERT permitted for security triggers and authenticated actors
CREATE POLICY "Audit logs insert policy" ON audit_logs
    FOR INSERT TO authenticated
    WITH CHECK (actor_id = auth.uid());
-- ==============================================================================
-- KORMO - Migration 03: Core Business Logic RPC Functions
-- Database: PostgreSQL (Supabase)
-- Timezone: Asia/Dhaka (Tamper-proof server clock)
-- ==============================================================================

-- 1. HAVERSINE DISTANCE HELPER FUNCTION (meters)
CREATE OR REPLACE FUNCTION public.haversine_distance(
    lat1 NUMERIC, lon1 NUMERIC,
    lat2 NUMERIC, lon2 NUMERIC
)
RETURNS NUMERIC AS $$
DECLARE
    R NUMERIC := 6371000; -- Earth's radius in meters
    dLat NUMERIC := radians(lat2 - lat1);
    dLon NUMERIC := radians(lon2 - lon1);
    a NUMERIC;
    c NUMERIC;
BEGIN
    a := sin(dLat / 2) * sin(dLat / 2) +
         cos(radians(lat1)) * cos(radians(lat2)) *
         sin(dLon / 2) * sin(dLon / 2);
    c := 2 * atan2(sqrt(a), sqrt(1 - a));
    RETURN R * c;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- 2. SERVER-TIME TAMPER-PROOF CHECK-IN RPC
CREATE OR REPLACE FUNCTION public.check_in(
    p_branch_id UUID,
    p_lat NUMERIC,
    p_lng NUMERIC,
    p_selfie_url TEXT DEFAULT NULL,
    p_ip TEXT DEFAULT NULL,
    p_wifi TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_user profiles%ROWTYPE;
    v_branch branches%ROWTYPE;
    v_shift shifts%ROWTYPE;
    v_today DATE := (NOW() AT TIME ZONE 'Asia/Dhaka')::DATE;
    v_now TIMESTAMPTZ := NOW();
    v_now_time TIME := (NOW() AT TIME ZONE 'Asia/Dhaka')::TIME;
    v_existing_attendance attendance%ROWTYPE;
    v_distance NUMERIC;
    v_status attendance_status := 'present';
    v_grace_limit TIME;
    v_half_day_limit TIME;
    v_result attendance%ROWTYPE;
BEGIN
    -- Check user active status
    SELECT * INTO v_user FROM profiles WHERE id = v_user_id;
    IF NOT FOUND OR NOT v_user.is_active THEN
        RAISE EXCEPTION 'User profile not found or account is deactivated.';
    END IF;

    -- Double check-in prevention & idempotency
    SELECT * INTO v_existing_attendance
    FROM attendance
    WHERE user_id = v_user_id AND date = v_today;

    IF FOUND AND v_existing_attendance.check_in IS NOT NULL THEN
        RAISE EXCEPTION 'Double check-in prohibited: You have already checked in today at %',
            to_char(v_existing_attendance.check_in AT TIME ZONE 'Asia/Dhaka', 'HH12:MI AM');
    END IF;

    -- Validate branch & geofence
    SELECT * INTO v_branch FROM branches WHERE id = COALESCE(p_branch_id, v_user.branch_id);
    IF FOUND AND p_lat IS NOT NULL AND p_lng IS NOT NULL THEN
        v_distance := public.haversine_distance(p_lat, p_lng, v_branch.latitude, v_branch.longitude);
        IF v_distance > v_branch.radius_meters THEN
            RAISE EXCEPTION 'Geofence violation: You are % meters away from branch "%" (Maximum allowed: % meters).',
                round(v_distance, 1), v_branch.name, v_branch.radius_meters;
        END IF;
    END IF;

    -- Determine shift and attendance status (Present vs Late vs Half-Day)
    IF v_user.shift_id IS NOT NULL THEN
        SELECT * INTO v_shift FROM shifts WHERE id = v_user.shift_id;
        IF FOUND THEN
            v_grace_limit := v_shift.start_time + (v_shift.grace_period_mins || ' minutes')::interval;
            v_half_day_limit := v_shift.start_time + (v_shift.half_day_late_threshold_mins || ' minutes')::interval;

            IF v_now_time > v_half_day_limit THEN
                v_status := 'half_day';
            ELSIF v_now_time > v_grace_limit THEN
                v_status := 'late';
            ELSE
                v_status := 'present';
            END IF;
        END IF;
    END IF;

    -- Upsert attendance record
    INSERT INTO attendance (
        user_id,
        branch_id,
        date,
        check_in,
        status,
        check_in_lat,
        check_in_lng,
        check_in_selfie_url,
        check_in_ip,
        check_in_wifi,
        created_at,
        updated_at
    ) VALUES (
        v_user_id,
        v_branch.id,
        v_today,
        v_now,
        v_status,
        p_lat,
        p_lng,
        p_selfie_url,
        p_ip,
        p_wifi,
        v_now,
        v_now
    )
    ON CONFLICT (user_id, date) DO UPDATE SET
        check_in = EXCLUDED.check_in,
        status = EXCLUDED.status,
        check_in_lat = EXCLUDED.check_in_lat,
        check_in_lng = EXCLUDED.check_in_lng,
        check_in_selfie_url = EXCLUDED.check_in_selfie_url,
        check_in_ip = EXCLUDED.check_in_ip,
        check_in_wifi = EXCLUDED.check_in_wifi,
        updated_at = v_now
    RETURNING * INTO v_result;

    RETURN jsonb_build_object(
        'success', TRUE,
        'attendance_id', v_result.id,
        'status', v_result.status,
        'check_in', v_result.check_in,
        'message', 'Check-in successful.'
    );
END;
$$;

-- 3. SERVER-TIME TAMPER-PROOF CHECK-OUT RPC
CREATE OR REPLACE FUNCTION public.check_out(
    p_lat NUMERIC DEFAULT NULL,
    p_lng NUMERIC DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_user profiles%ROWTYPE;
    v_shift shifts%ROWTYPE;
    v_today DATE := (NOW() AT TIME ZONE 'Asia/Dhaka')::DATE;
    v_now TIMESTAMPTZ := NOW();
    v_att attendance%ROWTYPE;
    v_work_minutes INTEGER;
    v_overtime_minutes INTEGER := 0;
    v_standard_minutes INTEGER := 480; -- 8 hours
    v_status attendance_status;
    v_result attendance%ROWTYPE;
BEGIN
    SELECT * INTO v_att
    FROM attendance
    WHERE user_id = v_user_id AND date = v_today;

    IF NOT FOUND OR v_att.check_in IS NULL THEN
        RAISE EXCEPTION 'No active check-in found for today. Please check in first.';
    END IF;

    -- Calculate work minutes minus breaks
    v_work_minutes := EXTRACT(EPOCH FROM (v_now - v_att.check_in)) / 60;
    v_work_minutes := GREATEST(0, v_work_minutes - v_att.break_minutes);

    -- Check shift standard hours
    SELECT * INTO v_user FROM profiles WHERE id = v_user_id;
    IF v_user.shift_id IS NOT NULL THEN
        SELECT * INTO v_shift FROM shifts WHERE id = v_user.shift_id;
        IF FOUND THEN
            v_standard_minutes := (v_shift.standard_hours * 60)::INTEGER;
        END IF;
    END IF;

    -- Overtime calculation
    IF v_work_minutes > v_standard_minutes THEN
        v_overtime_minutes := v_work_minutes - v_standard_minutes;
    END IF;

    -- Preserve status if was late or half-day, otherwise check early leave
    v_status := v_att.status;
    IF v_status = 'present' AND v_work_minutes < (v_standard_minutes - 60) THEN
        v_status := 'early_leave';
    END IF;

    UPDATE attendance SET
        check_out = v_now,
        check_out_lat = p_lat,
        check_out_lng = p_lng,
        work_minutes = v_work_minutes,
        overtime_minutes = v_overtime_minutes,
        status = v_status,
        updated_at = v_now
    WHERE id = v_att.id
    RETURNING * INTO v_result;

    RETURN jsonb_build_object(
        'success', TRUE,
        'attendance_id', v_result.id,
        'check_out', v_result.check_out,
        'work_minutes', v_result.work_minutes,
        'overtime_minutes', v_result.overtime_minutes,
        'status', v_result.status,
        'message', 'Check-out successful.'
    );
END;
$$;

-- 4. APPLY LEAVE RPC (Enforces non-negative balance)
CREATE OR REPLACE FUNCTION public.apply_leave(
    p_leave_type_id UUID,
    p_start_date DATE,
    p_end_date DATE,
    p_is_half_day BOOLEAN DEFAULT FALSE,
    p_half_day_type TEXT DEFAULT NULL,
    p_reason TEXT DEFAULT '',
    p_attachment_url TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_total_days NUMERIC(4, 1);
    v_year INTEGER := EXTRACT(YEAR FROM p_start_date);
    v_balance leave_balances%ROWTYPE;
    v_existing_overlap INTEGER;
    v_req leave_requests%ROWTYPE;
BEGIN
    IF p_end_date < p_start_date THEN
        RAISE EXCEPTION 'End date must be greater than or equal to start date.';
    END IF;

    IF p_is_half_day THEN
        v_total_days := 0.5;
    ELSE
        v_total_days := (p_end_date - p_start_date + 1)::NUMERIC;
    END IF;

    -- Verify leave balance
    SELECT * INTO v_balance
    FROM leave_balances
    WHERE user_id = v_user_id AND leave_type_id = p_leave_type_id AND year = v_year;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No leave balance allocated for this leave type in year %.', v_year;
    END IF;

    IF v_balance.remaining_days < v_total_days THEN
        RAISE EXCEPTION 'Insufficient leave balance: You requested % days, but have only % days remaining.',
            v_total_days, v_balance.remaining_days;
    END IF;

    -- Check overlapping leaves
    SELECT COUNT(*) INTO v_existing_overlap
    FROM leave_requests
    WHERE user_id = v_user_id
      AND status IN ('pending', 'approved')
      AND (
          (start_date <= p_end_date AND end_date >= p_start_date)
      );

    IF v_existing_overlap > 0 THEN
        RAISE EXCEPTION 'Overlapping leave request already exists for the selected dates.';
    END IF;

    -- Insert request
    INSERT INTO leave_requests (
        user_id,
        leave_type_id,
        start_date,
        end_date,
        total_days,
        is_half_day,
        half_day_type,
        reason,
        attachment_url,
        status
    ) VALUES (
        v_user_id,
        p_leave_type_id,
        p_start_date,
        p_end_date,
        v_total_days,
        p_is_half_day,
        p_half_day_type,
        p_reason,
        p_attachment_url,
        'pending'
    ) RETURNING * INTO v_req;

    RETURN jsonb_build_object(
        'success', TRUE,
        'request_id', v_req.id,
        'total_days', v_req.total_days,
        'status', v_req.status,
        'message', 'Leave application submitted successfully.'
    );
END;
$$;

-- 5. DECIDE LEAVE RPC (Approves / Rejects & Debits Balance Atomically)
CREATE OR REPLACE FUNCTION public.decide_leave(
    p_request_id UUID,
    p_status leave_status,
    p_comment TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_actor_id UUID := auth.uid();
    v_actor_role user_role := public.current_role();
    v_req leave_requests%ROWTYPE;
    v_applicant profiles%ROWTYPE;
    v_balance leave_balances%ROWTYPE;
    v_year INTEGER;
BEGIN
    SELECT * INTO v_req FROM leave_requests WHERE id = p_request_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Leave request not found.';
    END IF;

    IF v_req.status != 'pending' THEN
        RAISE EXCEPTION 'Leave request is already % and cannot be modified.', v_req.status;
    END IF;

    SELECT * INTO v_applicant FROM profiles WHERE id = v_req.user_id;

    -- Permission check
    IF v_actor_role NOT IN ('director', 'admin', 'hr') THEN
        IF v_actor_role = 'manager' AND v_applicant.department_id != public.current_dept() THEN
            RAISE EXCEPTION 'Unauthorized: Managers can only approve leave for their own department.';
        ELSIF v_actor_role NOT IN ('manager') THEN
            RAISE EXCEPTION 'Unauthorized: You lack permissions to approve or reject leave requests.';
        END IF;
    END IF;

    v_year := EXTRACT(YEAR FROM v_req.start_date);

    IF p_status = 'approved' THEN
        -- Atomic debit with check
        SELECT * INTO v_balance
        FROM leave_balances
        WHERE user_id = v_req.user_id AND leave_type_id = v_req.leave_type_id AND year = v_year
        FOR UPDATE;

        IF v_balance.remaining_days < v_req.total_days THEN
            RAISE EXCEPTION 'Cannot approve: User remaining balance (% days) is lower than requested (% days).',
                v_balance.remaining_days, v_req.total_days;
        END IF;

        UPDATE leave_balances
        SET used_days = used_days + v_req.total_days,
            updated_at = NOW()
        WHERE id = v_balance.id;

        -- Record notification
        INSERT INTO notifications (user_id, title, message, type, reference_id)
        VALUES (
            v_req.user_id,
            'Leave Request Approved',
            'Your leave application for ' || v_req.total_days || ' day(s) has been approved.',
            'leave',
            v_req.id::TEXT
        );
    ELSIF p_status = 'rejected' THEN
        INSERT INTO notifications (user_id, title, message, type, reference_id)
        VALUES (
            v_req.user_id,
            'Leave Request Rejected',
            'Your leave application was rejected: ' || COALESCE(p_comment, 'No specific reason provided.'),
            'leave',
            v_req.id::TEXT
        );
    END IF;

    UPDATE leave_requests SET
        status = p_status,
        decided_by = v_actor_id,
        decision_comment = p_comment,
        decided_at = NOW(),
        updated_at = NOW()
    WHERE id = v_req.id;

    -- Audit log
    INSERT INTO audit_logs (
        actor_id,
        action,
        table_name,
        record_id,
        old_data,
        new_data,
        platform
    ) VALUES (
        v_actor_id,
        'DECIDE_LEAVE',
        'leave_requests',
        v_req.id::TEXT,
        to_jsonb(v_req),
        jsonb_build_object('status', p_status, 'comment', p_comment),
        'web'
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'request_id', v_req.id,
        'status', p_status,
        'message', 'Leave decision recorded successfully.'
    );
END;
$$;

-- 6. RUN PAYROLL DRAFT GENERATOR RPC
CREATE OR REPLACE FUNCTION public.generate_payroll_run(
    p_month INTEGER,
    p_year INTEGER,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_actor_id UUID := auth.uid();
    v_run payroll_runs%ROWTYPE;
    v_emp RECORD;
    v_structure salary_structures%ROWTYPE;
    v_unpaid_days NUMERIC := 0;
    v_late_count INTEGER := 0;
    v_ot_minutes INTEGER := 0;
    v_daily_rate NUMERIC(12, 2);
    v_hourly_rate NUMERIC(12, 2);
    v_unpaid_deduction NUMERIC(12, 2);
    v_late_deduction NUMERIC(12, 2);
    v_ot_pay NUMERIC(12, 2);
    v_net_pay NUMERIC(12, 2);
    v_total_gross NUMERIC(14, 2) := 0;
    v_total_deductions NUMERIC(14, 2) := 0;
    v_total_net NUMERIC(14, 2) := 0;
BEGIN
    IF public.current_role() NOT IN ('director', 'admin', 'hr') THEN
        RAISE EXCEPTION 'Unauthorized: Only Director, Admin, or HR can generate payroll runs.';
    END IF;

    -- Create or fetch draft run
    SELECT * INTO v_run FROM payroll_runs WHERE month = p_month AND year = p_year;
    IF FOUND THEN
        IF v_run.status = 'locked' THEN
            RAISE EXCEPTION 'Payroll run for %/% is locked and cannot be regenerated.', p_month, p_year;
        END IF;
        -- Delete existing draft payslips to regenerate
        DELETE FROM payslips WHERE payroll_run_id = v_run.id;
    ELSE
        INSERT INTO payroll_runs (month, year, status, notes)
        VALUES (p_month, p_year, 'draft', p_notes)
        RETURNING * INTO v_run;
    END IF;

    -- Loop over all active profiles with salary structure
    FOR v_emp IN
        SELECT p.id as user_id, p.full_name
        FROM profiles p
        WHERE p.is_active = TRUE
    LOOP
        SELECT * INTO v_structure FROM salary_structures WHERE user_id = v_emp.user_id;
        IF FOUND THEN
            v_daily_rate := round(v_structure.base_salary / 30.0, 2);
            v_hourly_rate := round(v_structure.base_salary / 208.0, 2);

            -- Count unpaid leaves approved in that month
            SELECT COALESCE(SUM(lr.total_days), 0) INTO v_unpaid_days
            FROM leave_requests lr
            JOIN leave_types lt ON lt.id = lr.leave_type_id
            WHERE lr.user_id = v_emp.user_id
              AND lt.is_paid = FALSE
              AND lr.status = 'approved'
              AND EXTRACT(MONTH FROM lr.start_date) = p_month
              AND EXTRACT(YEAR FROM lr.start_date) = p_year;

            v_unpaid_deduction := round(v_unpaid_days * v_daily_rate, 2);

            -- Count late days (every 3 late days = 1 day base salary deduction)
            SELECT COUNT(*) INTO v_late_count
            FROM attendance
            WHERE user_id = v_emp.user_id
              AND status = 'late'
              AND EXTRACT(MONTH FROM date) = p_month
              AND EXTRACT(YEAR FROM date) = p_year;

            v_late_deduction := round((v_late_count / 3) * v_daily_rate, 2);

            -- Total OT minutes in that month
            SELECT COALESCE(SUM(overtime_minutes), 0) INTO v_ot_minutes
            FROM attendance
            WHERE user_id = v_emp.user_id
              AND EXTRACT(MONTH FROM date) = p_month
              AND EXTRACT(YEAR FROM date) = p_year;

            v_ot_pay := round((v_ot_minutes / 60.0) * (v_hourly_rate * 1.5), 2);

            v_net_pay := v_structure.gross_salary + v_ot_pay - v_structure.tax_deduction - v_structure.other_deductions - v_unpaid_deduction - v_late_deduction;

            INSERT INTO payslips (
                payroll_run_id,
                user_id,
                base_salary,
                allowances,
                overtime_pay,
                unpaid_leave_deductions,
                late_deductions,
                tax_deductions,
                other_deductions,
                net_pay,
                payment_status
            ) VALUES (
                v_run.id,
                v_emp.user_id,
                v_structure.base_salary,
                (v_structure.gross_salary - v_structure.base_salary),
                v_ot_pay,
                v_unpaid_deduction,
                v_late_deduction,
                v_structure.tax_deduction,
                v_structure.other_deductions,
                v_net_pay,
                'unpaid'
            );

            v_total_gross := v_total_gross + v_structure.gross_salary + v_ot_pay;
            v_total_deductions := v_total_deductions + v_structure.tax_deduction + v_structure.other_deductions + v_unpaid_deduction + v_late_deduction;
            v_total_net := v_total_net + v_net_pay;
        END IF;
    END LOOP;

    UPDATE payroll_runs SET
        total_gross = v_total_gross,
        total_deductions = v_total_deductions,
        total_net = v_total_net,
        updated_at = NOW()
    WHERE id = v_run.id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'run_id', v_run.id,
        'total_gross', v_total_gross,
        'total_net', v_total_net,
        'message', 'Draft payroll run calculated successfully.'
    );
END;
$$;

-- 7. APPROVE & LOCK PAYROLL RUN RPC (Director Only)
CREATE OR REPLACE FUNCTION public.approve_payroll_run(p_run_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_actor_id UUID := auth.uid();
    v_run payroll_runs%ROWTYPE;
BEGIN
    IF public.current_role() != 'director' THEN
        RAISE EXCEPTION 'Unauthorized: Only Director can approve and lock payroll runs.';
    END IF;

    SELECT * INTO v_run FROM payroll_runs WHERE id = p_run_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Payroll run not found.';
    END IF;

    IF v_run.status = 'locked' THEN
        RAISE EXCEPTION 'Payroll run is already locked.';
    END IF;

    UPDATE payroll_runs SET
        status = 'locked',
        approved_by = v_actor_id,
        approved_at = NOW(),
        updated_at = NOW()
    WHERE id = p_run_id;

    INSERT INTO audit_logs (
        actor_id,
        action,
        table_name,
        record_id,
        new_data,
        platform
    ) VALUES (
        v_actor_id,
        'APPROVE_PAYROLL_RUN',
        'payroll_runs',
        p_run_id::TEXT,
        jsonb_build_object('status', 'locked', 'approved_by', v_actor_id),
        'web'
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'run_id', p_run_id,
        'status', 'locked',
        'message', 'Payroll run approved and permanently locked.'
    );
END;
$$;
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
