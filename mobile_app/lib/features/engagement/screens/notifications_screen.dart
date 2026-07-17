import 'package:flutter/material.dart';

import '../services/engagement_service.dart';
import 'achievements_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final EngagementService _service = EngagementService();

  List<Map<String, dynamic>> _notifications = <Map<String, dynamic>>[];

  int _unreadCount = 0;

  bool _loading = true;
  bool _markingAll = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait<dynamic>([
        _service.listNotifications(),
        _service.getUnreadCount(),
      ]);

      final notificationResult = results[0] as Map<String, dynamic>;

      if (!mounted) return;

      setState(() {
        _notifications =
            notificationResult['notifications'] as List<Map<String, dynamic>>;

        _unreadCount = results[1] as int;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openAchievements() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const AchievementsScreen()),
    );

    if (mounted) {
      await _loadNotifications();
    }
  }

  Future<void> _markAllRead() async {
    if (_unreadCount == 0) {
      return;
    }

    setState(() {
      _markingAll = true;
    });

    try {
      final updatedCount = await _service.markAllNotificationsRead();

      if (!mounted) return;

      setState(() {
        _unreadCount = 0;

        _notifications = _notifications.map((notification) {
          return <String, dynamic>{
            ...notification,
            'is_read': true,
            'status': 'read',
          };
        }).toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$updatedCount notification(s) marked as read.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _markingAll = false;
        });
      }
    }
  }

  Future<void> _openNotification(Map<String, dynamic> notification) async {
    final notificationId = _integerValue(notification['id']);

    if (notificationId == null) {
      return;
    }

    final wasUnread = notification['is_read'] != true;

    if (wasUnread) {
      try {
        await _service.markNotificationRead(notificationId);

        if (!mounted) return;

        setState(() {
          notification['is_read'] = true;
          notification['status'] = 'read';

          if (_unreadCount > 0) {
            _unreadCount -= 1;
          }
        });
      } catch (error) {
        if (!mounted) return;

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));

        return;
      }
    }

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final payload = _asMap(notification['data_payload']);

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: const Color(0xFFF0EFFF),
                        child: Icon(
                          _notificationIcon(
                            notification['notification_type']?.toString(),
                          ),
                          color: const Color(0xFF6059E8),
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Text(
                          notification['title']?.toString() ?? 'Notification',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 17),
                  Text(
                    notification['body']?.toString() ?? '',
                    style: const TextStyle(fontSize: 16, height: 1.6),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        label: Text(
                          _typeLabel(
                            notification['notification_type']?.toString(),
                          ),
                        ),
                      ),
                      Chip(
                        label: Text(
                          '${notification['priority_level'] ?? 'normal'} priority',
                        ),
                      ),
                      Chip(
                        label: Text(
                          _displayDate(notification['created_at']?.toString()),
                        ),
                      ),
                    ],
                  ),
                  if (payload.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Related information',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 9),
                    ...payload.entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 130,
                              child: Text(
                                _fieldLabel(entry.key),
                                style: const TextStyle(
                                  color: Color(0xFF74748A),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                entry.value.toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteNotification(Map<String, dynamic> notification) async {
    final notificationId = _integerValue(notification['id']);

    if (notificationId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove notification?'),
          content: Text(
            notification['title']?.toString() ??
                'This notification will be removed.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _service.deleteNotification(notificationId);

      if (!mounted) return;

      final wasUnread = notification['is_read'] != true;

      setState(() {
        _notifications.removeWhere(
          (item) => _integerValue(item['id']) == notificationId,
        );

        if (wasUnread && _unreadCount > 0) {
          _unreadCount -= 1;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification removed.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  int? _integerValue(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '');
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  String _displayDate(String? value) {
    if (value == null || value.isEmpty) {
      return 'Unknown time';
    }

    final normalized = value.replaceFirst('T', ' ').replaceFirst('Z', '');

    return normalized.length > 16 ? normalized.substring(0, 16) : normalized;
  }

  String _fieldLabel(String value) {
    final words = value
        .replaceAll('_', ' ')
        .split(' ')
        .where((word) => word.isNotEmpty)
        .toList();

    return words
        .map((word) {
          return '${word[0].toUpperCase()}${word.substring(1)}';
        })
        .join(' ');
  }

  String _typeLabel(String? type) {
    switch (type) {
      case 'checkin_reminder':
        return 'Check-in reminder';
      case 'habit_reminder':
        return 'Habit reminder';
      case 'sleep_reminder':
        return 'Sleep reminder';
      case 'recovery_reminder':
        return 'Recovery reminder';
      case 'wellness_scan_reminder':
        return 'Wellness scan';
      case 'report_ready':
        return 'Report ready';
      case 'achievement':
        return 'Achievement';
      case 'inactivity':
        return 'Inactivity reminder';
      case 'announcement':
        return 'Announcement';
      default:
        return 'System';
    }
  }

  IconData _notificationIcon(String? type) {
    switch (type) {
      case 'checkin_reminder':
        return Icons.favorite_outline_rounded;
      case 'habit_reminder':
        return Icons.task_alt_rounded;
      case 'sleep_reminder':
        return Icons.bedtime_outlined;
      case 'recovery_reminder':
        return Icons.spa_outlined;
      case 'wellness_scan_reminder':
        return Icons.health_and_safety_outlined;
      case 'report_ready':
        return Icons.insights_rounded;
      case 'achievement':
        return Icons.emoji_events_rounded;
      case 'inactivity':
        return Icons.schedule_rounded;
      case 'announcement':
        return Icons.campaign_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FC),
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            onPressed: _openAchievements,
            tooltip: 'Achievements',
            icon: const Icon(Icons.emoji_events_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'read_all') {
                _markAllRead();
              } else if (value == 'refresh') {
                _loadNotifications();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem<String>(
                value: 'read_all',
                enabled: !_markingAll && _unreadCount > 0,
                child: const Text('Mark all as read'),
              ),
              const PopupMenuItem<String>(
                value: 'refresh',
                child: Text('Refresh'),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadNotifications,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: [
                  if (_errorMessage != null) _buildErrorBanner(),
                  _buildSummaryCard(),
                  const SizedBox(height: 16),
                  if (_notifications.isEmpty)
                    _buildEmptyState()
                  else
                    ..._notifications.map(_buildNotificationCard),
                ],
              ),
            ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade800)),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5C58E8), Color(0xFF875EF0)],
        ),
        borderRadius: BorderRadius.circular(23),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 27,
            backgroundColor: Color(0x33FFFFFF),
            child: Icon(
              Icons.notifications_active_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_unreadCount unread notification${_unreadCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_notifications.length} notification${_notifications.length == 1 ? '' : 's'} loaded',
                  style: const TextStyle(color: Color(0xFFEDEBFF)),
                ),
              ],
            ),
          ),
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markingAll ? null : _markAllRead,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: Text(_markingAll ? 'Saving...' : 'Read all'),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 55),
        child: Column(
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 76,
              color: Colors.grey,
            ),
            SizedBox(height: 15),
            Text(
              'No notifications available.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final isRead = notification['is_read'] == true;

    final priority = notification['priority_level']?.toString() ?? 'normal';

    return Card(
      margin: const EdgeInsets.only(bottom: 11),
      color: isRead ? Colors.white : const Color(0xFFF0EFFF),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openNotification(notification),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: isRead
                        ? const Color(0xFFF1F1F5)
                        : Colors.white,
                    child: Icon(
                      _notificationIcon(
                        notification['notification_type']?.toString(),
                      ),
                      color: const Color(0xFF6059E8),
                    ),
                  ),
                  if (!isRead)
                    Positioned(
                      right: -1,
                      top: -1,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: const BoxDecoration(
                          color: Color(0xFF6059E8),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification['title']?.toString() ?? 'Notification',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isRead
                                  ? FontWeight.w700
                                  : FontWeight.w900,
                            ),
                          ),
                        ),
                        if (priority == 'high')
                          const Icon(
                            Icons.priority_high_rounded,
                            color: Colors.red,
                            size: 20,
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      notification['body']?.toString() ?? '',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        height: 1.4,
                        color: Color(0xFF67677A),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      '${_typeLabel(notification['notification_type']?.toString())} • '
                      '${_displayDate(notification['created_at']?.toString())}',
                      style: const TextStyle(
                        color: Color(0xFF85859A),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') {
                    _deleteNotification(notification);
                  } else if (value == 'read' && !isRead) {
                    _openNotification(notification);
                  }
                },
                itemBuilder: (_) => [
                  if (!isRead)
                    const PopupMenuItem(
                      value: 'read',
                      child: Text('Mark as read'),
                    ),
                  const PopupMenuItem(value: 'delete', child: Text('Remove')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
