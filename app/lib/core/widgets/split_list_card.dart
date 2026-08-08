import 'package:app/core/localization/app_material.dart';

class SplitListCard extends StatelessWidget {
  final double height;
  final double leadingWidth;
  final dynamic icon;
  final Color accentColor;
  final Color leadingColor;
  final Color borderColor;
  final double iconContainerSize;
  final double iconSize;
  final Color? glowColor;
  final Widget child;

  const SplitListCard({
    super.key,
    required this.height,
    required this.icon,
    required this.accentColor,
    required this.leadingColor,
    required this.child,
    this.leadingWidth = 104,
    this.borderColor = const Color(0xFFE2E8F0),
    this.iconContainerSize = 54,
    this.iconSize = 28,
    this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: height,
          margin: const EdgeInsets.only(bottom: 14),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.07),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
              if (glowColor != null)
                BoxShadow(
                  color: glowColor!.withValues(alpha: 0.32),
                  blurRadius: 12,
                  spreadRadius: 0.8,
                  offset: const Offset(0, 1),
                ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: leadingWidth,
                child: ColoredBox(
                  color: leadingColor,
                  child: Center(
                    child: icon is Widget
                        ? icon as Widget
                        : Container(
                            width: iconContainerSize,
                            height: iconContainerSize,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.56),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon as IconData, color: accentColor, size: iconSize),
                          ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 11, 11, 11),
                  child: child,
                ),
              ),
            ],
          ),
        ),
        Positioned.fill(
          bottom: 14,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.outlineVariant
                      : borderColor,
                  width: glowColor != null ? 2.2 : 1.0,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class CompactAddButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const CompactAddButton({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: color,
          borderRadius: BorderRadius.circular(14),
          elevation: 0,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, color: Colors.white, size: 17),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CardActionMenu extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const CardActionMenu({
    super.key,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 28,
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        icon: const Icon(
          Icons.more_horiz_rounded,
          color: Color(0xFF64748B),
          size: 20,
        ),
        onSelected: (value) {
          if (value == 'edit') onEdit();
          if (value == 'delete') onDelete();
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 'edit', child: Text(context.tr('แก้ไข', 'Edit'))),
          PopupMenuItem(
            value: 'delete',
            child: Text(context.tr('ลบ', 'Delete'), style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
  }
}
