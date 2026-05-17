import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_theme.dart';
import '../../core/design_system/blobs.dart';
import '../../core/design_system/press_scale.dart';
import '../../core/networking/token_store.dart';
import '../../models/worker_dto.dart';
import '../../services/interview_session.dart';

class VoiceInterviewScreen extends StatefulWidget {
  const VoiceInterviewScreen({super.key, required this.trade, required this.onClose});
  final String trade;
  final VoidCallback onClose;

  @override
  State<VoiceInterviewScreen> createState() => _VoiceInterviewScreenState();
}

class _VoiceInterviewScreenState extends State<VoiceInterviewScreen> {
  String _lang = 'en';
  InterviewSession? _session;
  InterviewScores? _scores;
  String _status = 'pick';
  String _lastText = '';

  Future<void> _start() async {
    final token = TokenStore.instance.token;
    if (token == null) return;
    setState(() => _status = 'connecting');
    final s = InterviewSession(token: token, lang: _lang, trade: widget.trade);
    s.onStateChange = (st) {
      if (mounted) setState(() {
        if (st == InterviewState.failed) _status = 'failed';
        if (st == InterviewState.ended) _status = 'done';
        if (st == InterviewState.listening) _status = 'live';
      });
    };
    s.onText = (t) => setState(() => _lastText = t);
    s.onScores = (sc) => setState(() { _scores = sc; _status = 'result'; });
    s.onError = (_) => setState(() => _status = 'failed');
    _session = s;
    await s.connect();
  }

  @override
  void dispose() {
    _session?.disconnect();
    super.dispose();
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
                  Row(
                    children: [
                      IconButton(onPressed: widget.onClose, icon: const Icon(Icons.close)),
                      Text(theme.t('AI Voice Interview', 'AI वॉयस इंटरव्यू'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_status == 'pick') ...[
                    Text(theme.t('Choose language', 'भाषा चुनें')),
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, children: [
                      _LangChip('English', 'en', _lang, (l) => setState(() => _lang = l)),
                      _LangChip('हिंदी', 'hi', _lang, (l) => setState(() => _lang = l)),
                      _LangChip('Hinglish', 'hi-en', _lang, (l) => setState(() => _lang = l)),
                    ]),
                    const Spacer(),
                    PressScaleButton(
                      onPressed: _start,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 17),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: theme.accent, borderRadius: BorderRadius.circular(16)),
                        child: Text(theme.t('Start Interview', 'इंटरव्यू शुरू'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ] else if (_status == 'connecting' || _status == 'live') ...[
                    const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: 24),
                    Center(child: Text(_status == 'live' ? theme.t('Listening…', 'सुन रहे हैं…') : theme.t('Connecting…', 'कनेक्ट हो रहा…'))),
                    if (_lastText.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(_lastText, style: const TextStyle(color: AppColors.mutedText)),
                    ],
                    const Spacer(),
                    PressScaleButton(
                      onPressed: () { _session?.end(); setState(() => _status = 'done'); },
                      child: Text(theme.t('End interview', 'समाप्त'), style: TextStyle(color: theme.accent, fontWeight: FontWeight.bold)),
                    ),
                  ] else if (_status == 'result' && _scores != null) ...[
                    _ScoreRow(theme.t('Confidence', 'आत्मविश्वास'), _scores!.confidence),
                    _ScoreRow(theme.t('Clarity', 'स्पष्टता'), _scores!.clarity),
                    _ScoreRow(theme.t('Trade skill', 'ट्रेड'), _scores!.tradeCompetence),
                    const SizedBox(height: 16),
                    Text(_scores!.summary, style: const TextStyle(color: AppColors.mutedText)),
                    const Spacer(),
                    PressScaleButton(onPressed: widget.onClose, child: Text(theme.t('Done', 'हो गया'), style: TextStyle(color: theme.accent, fontWeight: FontWeight.bold))),
                  ] else ...[
                    Text(theme.t('Something went wrong', 'कुछ गलत हुआ'), style: const TextStyle(color: AppColors.errorRed)),
                    TextButton(onPressed: () => setState(() => _status = 'pick'), child: Text(theme.t('Try again', 'फिर कोशिश'))),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  const _LangChip(this.label, this.code, this.selected, this.onSelect);
  final String label;
  final String code;
  final String selected;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    final sel = code == selected;
    return FilterChip(label: Text(label), selected: sel, onSelected: (_) => onSelect(code));
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow(this.label, this.value);
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Text('$value', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
