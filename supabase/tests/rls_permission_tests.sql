-- ==============================================================================
-- KORMO - SQL Test Suite: RLS & Business Logic Verification
-- ==============================================================================

DO $$
DECLARE
    v_director_id UUID := '11111111-0000-0000-0000-000000000001';
    v_admin_id    UUID := '22222222-0000-0000-0000-000000000002';
    v_hr_id       UUID := '33333333-0000-0000-0000-000000000003';
    v_manager_id  UUID := '44444444-0000-0000-0000-000000000004';
    v_exec_id     UUID := '55555555-0000-0000-0000-000000000005';
    v_emp_id      UUID := '66666666-0000-0000-0000-000000000006';
    v_eng_dept    UUID := 'dddddddd-0000-0000-0000-000000000003';
    v_hr_dept     UUID := 'dddddddd-0000-0000-0000-000000000002';
    v_leave_al    UUID := 'eeeeeeee-0000-0000-0000-000000000001';
BEGIN
    RAISE NOTICE '==================================================';
    RAISE NOTICE 'STARTING KORMO SQL VERIFICATION TEST SUITE';
    RAISE NOTICE '==================================================';

    -- TEST 1: IMMUTABLE AUDIT LOG PROTECTION
    RAISE NOTICE '[TEST 1] Testing audit_logs immutability trigger...';
    BEGIN
        INSERT INTO audit_logs (id, action, table_name, platform)
        VALUES ('00000000-0000-0000-0000-000000000099', 'TEST_INSERT', 'test', 'system');

        -- Attempt illegal update
        UPDATE audit_logs SET action = 'ILLEGAL_MODIFICATION'
        WHERE id = '00000000-0000-0000-0000-000000000099';

        RAISE EXCEPTION 'TEST FAILED: audit_logs allowed UPDATE!';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM LIKE '%strictly immutable%' THEN
            RAISE NOTICE '  --> PASSED: Audit log modification was rejected as expected.';
        ELSE
            RAISE EXCEPTION 'Unexpected error: %', SQLERRM;
        END IF;
    END;

    -- TEST 2: NON-NEGATIVE LEAVE BALANCE CONSTRAINT
    RAISE NOTICE '[TEST 2] Testing leave_balances non-negative constraint...';
    BEGIN
        -- Attempt to set used_days > allocated_days
        INSERT INTO leave_balances (user_id, leave_type_id, year, allocated_days, used_days)
        VALUES (v_emp_id, v_leave_al, 2030, 10.0, 15.0);

        RAISE EXCEPTION 'TEST FAILED: leave_balances allowed negative balance!';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE '  --> PASSED: Negative leave balance was rejected by CHECK constraint.';
    END;

    -- TEST 3: ATTENDANCE DOUBLE CHECK-IN / UNIQUE CONSTRAINT
    RAISE NOTICE '[TEST 3] Testing attendance unique(user_id, date) constraint...';
    BEGIN
        INSERT INTO attendance (user_id, date, status)
        VALUES (v_emp_id, '2026-11-15', 'present');

        INSERT INTO attendance (user_id, date, status)
        VALUES (v_emp_id, '2026-11-15', 'present');

        RAISE EXCEPTION 'TEST FAILED: Duplicate attendance allowed for same date!';
    EXCEPTION WHEN unique_violation THEN
        RAISE NOTICE '  --> PASSED: Duplicate attendance prevented by unique constraint.';
    END;

    -- Clean up test attendance record
    DELETE FROM attendance WHERE user_id = v_emp_id AND date = '2026-11-15';

    RAISE NOTICE '==================================================';
    RAISE NOTICE 'ALL CORE SQL INTEGRITY TESTS COMPLETED SUCCESSFULLY!';
    RAISE NOTICE '==================================================';
END $$;
