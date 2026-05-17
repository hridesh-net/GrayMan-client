import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_theme.dart';
import '../../core/design_system/blobs.dart';
import '../../core/design_system/press_scale.dart';

class AvatarPickerScreen extends StatefulWidget {
  const AvatarPickerScreen({super.key, required this.name, required this.onBack, required this.onNext});
  final String name;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  State<AvatarPickerScreen> createState() => _AvatarPickerScreenState();
}

class _AvatarPickerScreenState extends State<AvatarPickerScreen> {
  File? _image;

  Future<void> _pick() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800);
    if (x != null) setState(() => _image = File(x.path));
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<GrayManTheme>();
    final first = widget.name.split(' ').first;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Stack(
        children: [
          Blobs(accent: theme.accent),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Align(alignment: Alignment.centerLeft, child: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back))),
                  Text(theme.t('Add a photo, $first?', 'फ़ोटो जोड़ें, $first?'), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.shadowGrey)),
                  const SizedBox(height: 8),
                  Text(theme.t('Optional — helps hirers recognise you', 'वैकल्पिक — हायरों को पहचानने में मदद'), style: const TextStyle(color: AppColors.mutedText)),
                  const SizedBox(height: 40),
                  GestureDetector(
                    onTap: _pick,
                    child: CircleAvatar(
                      radius: 64,
                      backgroundColor: AppColors.soft,
                      backgroundImage: _image != null ? FileImage(_image!) : null,
                      child: _image == null ? Icon(Icons.camera_alt, size: 36, color: theme.accent) : null,
                    ),
                  ),
                  const Spacer(),
                  PressScaleButton(
                    onPressed: widget.onNext,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 17),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: theme.accent, borderRadius: BorderRadius.circular(16)),
                      child: Text(theme.t('Continue', 'जारी रखें'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(onPressed: widget.onNext, child: Text(theme.t('Skip for now', 'अभी छोड़ें'), style: const TextStyle(color: AppColors.mutedText))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
