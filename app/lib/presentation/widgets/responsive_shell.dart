import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/profile_model.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_locale_provider.dart';
import 'brand_logo.dart';
import 'user_form_dialog.dart';

class ResponsiveShell extends ConsumerStatefulWidget {
  final Widget child;
  final String currentRoute;

  const ResponsiveShell({
    super.key,
    required this.child,
    required this.currentRoute,
  });

  @override
  ConsumerState<ResponsiveShell> createState() => _ResponsiveShellState();
}

class _ResponsiveShellState extends ConsumerState<ResponsiveShell> {
  bool _sidebarExpanded = true;
  String _selectedBranch = 'Dhaka HQ (Banani)';

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final authState = ref.watch(authProvider);
    final user = authState.profile;
    final role = authState.role;

    if (isDesktop) {
      // WEB DESKTOP LAYOUT (White sidebar with logo, topbar with search/branch/add user/notif/profile)
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            // Left White Sidebar
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _sidebarExpanded ? 240 : 72,
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: const Border(right: BorderSide(color: AppColors.border)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Sidebar Logo Header
                  Container(
                    height: 70,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_sidebarExpanded)
                          const Expanded(child: BrandLogo(height: 36))
                        else
                          const BrandLogo(height: 32, iconOnly: true),
                        IconButton(
                          icon: Icon(
                            _sidebarExpanded ? Icons.chevron_left : Icons.chevron_right,
                            color: AppColors.muted,
                          ),
                          onPressed: () {
                            setState(() => _sidebarExpanded = !_sidebarExpanded);
                          },
                        ),
                      ],
                    ),
                  ),

                  // Navigation Links
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                      children: [
                        _buildNavItem(
                          icon: Icons.dashboard_outlined,
                          activeIcon: Icons.dashboard,
                          label: 'Dashboard',
                          route: '/dashboard',
                        ),
                        _buildNavItem(
                          icon: Icons.access_time_outlined,
                          activeIcon: Icons.access_time_filled,
                          label: 'Attendance',
                          route: '/attendance',
                        ),
                        _buildNavItem(
                          icon: Icons.event_note_outlined,
                          activeIcon: Icons.event_note,
                          label: 'Leave Management',
                          route: '/leave',
                        ),
                        _buildNavItem(
                          icon: Icons.people_outline,
                          activeIcon: Icons.people,
                          label: 'Employees',
                          route: '/users',
                        ),
                        _buildNavItem(
                          icon: Icons.task_alt_outlined,
                          activeIcon: Icons.task_alt,
                          label: 'Tasks & Notices',
                          route: '/tasks',
                        ),
                        if (role == UserRole.director || role == UserRole.admin || role == UserRole.hr)
                          _buildNavItem(
                            icon: Icons.account_balance_wallet_outlined,
                            activeIcon: Icons.account_balance_wallet,
                            label: 'Payroll',
                            route: '/payroll',
                          ),
                        _buildNavItem(
                          icon: Icons.bar_chart_outlined,
                          activeIcon: Icons.bar_chart,
                          label: 'Reports',
                          route: '/reports',
                        ),
                        if (role == UserRole.director || role == UserRole.admin)
                          _buildNavItem(
                            icon: Icons.settings_outlined,
                            activeIcon: Icons.settings,
                            label: 'Settings',
                            route: '/settings',
                          ),
                      ],
                    ),
                  ),

                  // Sidebar Bottom User Profile Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.primaryTeal,
                          child: Text(
                            user?.fullName.isNotEmpty == true ? user!.fullName[0].toUpperCase() : 'U',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (_sidebarExpanded) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.fullName ?? 'User',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.ink),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  role.displayName,
                                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.logout, size: 18, color: AppColors.muted),
                            tooltip: 'Sign Out',
                            onPressed: () => ref.read(authProvider.notifier).signOut(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Main Web Body & Topbar
            Expanded(
              child: Column(
                children: [
                  // Web Topbar
                  Container(
                    height: 70,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border(bottom: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(
                      children: [
                        // Search bar
                        SizedBox(
                          width: 280,
                          height: 40,
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Search employees, tasks, departments...',
                              prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.muted),
                              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Branch filter dropdown
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedBranch,
                              icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.primaryTeal),
                              items: const [
                                DropdownMenuItem(value: 'Dhaka HQ (Banani)', child: Text('Dhaka HQ (Banani)', style: TextStyle(fontSize: 13))),
                                DropdownMenuItem(value: 'Chattogram Branch', child: Text('Chattogram Branch', style: TextStyle(fontSize: 13))),
                                DropdownMenuItem(value: 'All Branches', child: Text('All Branches (National)', style: TextStyle(fontSize: 13))),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedBranch = val);
                              },
                            ),
                          ),
                        ),

                        const Spacer(),

                        // Language Switcher (EN / বাংলা)
                        TextButton.icon(
                          onPressed: () {
                            ref.read(localeProvider.notifier).toggleLanguage();
                          },
                          icon: const Icon(Icons.translate, size: 18, color: AppColors.primaryTeal),
                          label: Text(
                            ref.watch(localeProvider).isBengali ? 'বাংলা' : 'English',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryTeal),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Quick "Add user" button (Dashboard, Users page, Dept pages)
                        if (role != UserRole.employee)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryTeal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                            onPressed: () => UserFormDialog.show(context),
                            icon: const Icon(Icons.person_add, size: 18),
                            label: const Text('Add User'),
                          ),
                        const SizedBox(width: 16),

                        // Notifications bell
                        Stack(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.notifications_outlined, color: AppColors.ink),
                              onPressed: () {},
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.accentOrange,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Content Body
                  Expanded(
                    child: widget.child,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      // ANDROID / MOBILE LAYOUT
      // Teal app bar with clock-K icon, bottom navigation bar, orange check-in button
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.primaryTeal,
          title: const Row(
            children: [
              BrandLogo(height: 28, iconOnly: true),
              SizedBox(width: 10),
              Text('KORMO', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.translate),
              tooltip: 'Switch Language',
              onPressed: () => ref.read(localeProvider.notifier).toggleLanguage(),
            ),
            IconButton(
              icon: const Icon(Icons.notifications_none),
              onPressed: () {},
            ),
          ],
        ),
        body: widget.child,
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.accentOrange,
          foregroundColor: Colors.white,
          onPressed: () {
            context.go('/attendance');
          },
          icon: const Icon(Icons.fingerprint),
          label: const Text('Check In', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _getMobileNavIndex(widget.currentRoute),
          selectedItemColor: AppColors.primaryTeal,
          unselectedItemColor: AppColors.muted,
          type: BottomNavigationBarType.fixed,
          onTap: (index) {
            switch (index) {
              case 0:
                context.go('/dashboard');
                break;
              case 1:
                context.go('/attendance');
                break;
              case 2:
                context.go('/leave');
                break;
              case 3:
                context.go('/tasks');
                break;
              case 4:
                context.go('/users');
                break;
            }
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.access_time_outlined), activeIcon: Icon(Icons.access_time_filled), label: 'Attend'),
            BottomNavigationBarItem(icon: Icon(Icons.event_note_outlined), activeIcon: Icon(Icons.event_note), label: 'Leaves'),
            BottomNavigationBarItem(icon: Icon(Icons.task_alt_outlined), activeIcon: Icon(Icons.task_alt), label: 'Tasks'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Staff'),
          ],
        ),
      );
    }
  }

  int _getMobileNavIndex(String route) {
    if (route.startsWith('/attendance')) return 1;
    if (route.startsWith('/leave')) return 2;
    if (route.startsWith('/tasks')) return 3;
    if (route.startsWith('/users')) return 4;
    return 0;
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required String route,
  }) {
    final isActive = widget.currentRoute == route;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        dense: true,
        selected: isActive,
        selectedTileColor: AppColors.primaryTeal.withOpacity(0.08),
        leading: Icon(
          isActive ? activeIcon : icon,
          color: isActive ? AppColors.primaryTeal : AppColors.muted,
          size: 20,
        ),
        title: _sidebarExpanded
            ? Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  color: isActive ? AppColors.primaryTeal : AppColors.ink,
                ),
              )
            : null,
        onTap: () => context.go(route),
      ),
    );
  }
}
