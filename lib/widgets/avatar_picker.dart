import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/profile.dart';

/// Avatar selection grid — 2 rows x 4 columns of preset avatars
class AvatarPicker extends StatelessWidget {
  final String? selectedKey;
  final ValueChanged<String> onSelect;

  const AvatarPicker({
    super.key,
    this.selectedKey,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final avatarKeys = Profile.avatarOptions.keys.toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
      ),
      itemCount: avatarKeys.length,
      itemBuilder: (context, index) {
        final key = avatarKeys[index];
        final emoji = Profile.avatarOptions[key]!;
        final isSelected = selectedKey == key;

        return GestureDetector(
          onTap: () => onSelect(key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: const Color(0xFFF0EAE0),
              borderRadius: BorderRadius.circular(AppRadius.large),
              border: isSelected
                  ? Border.all(color: AppColors.primary, width: 2.5)
                  : null,
            ),
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 36),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Circle avatar display widget
class AvatarCircle extends StatelessWidget {
  final String avatarKey;
  final double size;
  final bool showEditIcon;
  final VoidCallback? onTap;

  const AvatarCircle({
    super.key,
    required this.avatarKey,
    this.size = 48,
    this.showEditIcon = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final emoji = Profile.avatarOptions[avatarKey] ?? '\u{1F431}';

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: const Color(0xFFF0EAE0),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.white,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                emoji,
                style: TextStyle(fontSize: size * 0.5),
              ),
            ),
          ),
          if (showEditIcon)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: size * 0.3,
                height: size * 0.3,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.white, width: 2),
                ),
                child: Icon(
                  Icons.edit,
                  size: size * 0.15,
                  color: AppColors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
