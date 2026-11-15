import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, dynamic>> _sampleTasks = [
    {
      'id': 't1',
      'title': 'Prepare Q4 Infrastructure Audit Report',
      'status': 'In Progress',
      'priority': 'High',
      'due': '22 Nov 2026',
      'assignee': 'Fatima Zohra',
    },
    {
      'id': 't2',
      'title': 'Deploy Supabase Database Security Policies',
      'status': 'Completed',
      'priority': 'Urgent',
      'due': '18 Nov 2026',
      'assignee': 'Tanvir Ahmed',
    },
    {
      'id': 't3',
      'title': 'Employee Onboarding Checklist Review',
      'status': 'To-Do',
      'priority': 'Medium',
      'due': '25 Nov 2026',
      'assignee': 'Nasreen Akter',
    },
  ];

  final List<Map<String, dynamic>> _sampleNotices = [
    {
      'title': 'Official Holiday Notice: Victory Day 2026',
      'content': 'Office will remain closed on 16 December 2026 in observance of National Victory Day.',
      'date': '15 Nov 2026',
      'pinned': true,
      'scope': 'All Branches',
    },
    {
      'title': 'Office Biometric & Geofencing System Launched',
      'content': 'All team members are requested to punch attendance using Kormo mobile or web client within branch radius.',
      'date': '12 Nov 2026',
      'pinned': true,
      'scope': 'All Branches',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showCreateTaskDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String priority = 'Medium';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create New Task'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Task Title *', hintText: 'e.g. Audit security logs'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description', hintText: 'Task requirements and instructions...'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: priority,
                decoration: const InputDecoration(labelText: 'Priority Level'),
                items: const [
                  DropdownMenuItem(value: 'Low', child: Text('Low')),
                  DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'High', child: Text('High')),
                  DropdownMenuItem(value: 'Urgent', child: Text('Urgent')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => priority = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty) return;
                setState(() {
                  _sampleTasks.insert(0, {
                    'id': 't_${DateTime.now().millisecondsSinceEpoch}',
                    'title': titleController.text.trim(),
                    'status': 'To-Do',
                    'priority': priority,
                    'due': 'Tomorrow',
                    'assignee': 'Assigned Member',
                  });
                });
                Navigator.pop(ctx);
              },
              child: const Text('Create Task'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tasks & Bulletin Board', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.ink)),
                    SizedBox(height: 4),
                    Text('Department assignments, project tracking, and corporate notices', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryTeal),
                  onPressed: _showCreateTaskDialog,
                  icon: const Icon(Icons.add_task, size: 18),
                  label: const Text('New Task'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            TabBar(
              controller: _tabController,
              labelColor: AppColors.primaryTeal,
              indicatorColor: AppColors.primaryTeal,
              tabs: const [
                Tab(icon: Icon(Icons.task_alt), text: 'Tasks & Workflow'),
                Tab(icon: Icon(Icons.campaign), text: 'Company Notices'),
              ],
            ),
            const SizedBox(height: 20),

            SizedBox(
              height: 540,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tasks List Tab
                  ListView.separated(
                    itemCount: _sampleTasks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, index) {
                      final task = _sampleTasks[index];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: task['status'] == 'Completed',
                              onChanged: (val) {
                                setState(() {
                                  task['status'] = val == true ? 'Completed' : 'To-Do';
                                });
                              },
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    task['title'],
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: task['status'] == 'Completed' ? AppColors.muted : AppColors.ink,
                                      decoration: task['status'] == 'Completed' ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Assignee: ${task['assignee']} • Due: ${task['due']}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                  ),
                                ],
                              ),
                            ),
                            _buildPriorityChip(task['priority']),
                          ],
                        ),
                      );
                    },
                  ),

                  // Company Notices Tab
                  ListView.separated(
                    itemCount: _sampleNotices.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, index) {
                      final notice = _sampleNotices[index];
                      return Container(
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
                                Row(
                                  children: [
                                    const Icon(Icons.push_pin, size: 16, color: AppColors.accentOrange),
                                    const SizedBox(width: 8),
                                    Text(
                                      notice['title'],
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.ink),
                                    ),
                                  ],
                                ),
                                Text(notice['date'], style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              notice['content'],
                              style: const TextStyle(fontSize: 13, color: AppColors.ink),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.tealBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                notice['scope'],
                                style: const TextStyle(color: AppColors.primaryTeal, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityChip(String priority) {
    Color bg = AppColors.tealBg;
    Color fg = AppColors.primaryTeal;

    if (priority == 'Urgent') {
      bg = AppColors.dangerBg;
      fg = AppColors.danger;
    } else if (priority == 'High') {
      bg = AppColors.warningBg;
      fg = AppColors.orangeText;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(priority, style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }
}
