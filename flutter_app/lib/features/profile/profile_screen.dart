import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_theme.dart';
import '../../core/design_system/avatar_bubble.dart';
import '../../core/design_system/blobs.dart';
import '../../core/design_system/flow_layout.dart';
import '../../core/design_system/floating_tab_bar.dart';
import '../../core/design_system/glass_card.dart';
import '../../core/design_system/press_scale.dart';
import '../../core/design_system/vouch_score_ring.dart';
import '../../models/worker.dart';
import '../../services/worker_service.dart';
import '../interview/voice_interview_screen.dart';
import '../notifications/notifications_screen.dart';
import '../vouch/give_vouch_sheet.dart';
import 'edit_profile_sheet.dart';
import 'proof_of_work_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.worker,
    this.userName = '',
    this.onBack,
    this.onExplore,
    this.onSignOut,
    this.onRecordReel,
    this.onHome,
  });

  final Worker? worker;
  final String userName;
  final VoidCallback? onBack;
  final VoidCallback? onExplore;
  final VoidCallback? onSignOut;
  final VoidCallback? onRecordReel;
  final VoidCallback? onHome;

  bool get isSelf => worker == null;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Worker? _self;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.isSelf) _loadSelf();
    else {
      _loading = false;
    }
  }

  Future<void> _loadSelf() async {
    try {
      final w = await WorkerService.instance.fetchSelf();
      if (mounted) setState(() { _self = w; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Worker? get _display => widget.worker ?? _self;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<GrayManTheme>();
    final w = _display;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Stack(
        children: [
          Blobs(accent: theme.accent, opacity: 0.5),
          SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                          child: Row(
                            children: [
                              if (widget.onBack != null)
                                IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back))
                              else
                                const SizedBox(width: 8),
                              const Spacer(),
                              if (widget.isSelf)
                                IconButton(
                                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsScreen(onBack: () => Navigator.pop(context)))),
                                  icon: const Icon(Icons.notifications_outlined),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (w != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: GlassCard(
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      AvatarBubble(initials: w.initials, avatarUrl: w.avatarURL, size: 64, gradientStart: w.gradientStart, gradientEnd: w.gradientEnd),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(child: Text(w.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
                                                if (w.isVerified) const Icon(Icons.verified, color: AppColors.verifiedBlue),
                                              ],
                                            ),
                                            Text('${w.trade} · ${w.location}', style: const TextStyle(color: AppColors.mutedText, fontSize: 13)),
                                          ],
                                        ),
                                      ),
                                      VouchScoreRing(score: w.vouchScore),
                                    ],
                                  ),
                                  if (w.bio != null && w.bio!.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Align(alignment: Alignment.centerLeft, child: Text(w.bio!, style: const TextStyle(color: AppColors.mutedText))),
                                  ],
                                  const SizedBox(height: 16),
                                  FlowLayout(
                                    spacing: 8,
                                    children: w.tags.asMap().entries.map((e) {
                                      final verified = w.verifiedTagIndices.contains(e.key);
                                      return Chip(
                                        label: Row(mainAxisSize: MainAxisSize.min, children: [
                                          Text(e.value),
                                          if (verified) ...[const SizedBox(width: 4), const Icon(Icons.verified, size: 14, color: AppColors.verifiedBlue)],
                                        ]),
                                        backgroundColor: AppColors.soft,
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      SliverToBoxAdapter(child: SizedBox(height: 20)),
                      if (widget.isSelf && w != null) ...[
                        SliverToBoxAdapter(child: _ActionRow(theme: theme, onRecordReel: widget.onRecordReel, onInterview: () {
                          Navigator.push(context, MaterialPageRoute(fullscreenDialog: true, builder: (_) => VoiceInterviewScreen(trade: w.trade, onClose: () => Navigator.pop(context))));
                        }, onProof: () {
                          Navigator.push(context, MaterialPageRoute(fullscreenDialog: true, builder: (_) => ProofOfWorkScreen(workerId: w.id, onClose: () => Navigator.pop(context))));
                        }, onEdit: () {
                          showModalBottomSheet(context: context, builder: (_) => EditProfileSheet(worker: w, onSaved: _loadSelf));
                        })),
                      ] else if (w != null) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                Expanded(child: _Cta(theme.t('Call', 'कॉल'), Icons.phone, () => launchUrl(Uri.parse('tel:${w.phone}')))),
                                const SizedBox(width: 10),
                                Expanded(child: _Cta(theme.t('WhatsApp', 'व्हाट्सऐप'), Icons.chat, () => launchUrl(Uri.parse('https://wa.me/${w.phone.replaceAll('+', '')}')))),
                                const SizedBox(width: 10),
                                Expanded(child: _Cta(theme.t('Vouch', 'वाउच'), Icons.handshake, () => showModalBottomSheet(context: context, builder: (_) => GiveVouchSheet(worker: w)))),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SliverToBoxAdapter(child: SizedBox(height: 120)),
                    ],
                  ),
          ),
          if (widget.isSelf)
            Positioned(
              left: 12,
              right: 12,
              bottom: 20,
              child: FloatingTabBar(
                active: TabItem.profile,
                accent: theme.accent,
                t: theme.t,
                onHome: widget.onHome ?? () {},
                onExplore: widget.onExplore ?? () {},
                onProfile: () {},
                onSettings: () => Navigator.push(context, MaterialPageRoute(fullscreenDialog: true, builder: (_) => SettingsScreen(onSignOut: widget.onSignOut ?? () {}, onBack: () => Navigator.pop(context)))),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.theme, this.onRecordReel, this.onInterview, this.onProof, this.onEdit});
  final GrayManTheme theme;
  final VoidCallback? onRecordReel;
  final VoidCallback? onInterview;
  final VoidCallback? onProof;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _chip(theme.t('Record Reel', 'रील रिकॉर्ड'), Icons.videocam, onRecordReel),
          _chip(theme.t('AI Interview', 'AI इंटरव्यू'), Icons.mic, onInterview),
          _chip(theme.t('Proof of Work', 'काम का प्रमाण'), Icons.photo_library, onProof),
          _chip(theme.t('Edit Profile', 'प्रोफ़ाइल संपादित'), Icons.edit, onEdit),
        ],
      ),
    );
  }

  Widget _chip(String label, IconData icon, VoidCallback? onTap) => PressScaleButton(
        onPressed: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 18, color: theme.accent), const SizedBox(width: 6), Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))]),
        ),
      );
}

class _Cta extends StatelessWidget {
  const _Cta(this.label, this.icon, this.onTap);
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScaleButton(
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(14)),
        child: Column(children: [Icon(icon), const SizedBox(height: 4), Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))]),
      ),
    );
  }
}
