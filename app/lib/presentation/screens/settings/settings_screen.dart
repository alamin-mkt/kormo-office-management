import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../providers/admin_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _allowExecutiveAddUser = false;
  bool _requireSelfie = false;
  bool _requireWifi = false;

  @override
  Widget build(BuildContext context) {
    final adminState = ref.watch(adminProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Organization & System Settings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.ink)),
                SizedBox(height: 4),
                Text('Manage branches, geofence radius, shift schedules, and global policy toggles', style: TextStyle(color: AppColors.muted, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 24),

            // Feature Toggles Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('System Feature Controls & Delegations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink)),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Allow Executives to Add Employees (Own Dept Only)'),
                    subtitle: const Text('Default OFF. When enabled, allows executive role to add employee-level staff within their own department.'),
                    activeColor: AppColors.primaryTeal,
                    value: _allowExecutiveAddUser,
                    onChanged: (val) {
                      setState(() => _allowExecutiveAddUser = val);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Setting allow_executive_add_user updated to $val')),
                      );
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Mandatory Check-In Camera Snapshot (Selfie)'),
                    subtitle: const Text('Requires mobile staff to capture a camera selfie before punch confirmation to prevent buddy punching.'),
                    activeColor: AppColors.primaryTeal,
                    value: _requireSelfie,
                    onChanged: (val) {
                      setState(() => _requireSelfie = val);
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Enforce Branch Wi-Fi BSSID / IP Matching'),
                    subtitle: const Text('Validates connected office network or public gateway IP against branch whitelist.'),
                    activeColor: AppColors.primaryTeal,
                    value: _requireWifi,
                    onChanged: (val) {
                      setState(() => _requireWifi = val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Branch Geofences Table
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Configured Branches & Geofences', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink)),
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.add_location_alt, size: 16),
                        label: const Text('Add Branch'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...adminState.branches.map((b) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_city, color: AppColors.primaryTeal),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${b["name"]} (${b["code"]})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text('Address: ${b["address"]}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                                const SizedBox(height: 2),
                                Text(
                                  'GPS: ${b["latitude"]}, ${b["longitude"]} • Radius: ${b["radius_meters"]} meters',
                                  style: const TextStyle(fontSize: 11, color: AppColors.primaryTeal, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: AppColors.successBg, borderRadius: BorderRadius.circular(6)),
                            child: const Text('Active', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
