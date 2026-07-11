import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/palette.dart';
import '../../core/providers.dart';
import '../../core/responsive.dart';
import '../../shared/widgets.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepository(ref.watch(apiClientProvider).dio),
);

final notificationsProvider =
    FutureProvider.autoDispose<List<AppNotification>>(
  (ref) => ref.watch(notificationsRepositoryProvider).list(),
);

class AppNotification {
  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get unread => readAt == null;

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String,
        type: (j['type'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        body: (j['body'] ?? '') as String,
        createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
        readAt: j['readAt'] == null
            ? null
            : DateTime.parse(j['readAt'] as String).toLocal(),
      );
}

class NotificationsRepository {
  NotificationsRepository(this._dio);
  final Dio _dio;

  Future<List<AppNotification>> list() async {
    final res = await _dio.get<List<dynamic>>('/notifications');
    return res.data!
        .cast<Map<String, dynamic>>()
        .map(AppNotification.fromJson)
        .toList();
  }

  Future<void> markAllRead() async {
    await _dio.post<void>('/notifications/read');
  }
}

const _typeIcons = <String, IconData>{
  'BOOKING_CONFIRMED': Icons.check_circle_outline,
  'BOOKING_CANCELLED': Icons.event_busy_outlined,
  'BOOKING_REMINDER': Icons.alarm,
  'MATCH_JOIN_REQUEST': Icons.person_add_alt_1_outlined,
  'MATCH_REQUEST_ACCEPTED': Icons.how_to_reg_outlined,
  'MATCH_CONFIRMED': Icons.sports_tennis,
  'MATCH_CANCELLED': Icons.cancel_outlined,
  'MATCH_PLAYER_WITHDREW': Icons.person_remove_outlined,
};

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifs = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(notificationsRepositoryProvider).markAllRead();
              ref.invalidate(notificationsProvider);
            },
            child: const Text('Tout marquer lu'),
          ),
        ],
      ),
      body: PageContainer(
        maxWidth: 720,
        child: notifs.when(
          loading: () => const CenteredLoader(),
          error: (e, _) => ErrorRetry(
            message: apiErrorMessage(e),
            onRetry: () => ref.invalidate(notificationsProvider),
          ),
          data: (list) {
            if (list.isEmpty) {
              return const EmptyState(
                icon: Icons.notifications_none_rounded,
                title: 'Aucune notification',
                subtitle:
                    'Vos confirmations de réservation et demandes de match\napparaîtront ici.',
              );
            }
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(notificationsProvider),
              child: ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final n = list[i];
                  return SoftCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 42,
                          width: 42,
                          decoration: BoxDecoration(
                            color: n.unread
                                ? AppColors.primary.withValues(alpha: 0.14)
                                : AppColors.line.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _typeIcons[n.type] ?? Icons.notifications_none,
                            size: 21,
                            color: n.unread
                                ? AppColors.primaryDark
                                : AppColors.slate,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      n.title,
                                      style: TextStyle(
                                        fontWeight: n.unread
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (n.unread)
                                    Container(
                                      height: 8,
                                      width: 8,
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                n.body,
                                style: const TextStyle(
                                    color: AppColors.slate, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('d MMM · HH:mm', 'fr')
                                    .format(n.createdAt),
                                style: const TextStyle(
                                    color: AppColors.slate, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
