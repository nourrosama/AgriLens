import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:agrilens/core/theme.dart';

/// Floating chatbot button — matches TSX design exactly:
/// Simple green circle with chat icon, shadow, positioned bottom-right
class ChatbotButton extends StatelessWidget {
  const ChatbotButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 24,
      bottom: 96,
      child: GestureDetector(
        onTap: () => context.push('/chatbot'),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.chat_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}
