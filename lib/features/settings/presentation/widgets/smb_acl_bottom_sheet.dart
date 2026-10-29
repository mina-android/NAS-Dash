import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../system/providers/system_provider.dart';

class SmbAclBottomSheet extends StatefulWidget {
  final String shareName;
  final String sharePath;
  final SystemNotifier systemNotifier;
  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> groups;

  const SmbAclBottomSheet({
    super.key,
    required this.shareName,
    required this.sharePath,
    required this.systemNotifier,
    this.users = const [],
    this.groups = const [],
  });

  @override
  State<SmbAclBottomSheet> createState() => _SmbAclBottomSheetState();
}

class _SmbAclBottomSheetState extends State<SmbAclBottomSheet> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _aclData;

  @override
  void initState() {
    super.initState();
    _loadAcl();
  }

  Future<void> _loadAcl() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final data = await widget.systemNotifier.getFilesystemAcl(widget.sharePath);
    if (!mounted) return;

    if (data == null) {
      setState(() {
        _loading = false;
        _error = 'Unable to fetch ACL for this share path. TrueNAS filesystem permissions may be POSIX or restricted.';
      });
    } else {
      setState(() {
        _loading = false;
        _aclData = data;
      });
    }
  }

  String _resolveUserName(dynamic rawId, Map<String, String> uidMap) {
    if (rawId == null) return 'N/A';
    final key = rawId.toString();
    final name = uidMap[key];
    if (name != null && name.isNotEmpty) {
      return '$name ($key)';
    }
    if (key == '0') return 'root (0)';
    return key;
  }

  String _resolveGroupName(dynamic rawId, Map<String, String> gidMap) {
    if (rawId == null) return 'N/A';
    final key = rawId.toString();
    final name = gidMap[key];
    if (name != null && name.isNotEmpty) {
      return '$name ($key)';
    }
    if (key == '0') return 'root / wheel (0)';
    if (key == '544') return 'builtin_administrators (544)';
    if (key == '545') return 'builtin_users (545)';
    return key;
  }

  String _formatAclIdentity({
    required String tag,
    required String? who,
    required String id,
    required String ownerUser,
    required String ownerGroup,
    required Map<String, String> uidMap,
    required Map<String, String> gidMap,
  }) {
    final cleanWho = (who != null && who.trim().isNotEmpty && who != 'null') ? who.trim() : null;
    final cleanId = (id.isNotEmpty && id != 'null' && id != '-1') ? id : '';
    final upperTag = tag.toUpperCase();

    if (cleanWho != null) {
      if (cleanId.isNotEmpty && !cleanWho.contains(cleanId)) {
        return '$tag: $cleanWho ($cleanId)';
      }
      return '$tag: $cleanWho';
    }

    if (tag == 'owner@' || upperTag == 'USER_OBJ') {
      return 'Owner ($ownerUser)';
    }
    if (tag == 'group@' || upperTag == 'GROUP_OBJ') {
      return 'Owner Group ($ownerGroup)';
    }
    if (tag == 'everyone@' || upperTag == 'OTHER') {
      return 'Everyone (everyone@)';
    }

    if (upperTag.contains('USER') && cleanId.isNotEmpty) {
      final resolved = uidMap[cleanId] ?? (cleanId == '0' ? 'root' : null);
      if (resolved != null) {
        return '$tag: $resolved ($cleanId)';
      }
      return '$tag ($cleanId)';
    }

    if (upperTag.contains('GROUP') && cleanId.isNotEmpty) {
      final resolved = gidMap[cleanId] ??
          (cleanId == '0'
              ? 'wheel'
              : cleanId == '544'
                  ? 'builtin_administrators'
                  : cleanId == '545'
                      ? 'builtin_users'
                      : null);
      if (resolved != null) {
        return '$tag: $resolved ($cleanId)';
      }
      return '$tag ($cleanId)';
    }

    return cleanId.isNotEmpty ? '$tag ($cleanId)' : tag;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
        mainAxisSize: MainAxisSize.min,
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
                  Icon(Icons.security_outlined, color: colorScheme.onSurfaceVariant, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'SMB Share ACL: ${widget.shareName}',
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
          Text(
            widget.sharePath,
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: AppColors.critical, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : _buildAclContent(colorScheme),
          ),
        ],
      ),
    );
  }

  Widget _buildAclContent(ColorScheme colorScheme) {
    final acl = _aclData?['acl'] as List? ?? [];
    final aclType = _aclData?['acltype'] as String? ?? 'NFSv4 / POSIX';

    final uidMap = <String, String>{};
    for (final u in widget.users) {
      final uid = u['uid']?.toString();
      final username = u['username'] as String?;
      if (uid != null && username != null && username.isNotEmpty) {
        uidMap[uid] = username;
      }
    }

    final gidMap = <String, String>{};
    for (final g in widget.groups) {
      final gid = g['gid']?.toString();
      final groupName = (g['group'] as String?) ?? (g['name'] as String?);
      if (gid != null && groupName != null && groupName.isNotEmpty) {
        gidMap[gid] = groupName;
      }
    }

    final ownerUser = _resolveUserName(_aclData?['uid'], uidMap);
    final ownerGroup = _resolveGroupName(_aclData?['gid'], gidMap);

    return ListView(
      children: [
        GlassCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text('ACL Type', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text(
                      aclType,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text('Owner User', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text(
                      ownerUser,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text('Owner Group', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text(
                      ownerGroup,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'ACCESS CONTROL ENTRIES (${acl.length})',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.6,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 6),
        if (acl.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                'No explicit ACL entries found.',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ),
          )
        else
          ...acl.map((entry) {
            final tag = entry['tag'] as String? ?? 'USER';
            final who = entry['who']?.toString();
            final id = entry['id']?.toString() ?? '';
            final type = entry['type'] as String? ?? 'ALLOW';
            final isAllow = type.toUpperCase() == 'ALLOW';
            final perms = entry['perms'] as Map<String, dynamic>?;

            final identityLabel = _formatAclIdentity(
              tag: tag,
              who: who,
              id: id,
              ownerUser: ownerUser,
              ownerGroup: ownerGroup,
              uidMap: uidMap,
              gidMap: gidMap,
            );

            final activePerms = perms?.entries
                    .where((e) => e.value == true)
                    .map((e) => e.key.toUpperCase())
                    .toList() ??
                [];

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isAllow
                      ? AppColors.healthy.withValues(alpha: 0.25)
                      : AppColors.critical.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              tag.toUpperCase().contains('GROUP')
                                  ? Icons.group_outlined
                                  : Icons.person_outline,
                              size: 16,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                identityLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isAllow
                              ? AppColors.healthy.withValues(alpha: 0.15)
                              : AppColors.critical.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          type,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isAllow ? AppColors.healthy : AppColors.critical,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (activePerms.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: activePerms.map((p) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(p, style: TextStyle(fontSize: 9, color: colorScheme.onSurfaceVariant)),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }
}
