// Nav grid for dashboard (plan Step 11).

import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../theme/layout_tokens.dart';
import '../../widgets/nav_card.dart';

class NavGridItem {
  const NavGridItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final VoidCallback onTap;
}

class NavGrid extends StatelessWidget {
  const NavGrid({
    super.key,
    required this.screenWidth,
    required this.items,
  });

  final double screenWidth;
  final List<NavGridItem> items;

  static const double _childAspectRatio = 0.92;

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = screenWidth >= kBreakpointTablet ? 3 : 2;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: kSpacingMd,
      crossAxisSpacing: kSpacingMd,
      childAspectRatio: _childAspectRatio,
      padding: EdgeInsets.zero,
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.all(kSpacingXs),
              child: NavCard(
                icon: item.icon,
                title: item.title,
                onTap: item.onTap,
              ),
            ),
          )
          .toList(),
    );
  }
}
