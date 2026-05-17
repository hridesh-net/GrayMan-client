import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_theme.dart';
import '../../core/design_system/press_scale.dart';
import '../../models/worker.dart';
import '../../models/worker_dto.dart';
import '../../services/worker_service.dart';

class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({super.key, required this.worker, required this.onSaved});
  final Worker worker;
  final VoidCallback onSaved;

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late final _nameCtrl = TextEditingController(text: widget.worker.name);
  late final _tradeCtrl = TextEditingController(text: widget.worker.trade);
  late final _bioCtrl = TextEditingController(text: widget.worker.bio ?? '');
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await WorkerService.instance.updateSelf(WorkerUpdateRequest(
        name: _nameCtrl.text.trim(),
        trade: _tradeCtrl.text.trim(),
        bio: _bioCtrl.text.trim(),
      ));
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<GrayManTheme>();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom, left: 24, right: 24, top: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(theme.t('Edit profile', 'प्रोफ़ाइल संपादित'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          TextField(controller: _nameCtrl, decoration: _dec(theme.t('Name', 'नाम'))),
          const SizedBox(height: 12),
          TextField(controller: _tradeCtrl, decoration: _dec(theme.t('Trade', 'ट्रेड'))),
          const SizedBox(height: 12),
          TextField(controller: _bioCtrl, maxLines: 3, decoration: _dec(theme.t('Bio', 'बायो'))),
          const SizedBox(height: 16),
          PressScaleButton(
            onPressed: _saving ? null : _save,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: theme.accent, borderRadius: BorderRadius.circular(14)),
              child: Text(theme.t('Save', 'सेव'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.soft,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      );
}
