import 'package:flutter/material.dart';
import '../services/slip_parser_service.dart';

/// วิดเจ็ตไอคอน/โลโก้ของแต่ละธนาคารในไทย ออกแบบให้คมชัด สวยงาม และตรงตามอัตลักษณ์แบรนด์
class BankLogoIcon extends StatelessWidget {
  final BankType bank;
  final double size;
  final bool isCircle;
  final bool showShadow;
  final bool showBorder;

  const BankLogoIcon({
    super.key,
    required this.bank,
    this.size = 36,
    this.isCircle = false,
    this.showShadow = true,
    this.showBorder = true,
  });

  static String? getAssetPath(BankType bank) {
    switch (bank) {
      case BankType.kbank:
        return 'assets/images/banks/kbank.png';
      case BankType.scb:
        return 'assets/images/banks/scb.png';
      case BankType.krungsri:
        return 'assets/images/banks/bay.png';
      case BankType.truemoney:
        return 'assets/images/banks/truemoney.png';
      case BankType.ktb:
        return 'assets/images/banks/ktb.png';
      case BankType.bbl:
        return 'assets/images/banks/bbl.png';
      case BankType.ttb:
        return 'assets/images/banks/ttb.png';
      case BankType.gsb:
        return 'assets/images/banks/gsb.png';
      case BankType.other:
        return 'assets/images/banks/promptpay.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final assetPath = getAssetPath(bank);
    final borderRadius = isCircle
        ? BorderRadius.circular(size / 2)
        : BorderRadius.circular(size * 0.24);

    if (assetPath != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: showShadow
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: size * 0.25,
                    offset: Offset(0, size * 0.08),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Image.asset(
            assetPath,
            width: size,
            height: size,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            errorBuilder: (context, error, stackTrace) => _buildFallbackContainer(context),
          ),
        ),
      );
    }

    return _buildFallbackContainer(context);
  }

  Widget _buildFallbackContainer(BuildContext context) {
    final colors = _getGradientColors(bank);
    final borderRadius = isCircle
        ? BorderRadius.circular(size / 2)
        : BorderRadius.circular(size * 0.28);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: borderRadius,
        border: showBorder
            ? Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: size > 32 ? 1.2 : 0.8,
              )
            : null,
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: colors.first.withValues(alpha: 0.35),
                  blurRadius: size * 0.3,
                  offset: Offset(0, size * 0.1),
                ),
              ]
            : null,
      ),
      child: Center(
        child: _buildBankSymbol(bank, size),
      ),
    );
  }

  static List<Color> _getGradientColors(BankType bank) {
    switch (bank) {
      case BankType.kbank:
        return [const Color(0xFF00A950), const Color(0xFF007A3A)];
      case BankType.scb:
        return [const Color(0xFF4E2A84), const Color(0xFF33165E)];
      case BankType.krungsri:
        return [const Color(0xFFFED100), const Color(0xFFE5B20D)];
      case BankType.ktb:
        return [const Color(0xFF00AEEF), const Color(0xFF0086BD)];
      case BankType.bbl:
        return [const Color(0xFF1E3A8A), const Color(0xFF0D1E4D)];
      case BankType.ttb:
        return [const Color(0xFF002D62), const Color(0xFF001938)];
      case BankType.gsb:
        return [const Color(0xFFEB1985), const Color(0xFFB50A61)];
      case BankType.truemoney:
        return [const Color(0xFFFF6A00), const Color(0xFFFF3D00)];
      case BankType.other:
        return [const Color(0xFF003B6F), const Color(0xFF00A88F)];
    }
  }

  Widget _buildBankSymbol(BankType bank, double size) {
    final scale = size / 36.0;

    switch (bank) {
      case BankType.kbank:
        return Stack(
          alignment: Alignment.center,
          children: [
            Text(
              'K+',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15 * scale,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                height: 1.0,
              ),
            ),
          ],
        );

      case BankType.scb:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.diamond_rounded,
              color: const Color(0xFFFED100),
              size: 13 * scale,
            ),
            Text(
              'SCB',
              style: TextStyle(
                color: Colors.white,
                fontSize: 8.5 * scale,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
                height: 1.0,
              ),
            ),
          ],
        );

      case BankType.krungsri:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_balance_rounded,
              color: const Color(0xFF3E2F00),
              size: 13 * scale,
            ),
            Text(
              'BAY',
              style: TextStyle(
                color: const Color(0xFF3E2F00),
                fontSize: 8.5 * scale,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
                height: 1.0,
              ),
            ),
          ],
        );

      case BankType.ktb:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.flight_takeoff_rounded,
              color: Colors.white,
              size: 13 * scale,
            ),
            Text(
              'KTB',
              style: TextStyle(
                color: Colors.white,
                fontSize: 8.5 * scale,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
                height: 1.0,
              ),
            ),
          ],
        );

      case BankType.bbl:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.change_history_rounded,
              color: const Color(0xFFF37021),
              size: 13 * scale,
            ),
            Text(
              'BBL',
              style: TextStyle(
                color: Colors.white,
                fontSize: 8.5 * scale,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
                height: 1.0,
              ),
            ),
          ],
        );

      case BankType.ttb:
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'ttb',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.5 * scale,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
                height: 1.0,
              ),
            ),
            Container(
              margin: EdgeInsets.only(left: 1.5 * scale, top: 4 * scale),
              width: 3.5 * scale,
              height: 3.5 * scale,
              decoration: const BoxDecoration(
                color: Color(0xFFF37021),
                shape: BoxShape.circle,
              ),
            ),
          ],
        );

      case BankType.gsb:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.savings_rounded,
              color: Colors.white,
              size: 13 * scale,
            ),
            Text(
              'GSB',
              style: TextStyle(
                color: Colors.white,
                fontSize: 8.5 * scale,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
                height: 1.0,
              ),
            ),
          ],
        );

      case BankType.truemoney:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_balance_wallet_rounded,
              color: Colors.white,
              size: 13 * scale,
            ),
            Text(
              'TRUE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 7.5 * scale,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
                height: 1.0,
              ),
            ),
          ],
        );

      case BankType.other:
        return Icon(
          Icons.account_balance_rounded,
          color: Colors.white,
          size: 18 * scale,
        );
    }
  }
}

/// วิดเจ็ตแสดงไอคอนธนาคารคู่ (ต้นทาง ➔ ปลายทาง) สำหรับรายการย้ายเงินระหว่างบัญชี
class DualBankLogoIcon extends StatelessWidget {
  final BankType fromBank;
  final BankType toBank;
  final double size;
  final bool showShadow;
  final Color? arrowColor;

  const DualBankLogoIcon({
    super.key,
    required this.fromBank,
    required this.toBank,
    this.size = 36,
    this.showShadow = true,
    this.arrowColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveArrowColor = arrowColor ??
        (Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF94A3B8)
            : const Color(0xFF64748B));

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        BankLogoIcon(
          bank: fromBank,
          size: size,
          showShadow: showShadow,
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: size * 0.15),
          child: Container(
            padding: EdgeInsets.all(size * 0.1),
            decoration: BoxDecoration(
              color: effectiveArrowColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: (size * 0.38).clamp(10.0, 20.0),
              color: effectiveArrowColor,
            ),
          ),
        ),
        BankLogoIcon(
          bank: toBank,
          size: size,
          showShadow: showShadow,
        ),
      ],
    );
  }
}

