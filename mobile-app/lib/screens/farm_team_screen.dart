import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/user_provider.dart';
import 'package:agrilens/widgets/plan_gate.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Simple in-memory team member store
// ─────────────────────────────────────────────────────────────────────────────

enum _MemberRole { worker, agronomist, viewer }

class _TeamMember {
  final String id;
  final String name;
  final String phone;
  _MemberRole role;
  bool active;

  _TeamMember({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    this.active = true,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class FarmTeamScreen extends StatefulWidget {
  const FarmTeamScreen({super.key});

  @override
  State<FarmTeamScreen> createState() => _FarmTeamScreenState();
}

class _FarmTeamScreenState extends State<FarmTeamScreen> {
  // Demo members — in production, load from /api/farm/team
  final List<_TeamMember> _members = [
    _TeamMember(
        id: '1',
        name: 'Ahmed Hassan',
        phone: '+20 100 123 4567',
        role: _MemberRole.worker),
    _TeamMember(
        id: '2',
        name: 'Dr. Sara Nour',
        phone: '+20 112 987 6543',
        role: _MemberRole.agronomist),
  ];

  void _inviteMember(BuildContext context, bool isRTL) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    _MemberRole role = _MemberRole.worker;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isRTL ? 'دعوة عضو جديد' : 'Invite Team Member',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: isRTL ? 'الاسم الكامل' : 'Full Name',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: isRTL ? 'رقم الهاتف' : 'Phone Number',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Text(isRTL ? 'الدور:' : 'Role:',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Row(
                children: _MemberRole.values.map((r) {
                  final label = _roleLabel(r, isRTL);
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setModal(() => role = r),
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: role == r
                              ? AppColors.primary
                              : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: role == r
                                ? AppColors.primary
                                : const Color(0xFFE0E0E0),
                          ),
                        ),
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: role == r
                                ? Colors.white
                                : const Color(0xFF616161),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty) return;
                    setState(() {
                      _members.add(_TeamMember(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: nameCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        role: role,
                      ));
                    });
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isRTL
                            ? 'تم إرسال الدعوة!'
                            : 'Invitation sent!'),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(isRTL ? 'إرسال الدعوة' : 'Send Invite'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _roleLabel(_MemberRole role, bool isRTL) {
    switch (role) {
      case _MemberRole.worker:
        return isRTL ? 'عامل' : 'Worker';
      case _MemberRole.agronomist:
        return isRTL ? 'زراعي' : 'Agronomist';
      case _MemberRole.viewer:
        return isRTL ? 'مشاهد' : 'Viewer';
    }
  }

  Color _roleColor(_MemberRole role) {
    switch (role) {
      case _MemberRole.worker:
        return const Color(0xFF1976D2);
      case _MemberRole.agronomist:
        return const Color(0xFF388E3C);
      case _MemberRole.viewer:
        return const Color(0xFF9E9E9E);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final user = context.watch<UserProvider>();
    final isRTL = lang.isRTL;

    if (user.plan != 'professional') {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: GestureDetector(
            onTap: () => context.pop(),
            child: const Icon(Icons.arrow_back,
                color: AppColors.textSecondary),
          ),
          title: Text(
            isRTL ? 'فريق المزرعة' : 'Farm Team',
            style: const TextStyle(
                color: AppColors.primaryDark, fontWeight: FontWeight.bold),
          ),
        ),
        body: PlanGateBody(requiredPlan: 'professional', isRTL: isRTL),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: const Icon(Icons.arrow_back,
              color: AppColors.textSecondary),
        ),
        title: Text(
          isRTL ? 'فريق المزرعة' : 'Farm Team',
          style: const TextStyle(
              color: AppColors.primaryDark, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded,
                color: AppColors.primary),
            onPressed: () => _inviteMember(context, isRTL),
            tooltip: isRTL ? 'دعوة' : 'Invite',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _inviteMember(context, isRTL),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: Text(isRTL ? 'دعوة' : 'Invite Member',
            style: const TextStyle(color: Colors.white)),
      ),
      body: _members.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.group_outlined,
                        size: 72, color: Color(0xFFBDBDBD)),
                    const SizedBox(height: 16),
                    Text(
                      isRTL ? 'لا يوجد أعضاء في الفريق بعد' : 'No team members yet',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF616161)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _members.length,
              itemBuilder: (ctx, i) {
                final m = _members[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor:
                            _roleColor(m.role).withValues(alpha: 0.15),
                        radius: 22,
                        child: Text(
                          m.name[0].toUpperCase(),
                          style: TextStyle(
                              color: _roleColor(m.role),
                              fontWeight: FontWeight.bold,
                              fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF212121),
                                  fontSize: 15),
                            ),
                            const SizedBox(height: 2),
                            Text(m.phone,
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _roleColor(m.role)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _roleLabel(m.role, isRTL),
                              style: TextStyle(
                                  color: _roleColor(m.role),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _members.removeAt(i)),
                            child: const Text(
                              'Remove',
                              style: TextStyle(
                                  color: Color(0xFFF44336),
                                  fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
