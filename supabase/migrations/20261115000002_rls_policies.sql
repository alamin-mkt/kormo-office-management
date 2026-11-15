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
