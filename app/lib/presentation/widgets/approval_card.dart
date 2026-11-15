import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class ApprovalCard extends StatelessWidget {
  final String title;
  final String requesterName;
  final String? requesterRole;
  final String? requesterDepartment;
  final String subtitle;
  final String reason;
  final String status;
  final String? attachmentUrl;
  final VoidCallback? onApprove;
  final ValueChanged<String?>? onReject;

  const ApprovalCard({
    super.key,
    required this.title,
    required this.requesterName,
    this.requesterRole,
    this.requesterDepartment,
    required this.subtitle,
    required this.reason,
    required this.status,
    this.attachmentUrl,
    this.onApprove,
    this.onReject,
  });

  void _showRejectDialog(BuildContext context) {
    final commentController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Request'),
        content: TextField(
          controller: commentController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Enter reason for rejection (mandatory)...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(ctx);
              onReject?.call(commentController.text.trim());
            },
            child: const Text('Confirm Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPending = status.toLowerCase() == 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.tealBg,
                    child: Text(
                      requesterName.isNotEmpty ? requesterName[0].toUpperCase() : 'U',
                      style: const TextStyle(color: AppColors.primaryTeal, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        requesterName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.ink),
                      ),
                      Text(
                        '${requesterRole ?? "Employee"} • ${requesterDepartment ?? "Staff"}',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isPending ? AppColors.warningBg : AppColors.successBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isPending ? AppColors.orangeText : AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.primaryTeal),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.ink),
          ),
          const SizedBox(height: 6),
          Text(
            'Reason: $reason',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          if (isPending && (onApprove != null || onReject != null)) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onReject != null)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                      minimumSize: const Size(90, 38),
                    ),
                    onPressed: () => _showRejectDialog(context),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Reject'),
                  ),
                const SizedBox(width: 10),
                if (onApprove != null)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryTeal,
                      minimumSize: const Size(100, 38),
                    ),
                    onPressed: onApprove,
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Approve'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
