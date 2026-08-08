import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:app/core/theme/app_theme.dart';

class SharedIconSelector {

  static const List<Color> colors = [
    Color(0xFFE3F2FD),
    Color(0xFFE8F5E9),
    Color(0xFFFCE4EC),
    Color(0xFFF3E5F5),
    Color(0xFFFDF1D6),
  ];

  static const Map<String, PhosphorDuotoneIconData> _allIconsMap = {
    'airplaneDuotone': PhosphorIcons.airplaneDuotone,
    'airplaneInFlightDuotone': PhosphorIcons.airplaneInFlightDuotone,
    'airplaneTiltDuotone': PhosphorIcons.airplaneTiltDuotone,
    'alienDuotone': PhosphorIcons.alienDuotone,
    'arrowCircleDownDuotone': PhosphorIcons.arrowCircleDownDuotone,
    'arrowCircleUpDuotone': PhosphorIcons.arrowCircleUpDuotone,
    'arrowDownDuotone': PhosphorIcons.arrowDownDuotone,
    'arrowFatLinesUpDuotone': PhosphorIcons.arrowFatLinesUpDuotone,
    'arrowFatUpDuotone': PhosphorIcons.arrowFatUpDuotone,
    'arrowUpDuotone': PhosphorIcons.arrowUpDuotone,
    'babyDuotone': PhosphorIcons.babyDuotone,
    'balloonDuotone': PhosphorIcons.balloonDuotone,
    'bankDuotone': PhosphorIcons.bankDuotone,
    'basketDuotone': PhosphorIcons.basketDuotone,
    'beerBottleDuotone': PhosphorIcons.beerBottleDuotone,
    'bicycleDuotone': PhosphorIcons.bicycleDuotone,
    'boatDuotone': PhosphorIcons.boatDuotone,
    'boneDuotone': PhosphorIcons.boneDuotone,
    'bookOpenDuotone': PhosphorIcons.bookOpenDuotone,
    'booksDuotone': PhosphorIcons.booksDuotone,
    'bowlFoodDuotone': PhosphorIcons.bowlFoodDuotone,
    'briefcaseDuotone': PhosphorIcons.briefcaseDuotone,
    'buildingsDuotone': PhosphorIcons.buildingsDuotone,
    'busDuotone': PhosphorIcons.busDuotone,
    'cameraDuotone': PhosphorIcons.cameraDuotone,
    'carDuotone': PhosphorIcons.carDuotone,
    'carProfileDuotone': PhosphorIcons.carProfileDuotone,
    'caretCircleUpDuotone': PhosphorIcons.caretCircleUpDuotone,
    'caretDoubleUpDuotone': PhosphorIcons.caretDoubleUpDuotone,
    'caretUpDuotone': PhosphorIcons.caretUpDuotone,
    'cashRegisterDuotone': PhosphorIcons.cashRegisterDuotone,
    'castleTurretDuotone': PhosphorIcons.castleTurretDuotone,
    'catDuotone': PhosphorIcons.catDuotone,
    'chargingStationDuotone': PhosphorIcons.chargingStationDuotone,
    'chartBarDuotone': PhosphorIcons.chartBarDuotone,
    'chartLineDownDuotone': PhosphorIcons.chartLineDownDuotone,
    'chartLineUpDuotone': PhosphorIcons.chartLineUpDuotone,
    'chartPieDuotone': PhosphorIcons.chartPieDuotone,
    'chartPolarDuotone': PhosphorIcons.chartPolarDuotone,
    'checkCircleDuotone': PhosphorIcons.checkCircleDuotone,
    'clockDuotone': PhosphorIcons.clockDuotone,
    'cloudSunDuotone': PhosphorIcons.cloudSunDuotone,
    'coffeeDuotone': PhosphorIcons.coffeeDuotone,
    'coinsDuotone': PhosphorIcons.coinsDuotone,
    'cookieDuotone': PhosphorIcons.cookieDuotone,
    'creditCardDuotone': PhosphorIcons.creditCardDuotone,
    'crownDuotone': PhosphorIcons.crownDuotone,
    'currencyBtcDuotone': PhosphorIcons.currencyBtcDuotone,
    'currencyDollarDuotone': PhosphorIcons.currencyDollarDuotone,
    'currencyEthDuotone': PhosphorIcons.currencyEthDuotone,
    'desktopDuotone': PhosphorIcons.desktopDuotone,
    'deviceMobileDuotone': PhosphorIcons.deviceMobileDuotone,
    'diamondDuotone': PhosphorIcons.diamondDuotone,
    'dogDuotone': PhosphorIcons.dogDuotone,
    'filmStripDuotone': PhosphorIcons.filmStripDuotone,
    'firstAidDuotone': PhosphorIcons.firstAidDuotone,
    'flagBannerDuotone': PhosphorIcons.flagBannerDuotone,
    'flagDuotone': PhosphorIcons.flagDuotone,
    'gameControllerDuotone': PhosphorIcons.gameControllerDuotone,
    'gasPumpDuotone': PhosphorIcons.gasPumpDuotone,
    'giftDuotone': PhosphorIcons.giftDuotone,
    'globeDuotone': PhosphorIcons.globeDuotone,
    'globeHemisphereWestDuotone': PhosphorIcons.globeHemisphereWestDuotone,
    'graduationCapDuotone': PhosphorIcons.graduationCapDuotone,
    'guitarDuotone': PhosphorIcons.guitarDuotone,
    'hamburgerDuotone': PhosphorIcons.hamburgerDuotone,
    'handCoinsDuotone': PhosphorIcons.handCoinsDuotone,
    'handsClappingDuotone': PhosphorIcons.handsClappingDuotone,
    'handshakeDuotone': PhosphorIcons.handshakeDuotone,
    'heartDuotone': PhosphorIcons.heartDuotone,
    'heartbeatDuotone': PhosphorIcons.heartbeatDuotone,
    'highHeelDuotone': PhosphorIcons.highHeelDuotone,
    'houseDuotone': PhosphorIcons.houseDuotone,
    'houseLineDuotone': PhosphorIcons.houseLineDuotone,
    'jeepDuotone': PhosphorIcons.jeepDuotone,
    'laptopDuotone': PhosphorIcons.laptopDuotone,
    'lightningDuotone': PhosphorIcons.lightningDuotone,
    'magicWandDuotone': PhosphorIcons.magicWandDuotone,
    'mapPinDuotone': PhosphorIcons.mapPinDuotone,
    'mapTrifoldDuotone': PhosphorIcons.mapTrifoldDuotone,
    'martiniDuotone': PhosphorIcons.martiniDuotone,
    'medalDuotone': PhosphorIcons.medalDuotone,
    'moneyDuotone': PhosphorIcons.moneyDuotone,
    'monitorPlayDuotone': PhosphorIcons.monitorPlayDuotone,
    'moonStarsDuotone': PhosphorIcons.moonStarsDuotone,
    'mopedDuotone': PhosphorIcons.mopedDuotone,
    'motorcycleDuotone': PhosphorIcons.motorcycleDuotone,
    'mountainsDuotone': PhosphorIcons.mountainsDuotone,
    'paintBrushDuotone': PhosphorIcons.paintBrushDuotone,
    'paletteDuotone': PhosphorIcons.paletteDuotone,
    'pantsDuotone': PhosphorIcons.pantsDuotone,
    'parachuteDuotone': PhosphorIcons.parachuteDuotone,
    'pawPrintDuotone': PhosphorIcons.pawPrintDuotone,
    'pianoKeysDuotone': PhosphorIcons.pianoKeysDuotone,
    'piggyBankDuotone': PhosphorIcons.piggyBankDuotone,
    'pillDuotone': PhosphorIcons.pillDuotone,
    'pizzaDuotone': PhosphorIcons.pizzaDuotone,
    'planetDuotone': PhosphorIcons.planetDuotone,
    'popcornDuotone': PhosphorIcons.popcornDuotone,
    'presentationChartDuotone': PhosphorIcons.presentationChartDuotone,
    'rainbowDuotone': PhosphorIcons.rainbowDuotone,
    'receiptDuotone': PhosphorIcons.receiptDuotone,
    'rocketDuotone': PhosphorIcons.rocketDuotone,
    'shoppingBagDuotone': PhosphorIcons.shoppingBagDuotone,
    'shoppingCartDuotone': PhosphorIcons.shoppingCartDuotone,
    'sketchLogoDuotone': PhosphorIcons.sketchLogoDuotone,
    'sneakerDuotone': PhosphorIcons.sneakerDuotone,
    'sparkleDuotone': PhosphorIcons.sparkleDuotone,
    'speakerHifiDuotone': PhosphorIcons.speakerHifiDuotone,
    'starDuotone': PhosphorIcons.starDuotone,
    'stethoscopeDuotone': PhosphorIcons.stethoscopeDuotone,
    'storefrontDuotone': PhosphorIcons.storefrontDuotone,
    'studentDuotone': PhosphorIcons.studentDuotone,
    'sunDuotone': PhosphorIcons.sunDuotone,
    'syringeDuotone': PhosphorIcons.syringeDuotone,
    'tShirtDuotone': PhosphorIcons.tShirtDuotone,
    'taxiDuotone': PhosphorIcons.taxiDuotone,
    'televisionDuotone': PhosphorIcons.televisionDuotone,
    'tentDuotone': PhosphorIcons.tentDuotone,
    'thumbsUpDuotone': PhosphorIcons.thumbsUpDuotone,
    'ticketDuotone': PhosphorIcons.ticketDuotone,
    'trainDuotone': PhosphorIcons.trainDuotone,
    'treeDuotone': PhosphorIcons.treeDuotone,
    'treePalmDuotone': PhosphorIcons.treePalmDuotone,
    'trendDownDuotone': PhosphorIcons.trendDownDuotone,
    'trendUpDuotone': PhosphorIcons.trendUpDuotone,
    'trophyDuotone': PhosphorIcons.trophyDuotone,
    'usersDuotone': PhosphorIcons.usersDuotone,
    'vaultDuotone': PhosphorIcons.vaultDuotone,
    'videoCameraDuotone': PhosphorIcons.videoCameraDuotone,
    'walletDuotone': PhosphorIcons.walletDuotone,
    'watchDuotone': PhosphorIcons.watchDuotone,
    'wavesDuotone': PhosphorIcons.wavesDuotone,
    'wineDuotone': PhosphorIcons.wineDuotone,
  };

  static Widget buildIcon(String? rawData, {double size = 24, Color defaultColor = const Color(0xFF64748B)}) {
    if (rawData == null || rawData.isEmpty) {
      return PhosphorIcon(PhosphorIcons.starDuotone, size: size, color: defaultColor);
    }
    
    // Format is iconName
    final parts = rawData.split('|');
    String iconName = parts[0];
    
    final iconData = _allIconsMap[iconName] ?? PhosphorIcons.starDuotone;
    return _buildContainer(iconData, size, defaultColor);
  }

  static Widget _buildContainer(PhosphorDuotoneIconData icon, double size, Color iconColor) {
    return Container(
      width: size + 16,
      height: size + 16,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC), // Soft slate background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1), // Faint border
      ),
      child: Center(
        child: PhosphorIcon(
          icon,
          size: size,
          color: iconColor,
        ),
      ),
    );
  }

  static PhosphorDuotoneIconData getIconData(String? iconName) {
    if (iconName == null || iconName.isEmpty) return PhosphorIcons.starDuotone;
    return _allIconsMap[iconName] ?? PhosphorIcons.starDuotone;
  }
}

class SharedIconPickerWidget extends StatefulWidget {
  final String? initialIconRawData;
  final void Function(String)? onIconSelected;

  const SharedIconPickerWidget({
    super.key, 
    this.initialIconRawData,
    this.onIconSelected,
  });

  @override
  State<SharedIconPickerWidget> createState() => _SharedIconPickerWidgetState();
}

class _SharedIconPickerWidgetState extends State<SharedIconPickerWidget> {
  String _selectedIconName = 'starDuotone';

  final List<String> _incomeIcons = [
    'starDuotone', 'moneyDuotone', 'coinsDuotone', 'walletDuotone', 'piggyBankDuotone',
    'chartLineUpDuotone', 'trendUpDuotone', 'bankDuotone', 'vaultDuotone',
    'handCoinsDuotone', 'handshakeDuotone', 'briefcaseDuotone', 'buildingsDuotone',
    'storefrontDuotone', 'shoppingBagDuotone', 'giftDuotone', 'cashRegisterDuotone',
    'chartBarDuotone', 'chartPieDuotone', 'chartPolarDuotone', 'presentationChartDuotone',
    'arrowCircleUpDuotone', 'arrowUpDuotone', 'arrowFatUpDuotone', 'arrowFatLinesUpDuotone',
    'caretUpDuotone', 'caretCircleUpDuotone', 'caretDoubleUpDuotone', 'checkCircleDuotone',
    'medalDuotone', 'crownDuotone', 'starDuotone', 'thumbsUpDuotone',
    'rocketDuotone', 'lightningDuotone', 'speakerHifiDuotone', 'laptopDuotone',
    'desktopDuotone', 'deviceMobileDuotone', 'booksDuotone', 'studentDuotone',
  ];

  final List<String> _expenseIcons = [
    'starDuotone', 'shoppingCartDuotone', 'basketDuotone', 'receiptDuotone', 'creditCardDuotone',
    'chartLineDownDuotone', 'trendDownDuotone', 'arrowCircleDownDuotone', 'arrowDownDuotone',
    'coffeeDuotone', 'hamburgerDuotone', 'pizzaDuotone', 'bowlFoodDuotone',
    'martiniDuotone', 'wineDuotone', 'beerBottleDuotone', 'cookieDuotone',
    'houseDuotone', 'houseLineDuotone', 'carDuotone', 'carProfileDuotone',
    'taxiDuotone', 'busDuotone', 'trainDuotone', 'mopedDuotone',
    'airplaneDuotone', 'boatDuotone', 'gasPumpDuotone', 'chargingStationDuotone',
    'tShirtDuotone', 'sneakerDuotone', 'highHeelDuotone', 'pantsDuotone',
    'gameControllerDuotone', 'filmStripDuotone', 'popcornDuotone', 'ticketDuotone',
    'monitorPlayDuotone', 'televisionDuotone', 'firstAidDuotone', 'pillDuotone',
    'syringeDuotone', 'stethoscopeDuotone', 'heartbeatDuotone', 'babyDuotone',
    'pawPrintDuotone', 'catDuotone', 'dogDuotone', 'boneDuotone',
  ];

  final List<String> _dreamIcons = [
    'starDuotone', 'houseDuotone', 'buildingsDuotone', 'castleTurretDuotone', 'tentDuotone',
    'carDuotone', 'jeepDuotone', 'bicycleDuotone', 'motorcycleDuotone',
    'airplaneTiltDuotone', 'airplaneInFlightDuotone', 'parachuteDuotone', 'balloonDuotone',
    'mapTrifoldDuotone', 'mapPinDuotone', 'globeDuotone', 'globeHemisphereWestDuotone',
    'mountainsDuotone', 'wavesDuotone', 'treeDuotone', 'treePalmDuotone',
    'cameraDuotone', 'videoCameraDuotone', 'guitarDuotone', 'pianoKeysDuotone',
    'paletteDuotone', 'paintBrushDuotone', 'bookOpenDuotone', 'graduationCapDuotone',
    'trophyDuotone', 'medalDuotone', 'flagDuotone', 'flagBannerDuotone',
    'diamondDuotone', 'sketchLogoDuotone', 'watchDuotone', 'clockDuotone',
    'babyDuotone', 'usersDuotone', 'heartDuotone', 'handsClappingDuotone',
    'sparkleDuotone', 'magicWandDuotone', 'rainbowDuotone', 'cloudSunDuotone',
    'sunDuotone', 'moonStarsDuotone', 'planetDuotone', 'alienDuotone',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialIconRawData != null && widget.initialIconRawData!.isNotEmpty) {
      _selectedIconName = widget.initialIconRawData!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final allIcons = {..._incomeIcons, ..._expenseIcons, ..._dreamIcons}.toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 20, 16),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context, null),
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF64748B)),
                  splashRadius: 24,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
                const Text(
                  'เลือกไอคอน',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context, null),
                  icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                  splashRadius: 24,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: allIcons.length,
              itemBuilder: (context, index) {
                final iconName = allIcons[index];
                final isSelected = _selectedIconName == iconName;
                final iconData = SharedIconSelector.getIconData(iconName);
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedIconName = iconName;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.secondaryColor : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppTheme.primaryColor : const Color(0xFFE2E8F0),
                        width: 1.5,
                      ),
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                      ],
                    ),
                    child: PhosphorIcon(
                      iconData,
                      size: 28,
                      color: isSelected ? AppTheme.primaryColor : const Color(0xFF1E293B),
                    ),
                  ),
                );
              },
            ),
          ),

          // Next Button at bottom
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Color(0xFFF1F5F9), width: 1),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pop(context, _selectedIconName);
                  },
                  child: const Text(
                    'ถัดไป',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
