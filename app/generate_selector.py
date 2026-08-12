import re
import os

with open('lib/icon_selector_demo.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Extract arrays
def extract_array(array_name):
    match = re.search(fr'final List<dynamic>\s+{array_name}\s*=\s*\[(.*?)\];', content, re.DOTALL)
    if not match:
        return []
    items = re.findall(r'PhosphorIcons\.([a-zA-Z]+Duotone)', match.group(1))
    return items

income_icons = extract_array('_incomeIcons')
expense_icons = extract_array('_expenseIcons')
dream_icons = extract_array('_dreamIcons')

all_icons = sorted(list(set(income_icons + expense_icons + dream_icons + ['starDuotone'])))

out = []
out.append("import 'package:flutter/material.dart';")
out.append("import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';\n")
out.append("class SharedIconSelector {\n")

out.append("  static const List<Color> colors = [")
out.append("    Color(0xFFE3F2FD),")
out.append("    Color(0xFFE8F5E9),")
out.append("    Color(0xFFFCE4EC),")
out.append("    Color(0xFFF3E5F5),")
out.append("    Color(0xFFFDF1D6),")
out.append("  ];\n")

# all_icons_map
out.append("  static const Map<String, PhosphorDuotoneIconData> _allIconsMap = {")
for icon in all_icons:
    out.append(f"    '{icon}': PhosphorIcons.{icon},")
out.append("  };\n")

# helper getIcon
out.append("""  static Widget buildIcon(String? rawData, {double size = 24, Color defaultColor = const Color(0xFFFDF1D6)}) {
    if (rawData == null || rawData.isEmpty) {
      return _buildContainer(PhosphorIcons.starDuotone, defaultColor, size);
    }
    
    // Format is iconName|colorHex
    final parts = rawData.split('|');
    String iconName = parts[0];
    Color bgColor = defaultColor;
    
    if (parts.length > 1) {
      final colorCode = int.tryParse(parts[1]);
      if (colorCode != null) {
        bgColor = Color(colorCode);
      }
    }

    final iconData = _allIconsMap[iconName] ?? PhosphorIcons.starDuotone;
    return _buildContainer(iconData, bgColor, size);
  }

  static Widget _buildContainer(PhosphorDuotoneIconData icon, Color bgColor, double size) {
    return Container(
      width: size + 16,
      height: size + 16,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade400, width: 1.5),
      ),
      child: Center(
        child: PhosphorIcon(
          icon,
          size: size,
          color: Colors.black87,
          duotoneSecondaryColor: Colors.white,
          duotoneSecondaryOpacity: 1.0,
        ),
      ),
    );
  }
""")

out.append("}")

with open('lib/core/widgets/shared_icon_selector.dart', 'w', encoding='utf-8') as f:
    f.write('\n'.join(out))
