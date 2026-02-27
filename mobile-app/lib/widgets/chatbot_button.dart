import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:agrilens/core/theme.dart';

/// Floating chatbot button — appears on main screens
class ChatbotButton extends StatelessWidget {
  const ChatbotButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 20,
      bottom: 90,
      child: GestureDetector(
        onTap: () => context.push('/chatbot'),
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.chat_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}
