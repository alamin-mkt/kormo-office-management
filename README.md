# KORMO (কর্মে) - Enterprise Office Management System

Kormo is a production-grade, enterprise Office Management System designed and built for real companies with stringent security, compliance, and multi-branch operations.

---

## 1. Architectural Highlights

- **One Backend, Two Clients (Single Source of Truth)**:
  - Powered by a single **Supabase** backend (PostgreSQL database, Supabase Auth, Row Level Security, RPC functions, Realtime channels, Storage buckets, and Edge Functions).
  - Web Portal and Android App share the exact same database records, permissions, and business rules. Realtime channels ensure instantaneous synchronization across web and mobile.
- **Single Flutter Codebase**:
  - Located in `/app`. Built using `supabase_flutter`, `Riverpod`, and `go_router`.
  - Minimalistic shared architecture: one `UserForm`, one `DataTable`, one `ApprovalCard`, and one `StatCard`.
  - Responsive shell: Data tables and collapsible white sidebar on Web; cards, bottom nav, and floating action button on Android.
- **Security Lives in the Database**:
  - 100% of tables have Row Level Security (RLS) enabled.
  - Security Definer helper functions: `current_role()`, `current_dept()`, `is_active()` with search path isolation.
  - Delegated user creation authority engine (`can_create` RPC + `create-user` Edge Function).
  - Service role secret key exists exclusively as an Edge Function environment secret and is **never** committed or exposed to the client.
- **Localization & Timezone**:
  - Currency: Bangladeshi Taka (`BDT` / `৳`).
  - Timezone: `Asia/Dhaka` (all timestamps validated server-side, never trusting device clock).
  - Localization: English and Bangla (Noto Sans Bengali). Default weekend: Friday.
- **Brand Tokens**:
  - Primary Teal: `#1A7E96`
  - Accent Orange: `#F3760C` (Text accents use `#B45309` for WCAG AA compliance)
  - Ink: `#0F172A`, Background: `#F4F6F8`, Success: `#047857`, Danger: `#B91C1C`, Info: `#1D4ED8`
  - 44px minimum touch targets and WCAG AA contrast.

---

## 2. Directory Structure

```
├── /app/                               # Single Flutter Codebase (Android & Web)
│   ├── lib/
│   │   ├── core/
│   │   │   ├── constants/              # AppColors & Brand Design Tokens
│   │   │   ├── theme/                  # AppTheme & Typography
│   │   │   ├── localization/           # English & Bangla Localization
│   │   │   └── router/                 # GoRouter & Navigation Configuration
│   │   ├── data/
│   │   │   ├── models/                 # Shared Data Entities (Profile, Attendance, Leave, etc.)
│   │   │   ├── repositories/           # Single API Layer interacting with Supabase
│   │   │   └── supabase_client.dart    # Supabase Client Singleton
│   │   └── presentation/
│   │       ├── providers/              # Riverpod State Management
│   │       ├── widgets/                # Reusable Widgets (ResponsiveShell, DataTable, etc.)
│   │       └── screens/                # Role-aware Dashboards & Feature Screens
│   ├── web/                            # Web Entry & Favicon Assets
│   └── android/                        # Android Manifest & Native Configurations
├── /assets/brand/                      # Official Kormo Logo & Icons
├── /supabase/
│   ├── migrations/                     # Ordered PostgreSQL Schema & RLS Migrations
│   │   ├── 20261115000001_initial_schema.sql
│   │   ├── 20261115000002_rls_policies.sql
│   │   └── 20261115000003_rpc_functions.sql
│   ├── seed.sql                        # Master Configuration & Test Users (All 6 Roles)
│   ├── tests/                          # SQL Test Suite for RLS & Business Logic
│   └── functions/                      # Supabase Edge Functions (create-user, send-fcm)
├── FEATURES.md                         # Master 54-Feature Matrix
├── AUDIT.md                            # Quality, Security & Audit Log
└── README.md                           # System Documentation & Deployment Guide
```

---

## 3. Database Setup & Supabase Migrations

### Numbered Steps to Deploy Supabase:
1. **Create Supabase Project**:
   - Go to [supabase.com](https://supabase.com) and create a project in Region `Singapore (ap-southeast-1)`.
2. **Execute Ordered Migrations**:
   In the Supabase SQL Editor, execute the migration files in order:
   - Run `supabase/migrations/20261115000001_initial_schema.sql` (Creates all tables, enums, indexes, and immutable audit triggers).
   - Run `supabase/migrations/20261115000002_rls_policies.sql` (Enables RLS on 100% of tables and creates security definer policies).
   - Run `supabase/migrations/20261115000003_rpc_functions.sql` (Creates server-time `check_in`, `check_out`, `apply_leave`, `decide_leave`, `generate_payroll_run`, and `approve_payroll_run`).
3. **Seed Master Data**:
   - Run `supabase/seed.sql` to populate settings, branches, departments, shifts, leave types, official holidays, and 6 test users.
4. **Deploy Edge Functions**:
   Using the Supabase CLI:
   ```bash
   npx supabase functions deploy create-user --no-verify-jwt
   npx supabase functions deploy send-fcm-notification --no-verify-jwt
   ```
   Set the function secrets in your Supabase Dashboard:
   ```bash
   npx supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
   ```

---

## 4. Test Accounts & Role Verification Guide

All test accounts come pre-configured in `supabase/seed.sql` with default password: `Kormo@2026!`

| Role | Email | Permissions & Verification Checklist |
| :--- | :--- | :--- |
| **Director** | `director@kormo.com` | Full executive visibility across all branches; can create any subordinate role; signs off and permanently locks monthly payroll runs; views full immutable audit logs. |
| **Admin** | `admin@kormo.com` | Manages branches, shifts, departments, company settings, and system health; creates HR, Manager, Executive, Employee roles. |
| **HR Lead** | `hr@kormo.com` | Operates daily attendance, processes leave requests, drafts monthly payroll runs, manages employee contracts and onboarding. |
| **Manager** | `manager@kormo.com` | Department scope only; views own department team attendance; approves/rejects leaves and corrections for department staff; creates Executives/Employees in own department only. |
| **Executive** | `executive@kormo.com` | Personal portal for attendance, leaves, and tasks; can create employees in own department only if `allow_executive_add_user` is enabled in settings. |
| **Employee** | `employee@kormo.com` | Check-in/check-out within geofence; applies for leave; views own payslips and tasks; zero access to peer private salary or audit data. |

---

## 5. Running the Client Applications

### Web Portal:
1. Navigate to `/app`:
   ```bash
   cd app
   ```
2. Build the production web bundle:
   ```bash
   flutter build web --release
   ```
3. Run or serve locally:
   ```bash
   flutter run -d chrome
   ```
   Or serve the compiled bundle at `http://localhost:8080`.

### Android App:
1. Ensure Android SDK / Emulator is active.
2. Build debug or release APK:
   ```bash
   cd app
   flutter build apk --release
   ```
3. Run on connected Android device/emulator:
   ```bash
   flutter run -d android
   ```

---

## 6. Automated Verification Tests

To run the complete test suite:
```bash
cd app
flutter test
```
- Tests all role creation hierarchies and forbidden self-promotion rules.
- Tests attendance status calculations (Present, Late, Half-Day, Early-Leave, Overtime).
- Tests non-negative leave balances and status transitions.
- Tests widget rendering and responsive layout adaptation.
