import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 데스크톱 좌측 내비 — 셸 탭 또는 go_router 직접 이동.
class DesktopNavRail extends StatelessWidget {
  const DesktopNavRail({
    super.key,
    this.shell,
    this.selectedIndex,
    this.addButtonSelected = false,
  });

  final StatefulNavigationShell? shell;
  final int? selectedIndex;
  /// `/plan/select` 등 오늘 선택 화면에서 + 버튼 강조.
  final bool addButtonSelected;

  static const primaryBlue = Color(0xFF4A90E2);

  int? get _idx => shell?.currentIndex ?? selectedIndex;

  void _goHome(BuildContext context) {
    if (shell != null) {
      shell!.goBranch(0);
    } else {
      context.go('/');
    }
  }

  void _goWeek(BuildContext context) {
    if (shell != null) {
      shell!.goBranch(1);
    } else {
      context.go('/plan/week');
    }
  }

  void _goProfile(BuildContext context) {
    if (shell != null) {
      shell!.goBranch(2);
    } else {
      context.go('/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    final idx = _idx;

    return Material(
      color: Colors.white,
      elevation: 1,
      shadowColor: Colors.black12,
      child: SafeArea(
        child: SizedBox(
          width: 72,
          child: Column(
            children: [
              const SizedBox(height: 16),
              _HomeNavButton(
                selected: idx == 0,
                onTap: () => _goHome(context),
              ),
              const SizedBox(height: 12),
              _CenterAddButton(
                selected: addButtonSelected,
                onTap: () => context.push('/plan/select'),
              ),
              const SizedBox(height: 12),
              _SideNavIcon(
                selected: idx == 1,
                icon: Icons.calendar_month_rounded,
                label: '주간',
                onTap: () => _goWeek(context),
              ),
              const SizedBox(height: 12),
              _SideNavIcon(
                selected: idx == 2,
                icon: Icons.person_outline_rounded,
                label: '프로필',
                onTap: () => _goProfile(context),
              ),
              const Spacer(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeNavButton extends StatelessWidget {
  const _HomeNavButton({
    required this.selected,
    required this.onTap,
  });

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: selected
                ? DesktopNavRail.primaryBlue
                : DesktopNavRail.primaryBlue.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            elevation: selected ? 4 : 0,
            shadowColor: DesktopNavRail.primaryBlue.withValues(alpha: 0.35),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Icon(
                  Icons.home_rounded,
                  color: selected ? Colors.white : DesktopNavRail.primaryBlue,
                  size: 26,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '홈',
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? DesktopNavRail.primaryBlue : const Color(0xFF8E93A3),
            ),
          ),
        ],
      ),
    );
  }
}

class _SideNavIcon extends StatelessWidget {
  const _SideNavIcon({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? DesktopNavRail.primaryBlue : const Color(0xFF8E93A3);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterAddButton extends StatelessWidget {
  const _CenterAddButton({
    required this.onTap,
    this.selected = false,
  });

  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DesktopNavRail.primaryBlue,
      elevation: selected ? 8 : 6,
      shadowColor: DesktopNavRail.primaryBlue.withValues(alpha: selected ? 0.6 : 0.45),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            Icons.add,
            color: Colors.white,
            size: selected ? 30 : 28,
          ),
        ),
      ),
    );
  }
}
