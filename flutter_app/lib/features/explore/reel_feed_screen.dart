import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_theme.dart';
import '../../models/worker.dart';
import '../../core/networking/token_store.dart';
import '../../services/worker_service.dart';
import '../vouch/give_vouch_sheet.dart';

class ReelFeedScreen extends StatefulWidget {
  const ReelFeedScreen({
    super.key,
    required this.onBack,
    required this.onViewProfile,
    required this.onGoProfile,
    required this.onGoHome,
    required this.onGoSettings,
  });

  final VoidCallback onBack;
  final void Function(Worker) onViewProfile;
  final VoidCallback onGoProfile;
  final VoidCallback onGoHome;
  final VoidCallback onGoSettings;

  @override
  State<ReelFeedScreen> createState() => _ReelFeedScreenState();
}

class _ReelFeedScreenState extends State<ReelFeedScreen> {
  final _pageCtrl = PageController();
  List<Worker> _workers = [];
  int _radiusIndex = 0;
  String _trade = 'All';
  int _page = 1;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool append = false}) async {
    if (!append) setState(() => _loading = true);
    try {
      final list = await WorkerService.instance.fetchExplore(
        trade: _trade == 'All' ? null : _trade,
        radiusKm: Worker.radiusSteps[_radiusIndex].toDouble(),
        page: _page,
      );
      setState(() {
        if (append) {
          _workers.addAll(list);
        } else {
          _workers = list;
        }
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<GrayManTheme>();
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator(color: Colors.white))
          else if (_workers.isEmpty)
            Center(child: Text(theme.t('No workers nearby', 'पास कोई कामगार नहीं'), style: const TextStyle(color: Colors.white)))
          else
            PageView.builder(
              controller: _pageCtrl,
              scrollDirection: Axis.vertical,
              itemCount: _workers.length,
              onPageChanged: (i) {
                if (i >= _workers.length - 3) {
                  _page++;
                  _load(append: true);
                }
              },
              itemBuilder: (_, i) => _ReelPage(worker: _workers[i], onProfile: () => widget.onViewProfile(_workers[i])),
            ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back, color: Colors.white)),
                      const Spacer(),
                      _RadiusPill(
                        radius: Worker.radiusSteps[_radiusIndex],
                        onTap: () {
                          setState(() => _radiusIndex = (_radiusIndex + 1) % Worker.radiusSteps.length);
                          _page = 1;
                          _load();
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: Worker.allCategories.length,
                    itemBuilder: (_, i) {
                      final cat = Worker.allCategories[i];
                      final sel = cat == _trade;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(cat, style: TextStyle(color: sel ? Colors.white : Colors.white70, fontSize: 12)),
                          selected: sel,
                          onSelected: (_) {
                            setState(() => _trade = cat);
                            _page = 1;
                            _load();
                          },
                          selectedColor: theme.accent,
                          backgroundColor: Colors.white12,
                        ),
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

class _RadiusPill extends StatelessWidget {
  const _RadiusPill({required this.radius, required this.onTap});
  final int radius;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
        child: Row(children: [const Icon(Icons.radar, color: Colors.white, size: 16), const SizedBox(width: 6), Text('$radius km', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))]),
      ),
    );
  }
}

class _ReelPage extends StatefulWidget {
  const _ReelPage({required this.worker, required this.onProfile});
  final Worker worker;
  final VoidCallback onProfile;

  @override
  State<_ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends State<_ReelPage> {
  VideoPlayerController? _video;
  bool _liked = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
    _loadState();
  }

  Future<void> _loadState() async {
    if (TokenStore.instance.token == null) return;
    try {
      final s = await WorkerService.instance.fetchMyActionState(widget.worker.id);
      if (mounted) setState(() { _liked = s.hasLiked; _saved = s.hasSaved; });
    } catch (_) {}
  }

  Future<void> _initVideo() async {
    final url = widget.worker.reelPlaybackURL;
    if (url == null || url.isEmpty) return;
    final c = VideoPlayerController.networkUrl(Uri.parse(url));
    await c.initialize();
    c.setLooping(true);
    await c.play();
    if (mounted) setState(() => _video = c);
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.worker;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_video != null)
          FittedBox(fit: BoxFit.cover, child: SizedBox(width: _video!.value.size.width, height: _video!.value.size.height, child: VideoPlayer(_video!)))
        else if (w.reelThumbnailURL != null)
          Image.network(w.reelThumbnailURL!, fit: BoxFit.cover)
        else
          Container(color: w.gradientStart),
        Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black54]))),
        Positioned(
          left: 16,
          right: 80,
          bottom: 100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: widget.onProfile,
                child: Text('${w.emoji} ${w.name}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              ),
              Text('${w.trade} · ${w.location}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, children: w.tags.take(4).map((t) => Chip(label: Text(t, style: const TextStyle(fontSize: 11)), backgroundColor: Colors.white24, padding: EdgeInsets.zero)).toList()),
            ],
          ),
        ),
        Positioned(
          right: 12,
          bottom: 100,
          child: Column(
            children: [
              _ActionBtn(icon: _liked ? Icons.favorite : Icons.favorite_border, onTap: () async {
                if (_liked) await WorkerService.instance.unlike(w.id); else await WorkerService.instance.like(w.id);
                setState(() => _liked = !_liked);
              }),
              _ActionBtn(icon: _saved ? Icons.bookmark : Icons.bookmark_border, onTap: () async {
                if (_saved) await WorkerService.instance.unsave(w.id); else await WorkerService.instance.save(w.id);
                setState(() => _saved = !_saved);
              }),
              _ActionBtn(icon: Icons.handshake_outlined, onTap: () => showModalBottomSheet(context: context, builder: (_) => GiveVouchSheet(worker: w))),
              _ActionBtn(icon: Icons.phone, onTap: () => launchUrl(Uri.parse('tel:${w.phone}'))),
              _ActionBtn(icon: Icons.chat_bubble_outline, onTap: () {}),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: IconButton(onPressed: onTap, icon: Icon(icon, color: Colors.white, size: 28)),
    );
  }
}
