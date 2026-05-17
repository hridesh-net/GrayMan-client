import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_theme.dart';
import '../../core/design_system/blobs.dart';
import '../../models/worker_dto.dart';
import '../../services/worker_service.dart';

class ProofOfWorkScreen extends StatefulWidget {
  const ProofOfWorkScreen({super.key, required this.workerId, required this.onClose});
  final String workerId;
  final VoidCallback onClose;

  @override
  State<ProofOfWorkScreen> createState() => _ProofOfWorkScreenState();
}

class _ProofOfWorkScreenState extends State<ProofOfWorkScreen> {
  List<ShowcaseItemDto> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await WorkerService.instance.fetchShowcase(widget.workerId);
      setState(() { _items = items; _loading = false; });
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
          Blobs(accent: theme.accent),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(onPressed: widget.onClose, icon: const Icon(Icons.close)),
                      Text(theme.t('Proof of Work', 'काम का प्रमाण'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12),
                          itemCount: _items.length,
                          itemBuilder: (_, i) {
                            final item = _items[i];
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: item.thumbnailURL != null
                                  ? Image.network(item.thumbnailURL!, fit: BoxFit.cover)
                                  : Container(color: AppColors.soft, child: Center(child: Text(item.title))),
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
