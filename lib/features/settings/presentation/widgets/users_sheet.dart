import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';

class UsersSheet extends StatefulWidget {
  final List<Map<String, dynamic>> users;

  const UsersSheet({super.key, required this.users});

  @override
  State<UsersSheet> createState() => _UsersSheetState();
}

class _UsersSheetState extends State<UsersSheet> {
  bool _showSystemUsers = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final displayedUsers = widget.users.where((u) {
      if (_showSystemUsers) return true;
      final builtin = u['builtin'] as bool? ?? false;
      final uid = (u['uid'] as num?)?.toInt() ?? 0;
      return !builtin && uid >= 1000;
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.manage_accounts_rounded, color: colorScheme.primary, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Created User Accounts',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing ${displayedUsers.length} user account(s)',
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
              Row(
                children: [
                  Text('System accounts', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                  const SizedBox(width: 4),
                  Switch(
                    value: _showSystemUsers,
                    onChanged: (val) => setState(() => _showSystemUsers = val),
                  ),
                ],
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 6),
          Expanded(
            child: displayedUsers.isEmpty
                ? Center(
                    child: Text(
                      'No non-system created users found.',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  )
                : ListView.separated(
                    itemCount: displayedUsers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final u = displayedUsers[index];
                      final username = u['username'] as String? ?? 'user';
                      final fullName = u['full_name'] as String? ?? '';
                      final uid = u['uid']?.toString() ?? '1000';
                      final sudo = u['sudo'] as bool? ?? false;
                      final locked = u['locked'] as bool? ?? false;
                      final shell = u['shell'] as String? ?? '/bin/sh';
                      final builtin = u['builtin'] as bool? ?? false;

                      return GlassCard(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (locked
                                        ? AppColors.critical
                                        : (sudo ? AppColors.warning : colorScheme.primary))
                                    .withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                locked
                                    ? Icons.lock_person_outlined
                                    : (sudo ? Icons.admin_panel_settings_outlined : Icons.person_outline),
                                size: 20,
                                color: locked
                                    ? AppColors.critical
                                    : (sudo ? AppColors.warning : colorScheme.primary),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        username,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      if (sudo)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: AppColors.warning.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'SUDO',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.warning,
                                            ),
                                          ),
                                        ),
                                      if (builtin) ...[
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: colorScheme.surfaceContainerHighest,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'BUILTIN',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (locked) ...[
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: AppColors.critical.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'LOCKED',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.critical,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${fullName.isNotEmpty ? "$fullName • " : ""}UID: $uid • Shell: $shell',
                                    style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
