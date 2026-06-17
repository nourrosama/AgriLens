import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/user_provider.dart';
import 'package:agrilens/widgets/plan_gate.dart';

class ChatbotButton extends StatelessWidget {
  const ChatbotButton({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final lang = context.watch<LanguageProvider>();
    final canAccess = user.plan == 'premium' || user.plan == 'professional';

    return Positioned(
      right: 20,
      bottom: 90,
      child: GestureDetector(
        onTap: () {
          if (canAccess) {
            context.push('/chatbot');
          } else {
            showPlanGateSheet(
              context,
              requiredPlan: 'premium',
              isRTL: lang.isRTL,
            );
          }
        },
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: canAccess
                  ? [const Color(0xFF4CAF50), const Color(0xFF2E7D32)]
                  : [const Color(0xFFBDBDBD), const Color(0xFF9E9E9E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (canAccess
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFF9E9E9E))
                    .withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 28),
              if (!canAccess)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      color: Color(0xFF9E9E9E),
                      size: 10,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
