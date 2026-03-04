// Dashboard app bar (plan Step 11).

import 'package:flutter/material.dart';

import 'dashboard_controller.dart';

class DashboardAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DashboardAppBar({
    super.key,
    required this.controller,
    required this.onSignOut,
  });

  final DashboardController controller;
  final VoidCallback onSignOut;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = controller;
    return AppBar(
      title: Semantics(
        header: true,
        child: const Text('fichAR'),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 4, top: 4, bottom: 4),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  c.userName ?? c.userEmail ?? '...',
                  style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (c.userEmail != null && c.userName != null)
                  Text(
                    c.userEmail!,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onPrimary.withValues(alpha: 0.9)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ),
        Semantics(
          label: 'Cerrar sesión',
          button: true,
          child: IconButton(
            icon: c.signingOut
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.logout),
            onPressed: c.signingOut ? null : onSignOut,
            tooltip: 'Cerrar sesión',
          ),
        ),
      ],
    );
  }
}
