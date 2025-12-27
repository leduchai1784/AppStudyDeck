import 'package:flutter/material.dart';

/// Reusable widget for social login buttons
class SocialLoginButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? iconColor;
  final VoidCallback onPressed;
  final String? imagePath;

  const SocialLoginButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.iconColor,
    this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: imagePath != null
          ? Image.asset(
              imagePath!,
              width: 24,
              height: 24,
              errorBuilder: (context, error, stackTrace) {
                return Icon(icon, size: 24, color: iconColor);
              },
            )
          : Icon(icon, size: 24, color: iconColor),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

