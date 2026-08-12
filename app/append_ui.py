with open('lib/core/widgets/shared_icon_selector.dart', 'a', encoding='utf-8') as f:
    f.write("""
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
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'เลือกไอคอน',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
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
                    if (widget.onIconSelected != null) {
                      widget.onIconSelected!(iconName);
                    } else {
                      Navigator.pop(context, iconName);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFE6F4F1) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFFE2E8F0),
                        width: 1.5,
                      ),
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(
                            color: const Color(0xFF38BDF8).withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                      ],
                    ),
                    child: PhosphorIcon(
                      iconData,
                      size: 28,
                      color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF1E293B),
                      duotoneSecondaryOpacity: 1.0,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
""")
