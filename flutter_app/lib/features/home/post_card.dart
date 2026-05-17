import 'package:flutter/material.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/design_system/avatar_bubble.dart';
import '../../models/worker_dto.dart';

class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.post, this.onAuthorTap});
  final PostDto post;
  final VoidCallback? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.shadowGrey.withValues(alpha: 0.06))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onAuthorTap,
            child: Row(
              children: [
                AvatarBubble(initials: post.author.name.isNotEmpty ? post.author.name[0] : '?', avatarUrl: post.author.avatarURL, size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(post.author.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          if (post.author.isVerified) ...[const SizedBox(width: 4), const Icon(Icons.verified, color: AppColors.verifiedBlue, size: 16)],
                        ],
                      ),
                      Text(post.author.trade, style: const TextStyle(fontSize: 12, color: AppColors.mutedText)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (post.body.isNotEmpty) ...[const SizedBox(height: 12), Text(post.body)],
          if (post.imageURL != null) ...[
            const SizedBox(height: 12),
            ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(post.imageURL!, height: 180, width: double.infinity, fit: BoxFit.cover)),
          ],
        ],
      ),
    );
  }
}
