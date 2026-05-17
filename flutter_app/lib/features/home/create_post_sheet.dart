import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_theme.dart';
import '../../core/design_system/press_scale.dart';
import '../../core/location/location_service.dart';
import '../../models/worker_dto.dart';
import '../../services/worker_service.dart';

class CreatePostSheet extends StatefulWidget {
  const CreatePostSheet({super.key, required this.onPosted});
  final void Function(PostDto post) onPosted;

  @override
  State<CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<CreatePostSheet> {
  final _bodyCtrl = TextEditingController();
  bool _posting = false;

  Future<void> _post() async {
    final body = _bodyCtrl.text.trim();
    if (body.isEmpty) return;
    setState(() => _posting = true);
    try {
      final loc = await LocationService.instance.current();
      final post = await WorkerService.instance.createPost(PostCreateRequest(body: body, lat: loc.lat, lng: loc.lng));
      if (mounted) {
        Navigator.pop(context);
        widget.onPosted(post);
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<GrayManTheme>();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom, left: 24, right: 24, top: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(theme.t('Create post', 'पोस्ट बनाएं'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          TextField(controller: _bodyCtrl, maxLines: 4, decoration: InputDecoration(hintText: theme.t('What did you work on?', 'आपने क्या काम किया?'), filled: true, fillColor: AppColors.soft, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
          const SizedBox(height: 16),
          PressScaleButton(
            onPressed: _posting ? null : _post,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: theme.accent, borderRadius: BorderRadius.circular(14)),
              child: Text(theme.t('Post', 'पोस्ट करें'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
