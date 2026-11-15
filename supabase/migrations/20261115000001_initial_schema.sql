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
