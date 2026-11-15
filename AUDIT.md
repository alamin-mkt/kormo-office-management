# KORMO - Quality, Security & Audit Log (AUDIT.md)

This document tracks all audit loops, security reviews, parity checks, and defect resolutions throughout the engineering lifecycle of KORMO.

## Audit Categories
1. **Security & Access Control**: RLS policies on 100% of tables, forbidden actions, prevention of self-promotion, secret isolation (service_role never in client).
2. **Web & Android Parity**: Identical business rules, realtime synchronization, responsive experience.
3. **Attendance & Time Integrity**: Server-time enforcement, Haversine GPS geofence, midnight shifts, overtime, double-punch prevention, offline queue.
4. **Data Integrity & Constraints**: Balance never negative, payroll lock immutable, audit logs immutable (INSERT only).
5. **Edge Cases**: Disabled accounts, expired JWT tokens, duplicate records, empty states, pagination, offline recovery.
6. **UX & Brand Compliance**: Brand tokens (Teal `#1A7E96`, Orange `#F3760C`, Ink `#0F172A`), logo usage, WCAG AA contrast, 44px min touch targets.
7. **Code Quality**: Zero dead code, zero unhandled errors, clean lint, shared single codebase.

---

## Audit Defect Tracking Log

| Defect ID | Category | Severity | Description | Phase Found | Remediation / Fix | Verification | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **AUD-001** | Security / Secret | HIGH | Service role key isolation check | Phase 1 | Service role key is only used in Supabase Edge Functions (`create-user`, `send-fcm-notification`). Flutter client only references public URL and anon key. | Verified in `app/.env.example` and `app/lib/data/` | **Closed** |
| **AUD-002** | Security / RLS | HIGH | Direct profile insertion / promotion block | Phase 1 | `can_create()` RPC verifies authority hierarchy. Direct INSERT on `profiles` is restricted to service_role. | Verified via `20261115000002_rls_policies.sql` & SQL test suite | **Closed** |
| **AUD-003** | Data Integrity | CRITICAL | Immutable Audit Logs enforcement | Phase 1 | Trigger `trg_immutable_audit_logs` prevents any UPDATE or DELETE operations on `audit_logs`. | Verified in `rls_permission_tests.sql` | **Closed** |
| **AUD-004** | Data Integrity | HIGH | Leave balance negative protection | Phase 1 & 4 | Added `chk_balance_non_negative` check constraint and pre-validation in `apply_leave()` and `decide_leave()`. | Verified in `leave_balance_test.dart` & SQL tests | **Closed** |
| **AUD-005** | Time Integrity | CRITICAL | Client clock tampering prevention | Phase 3 | Attendance timestamps generated using database `NOW() AT TIME ZONE 'Asia/Dhaka'`, never client device clock. | Verified in `check_in()` & `check_out()` RPCs | **Closed** |
| **AUD-006** | UI / Responsive | MEDIUM | Small viewport overflow in Dashboard notices widget | Phase 5 | Replaced static horizontal row in notices card with flexible responsive wrap and LayoutBuilder. | Verified via Flutter widget test suite | **Closed** |
| **AUD-007** | Client Architecture | LOW | Realtime websocket reconnect timer in widget tests | Phase 1 | Guarded realtime subscriptions with `SupabaseConfig.isInitialized` check so headless unit tests don't leak timers. | Verified: 13/13 tests green | **Closed** |
| **AUD-008** | Brand Compliance | MEDIUM | WCAG AA contrast for orange text | Brand | Defined separate token `AppColors.orangeText` (`#B45309`) for orange-colored text as per specification. | Verified in `app_colors.dart` & theme tokens | **Closed** |

---

## Audit Verification Sign-Off Checklist
- [x] **Security Review**: All 23 tables have RLS enabled. Service role key never in Flutter client. No self-promotion allowed.
- [x] **Realtime Parity**: Shared data models and repositories (`/lib/data`), realtime channel subscription hooks in place.
- [x] **Attendance Engine**: Geofence, server-time timestamping, overtime, and midnight shifts mathematically verified in SQL & Dart.
- [x] **Financial & Leave Integrity**: Leave balances cannot become negative. Approved payroll runs permanently locked.
- [x] **Brand Consistency**: Theme tokens strictly applied. Full logo and clock-K icon match specification.
- [x] **Automated Tests**: SQL/RLS integrity suite written, Flutter unit/widget tests passing (13/13 tests green), Web production bundle built cleanly.
