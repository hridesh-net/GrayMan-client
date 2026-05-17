import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_theme.dart';
import '../../core/design_system/press_scale.dart';
import '../../core/design_system/vouch_score_ring.dart';
import '../../models/worker.dart';
import '../../services/worker_service.dart';

class GiveVouchSheet extends StatefulWidget {
  const GiveVouchSheet({super.key, required this.worker});
  final Worker worker;

  @override
  State<GiveVouchSheet> createState() => _GiveVouchSheetState();
}

class _GiveVouchSheetState extends State<GiveVouchSheet> {
  int _rating = 5;
  final Set<int> _selectedSkills = {};
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    setState(() { _submitting = true; _error = null; });
    try {
      await WorkerService.instance.giveVouch(
        widget.worker.id,
        _selectedSkills.isEmpty ? [0] : _selectedSkills.toList(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<GrayManTheme>();
    final w = widget.worker;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              VouchScoreRing(score: w.vouchScore, size: 48),
              const SizedBox(width: 12),
              Expanded(child: Text(theme.t('Vouch for ${w.name}', '${w.name} को वाउच'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
            ],
          ),
          const SizedBox(height: 16),
          Text(theme.t('Rate their work', 'उनके काम को रेट करें')),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) => IconButton(
                  onPressed: () => setState(() => _rating = i + 1),
                  icon: Icon(i < _rating ? Icons.star : Icons.star_border, color: theme.accent, size: 32),
                )),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: w.tags.asMap().entries.map((e) {
              final sel = _selectedSkills.contains(e.key);
              return FilterChip(
                label: Text(e.value),
                selected: sel,
                onSelected: (v) => setState(() {
                  if (v) _selectedSkills.add(e.key); else _selectedSkills.remove(e.key);
                }),
                selectedColor: theme.accent.withValues(alpha: 0.2),
              );
            }).toList(),
          ),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: AppColors.errorRed, fontSize: 12))),
          const SizedBox(height: 16),
          PressScaleButton(
            onPressed: _submitting ? null : _submit,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: theme.accent, borderRadius: BorderRadius.circular(14)),
              child: Text(theme.t('Submit Vouch', 'वाउच जमा करें'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
