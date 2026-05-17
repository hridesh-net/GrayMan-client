import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_theme.dart';
import '../../core/design_system/blobs.dart';
import '../../core/design_system/press_scale.dart';
import '../../services/worker_service.dart';
import '../../models/worker_dto.dart';

class NameEntryScreen extends StatefulWidget {
  const NameEntryScreen({super.key, required this.onBack, required this.onNext});
  final VoidCallback onBack;
  final void Function(String name) onNext;

  @override
  State<NameEntryScreen> createState() => _NameEntryScreenState();
}

class _NameEntryScreenState extends State<NameEntryScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;

  Future<void> _submit() async {
    final name = _ctrl.text.trim();
    if (name.length < 2) return;
    setState(() => _loading = true);
    try {
      await WorkerService.instance.updateSelf(WorkerUpdateRequest(name: name));
    } catch (_) {}
    if (mounted) widget.onNext(name);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<GrayManTheme>();
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Stack(
        children: [
          Blobs(accent: theme.accent),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
                  const SizedBox(height: 16),
                  Text(theme.t('What should we call you?', 'हम आपको क्या बुलाएं?'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.shadowGrey)),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _ctrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(hintText: theme.t('Full name', 'पूरा नाम'), filled: true, fillColor: AppColors.soft, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)),
                  ),
                  const Spacer(),
                  PressScaleButton(
                    onPressed: _loading ? null : _submit,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 17),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: theme.accent, borderRadius: BorderRadius.circular(16)),
                      child: Text(theme.t('Continue', 'जारी रखें'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
