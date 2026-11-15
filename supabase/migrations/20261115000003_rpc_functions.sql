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
