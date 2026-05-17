import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_theme.dart';
import '../../core/design_system/blobs.dart';
import '../../core/design_system/floating_tab_bar.dart';
import '../../core/design_system/glass_card.dart';
import '../../core/location/location_service.dart';
import '../../models/worker.dart';
import '../../models/worker_dto.dart';
import '../../services/offline_reel_queue.dart';
import '../../services/worker_service.dart';
import 'post_card.dart';
import 'create_post_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.userName,
    required this.onProfile,
    required this.onExplore,
    required this.onSettings,
    required this.onViewWorker,
  });

  final String userName;
  final VoidCallback onProfile;
  final VoidCallback onExplore;
  final VoidCallback onSettings;
  final void Function(Worker worker) onViewWorker;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Worker? _worker;
  List<PostDto> _posts = [];
  String? _locationLabel;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    OfflineReelQueue.instance.addListener(_onQueue);
  }

  @override
  void dispose() {
    OfflineReelQueue.instance.removeListener(_onQueue);
    super.dispose();
  }

  void _onQueue() => setState(() {});

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final w = await WorkerService.instance.fetchSelf();
      final posts = await WorkerService.instance.fetchFeed();
      final place = await LocationService.instance.currentPlaceStrict();
      if (mounted) {
        setState(() {
          _worker = w;
          _posts = posts;
          _locationLabel = place?.shortLabel;
          _loading = false;
        });
      }
      await WorkerService.instance.syncSelfLocationIfNeeded();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<GrayManTheme>();
    final queue = OfflineReelQueue.instance;
    final displayName = (_worker?.name ?? widget.userName).split(' ').first;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Stack(
        children: [
          Blobs(accent: theme.accent, opacity: 0.55),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                      child: Row(
                        children: [
                          const Text('sthapna.ai', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.shadowGrey)),
                          const Spacer(),
                          Container(width: 7, height: 7, decoration: BoxDecoration(color: theme.accent, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Text(theme.t('Live', 'लाइव'), style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(theme.t('Hello, $displayName', 'नमस्ते, $displayName'), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.shadowGrey)),
                          if (_locationLabel != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(children: [const Icon(Icons.location_on, size: 14, color: AppColors.dimText), const SizedBox(width: 4), Text(_locationLabel!, style: const TextStyle(fontSize: 13, color: AppColors.dimText))]),
                            ),
                          if (queue.pendingCount > 0) ...[
                            const SizedBox(height: 16),
                            _QueueBanner(queue: queue, accent: theme.accent, t: theme.t),
                          ],
                          const SizedBox(height: 16),
                          if (_loading)
                            const LinearProgressIndicator(minHeight: 2, color: AppColors.shadowGrey)
                          else if (_worker != null)
                            _StatsCard(worker: _worker!),
                          const SizedBox(height: 22),
                          Text(theme.t('Recent Work', 'हाल का काम'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.shadowGrey)),
                        ],
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                        child: PostCard(post: _posts[i], onAuthorTap: () async {
                          try {
                            final w = await WorkerService.instance.fetchWorker(_posts[i].author.id);
                            widget.onViewWorker(w);
                          } catch (_) {}
                        }),
                      ),
                      childCount: _posts.length,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 20,
            child: FloatingTabBar(
              active: TabItem.home,
              accent: theme.accent,
              t: theme.t,
              onHome: () {},
              onExplore: widget.onExplore,
              onProfile: widget.onProfile,
              onSettings: widget.onSettings,
              onCenterAction: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: AppColors.canvas,
                builder: (_) => CreatePostSheet(onPosted: (p) {
                  setState(() => _posts = [p, ..._posts]);
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueBanner extends StatelessWidget {
  const _QueueBanner({required this.queue, required this.accent, required this.t});
  final OfflineReelQueue queue;
  final Color accent;
  final String Function(String, String) t;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => queue.flush(),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            queue.isFlushing ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: accent)) : Icon(Icons.cloud_upload, color: accent),
            const SizedBox(width: 12),
            Expanded(child: Text(t('${queue.pendingCount} reel(s) uploading when online', '${queue.pendingCount} रील अपलोड हो रही'))),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.worker});
  final Worker worker;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat('${worker.jobs}', 'Jobs'),
          _stat(worker.rating, 'Rating'),
          _stat('${worker.vouchScore}', 'Vouch'),
        ],
      ),
    );
  }

  Widget _stat(String v, String l) => Column(children: [Text(v, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)), Text(l, style: const TextStyle(fontSize: 12, color: AppColors.mutedText))]);
}
