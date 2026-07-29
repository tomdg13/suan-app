import 'package:flutter/material.dart';

class NavItem {
  final String label;
  final IconData icon;
  final int index; // maps to the content view shown on the right

  const NavItem({required this.label, required this.icon, required this.index});
}

class NavGroup {
  final String title;
  final List<NavItem> items;

  const NavGroup({required this.title, required this.items});
}

/// Left sidebar navigation used by the Admin and Seller shells.
/// Groups are always expanded (simple + predictable for a small menu tree).
class SideNav extends StatelessWidget {
  final List<NavGroup> groups;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final String headerTitle;
  final IconData headerIcon;
  final VoidCallback? onLogout;

  const SideNav({
    super.key,
    required this.groups,
    required this.selectedIndex,
    required this.onSelect,
    required this.headerTitle,
    required this.headerIcon,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(headerIcon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    headerTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final group in groups) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      group.title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.outline,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  for (final item in group.items)
                    _NavTile(
                      item: item,
                      selected: item.index == selectedIndex,
                      onTap: () => onSelect(item.index),
                    ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          if (onLogout != null)
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: onLogout,
            ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavTile({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? Theme.of(context).colorScheme.primary : null;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: selected
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
            : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(item.icon, size: 20, color: color),
        title: Text(item.label, style: TextStyle(color: color, fontSize: 14)),
        onTap: onTap,
      ),
    );
  }
}
