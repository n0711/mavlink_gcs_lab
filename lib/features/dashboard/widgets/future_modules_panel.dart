import 'package:flutter/material.dart';

class FutureModulesPanel extends StatelessWidget {
  const FutureModulesPanel({super.key});

  @override
  Widget build(BuildContext context) {
    const modules = [
      _FutureModule(Icons.map_outlined, 'Map view', 'Future'),
      _FutureModule(Icons.route, 'Mission viewer', 'Future'),
      _FutureModule(Icons.history, 'Logs/replay', 'Future'),
      _FutureModule(Icons.description, 'Offline parameter viewer', 'Future'),
      _FutureModule(Icons.manage_search, 'Parameter diff/export', 'Future'),
      _FutureModule(
        Icons.visibility,
        'Live read-only parameters',
        'Level 1 future',
      ),
      _FutureModule(Icons.lock, 'Review-gated parameter writes', 'Locked'),
      _FutureModule(Icons.manage_search, 'MAVLink inspector', 'Future'),
      _FutureModule(Icons.health_and_safety, 'Vehicle health panel', 'Active'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: 4),
            title: Text(
              'Planned Modules',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text('Roadmap items'),
            iconColor: const Color(0xFF7DC6FF),
            collapsedIconColor: const Color(0xFF98A6B3),
            children: modules
                .map(
                  (module) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Icon(
                          module.icon,
                          size: 18,
                          color: module.isLocked
                              ? const Color(0xFFFF6B6B)
                              : const Color(0xFF7DC6FF),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            module.title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (module.isLocked
                                        ? const Color(0xFFFF6B6B)
                                        : const Color(0xFF7DC6FF))
                                    .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            module.badge,
                            style: TextStyle(
                              color: module.isLocked
                                  ? const Color(0xFFFF6B6B)
                                  : const Color(0xFF98A6B3),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _FutureModule {
  const _FutureModule(this.icon, this.title, this.badge);

  final IconData icon;
  final String title;
  final String badge;

  bool get isLocked => badge == 'Locked';
}
