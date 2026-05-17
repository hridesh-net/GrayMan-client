import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_theme.dart';
import '../../core/design_system/blobs.dart';
import '../../models/worker_dto.dart';
import '../../services/worker_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.onBack});
  final VoidCallback onBack;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationDto> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await WorkerService.instance.fetchNotifications();
      setState(() { _items = res.notifications; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<GrayManTheme>();
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Stack(
        children: [
          Blobs(accent: theme.accent, opacity: 0.5),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
                      Text(theme.t('Notifications', 'सूचनाएं'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _items.isEmpty
                          ? Center(child: Text(theme.t('No notifications', 'कोई सूचना नहीं'), style: const TextStyle(color: AppColors.mutedText)))
                          : ListView.builder(
                              itemCount: _items.length,
                              itemBuilder: (_, i) {
                                final n = _items[i];
                                return ListTile(
                                  title: Text(n.kind),
                                  subtitle: Text(n.status),
                                  trailing: n.status == 'unread'
                                      ? TextButton(
                                          onPressed: () async {
                                            await WorkerService.instance.markNotificationRead(n.id);
                                            _load();
                                          },
                                          child: Text(theme.t('Read', 'पढ़ा')),
                                        )
                                      : null,
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
