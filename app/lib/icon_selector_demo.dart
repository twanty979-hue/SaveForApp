import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class IconSelectorDemo extends StatefulWidget {
  const IconSelectorDemo({super.key});

  @override
  State<IconSelectorDemo> createState() => _IconSelectorDemoState();
}

class _IconSelectorDemoState extends State<IconSelectorDemo> {
  var _selectedIcon = PhosphorIcons.walletDuotone;
  Color _selectedColor = Colors.blue.shade50;
  String _selectedCategory = 'Income'; 

  // 1. หมวดรายรับ (Income)
  final List<dynamic> _incomeIcons = [
    PhosphorIcons.moneyDuotone, PhosphorIcons.coinsDuotone, PhosphorIcons.walletDuotone, PhosphorIcons.piggyBankDuotone,
    PhosphorIcons.chartLineUpDuotone, PhosphorIcons.trendUpDuotone, PhosphorIcons.bankDuotone, PhosphorIcons.vaultDuotone,
    PhosphorIcons.currencyDollarDuotone, PhosphorIcons.currencyBtcDuotone, PhosphorIcons.currencyEthDuotone,
    PhosphorIcons.handCoinsDuotone, PhosphorIcons.handshakeDuotone, PhosphorIcons.briefcaseDuotone, PhosphorIcons.buildingsDuotone,
    PhosphorIcons.storefrontDuotone, PhosphorIcons.shoppingBagDuotone, PhosphorIcons.giftDuotone, PhosphorIcons.cashRegisterDuotone,
    PhosphorIcons.chartBarDuotone, PhosphorIcons.chartPieDuotone, PhosphorIcons.chartPolarDuotone, PhosphorIcons.presentationChartDuotone,
    PhosphorIcons.arrowCircleUpDuotone, PhosphorIcons.arrowUpDuotone, PhosphorIcons.arrowFatUpDuotone, PhosphorIcons.arrowFatLinesUpDuotone,
    PhosphorIcons.caretUpDuotone, PhosphorIcons.caretCircleUpDuotone, PhosphorIcons.caretDoubleUpDuotone, PhosphorIcons.checkCircleDuotone,
    PhosphorIcons.medalDuotone, PhosphorIcons.crownDuotone, PhosphorIcons.starDuotone, PhosphorIcons.thumbsUpDuotone,
    PhosphorIcons.rocketDuotone, PhosphorIcons.lightningDuotone, PhosphorIcons.speakerHifiDuotone, PhosphorIcons.laptopDuotone,
    PhosphorIcons.desktopDuotone, PhosphorIcons.deviceMobileDuotone, PhosphorIcons.booksDuotone, PhosphorIcons.studentDuotone,
  ];

  // 2. หมวดรายจ่าย (Expense)
  final List<dynamic> _expenseIcons = [
    PhosphorIcons.shoppingCartDuotone, PhosphorIcons.basketDuotone, PhosphorIcons.receiptDuotone, PhosphorIcons.creditCardDuotone,
    PhosphorIcons.chartLineDownDuotone, PhosphorIcons.trendDownDuotone, PhosphorIcons.arrowCircleDownDuotone, PhosphorIcons.arrowDownDuotone,
    PhosphorIcons.coffeeDuotone, PhosphorIcons.hamburgerDuotone, PhosphorIcons.pizzaDuotone, PhosphorIcons.bowlFoodDuotone,
    PhosphorIcons.martiniDuotone, PhosphorIcons.wineDuotone, PhosphorIcons.beerBottleDuotone, PhosphorIcons.cookieDuotone,
    PhosphorIcons.houseDuotone, PhosphorIcons.houseLineDuotone, PhosphorIcons.carDuotone, PhosphorIcons.carProfileDuotone,
    PhosphorIcons.taxiDuotone, PhosphorIcons.busDuotone, PhosphorIcons.trainDuotone, PhosphorIcons.mopedDuotone,
    PhosphorIcons.airplaneDuotone, PhosphorIcons.boatDuotone, PhosphorIcons.gasPumpDuotone, PhosphorIcons.chargingStationDuotone,
    PhosphorIcons.tShirtDuotone, PhosphorIcons.sneakerDuotone, PhosphorIcons.highHeelDuotone, PhosphorIcons.pantsDuotone,
    PhosphorIcons.gameControllerDuotone, PhosphorIcons.filmStripDuotone, PhosphorIcons.popcornDuotone, PhosphorIcons.ticketDuotone,
    PhosphorIcons.monitorPlayDuotone, PhosphorIcons.televisionDuotone, PhosphorIcons.firstAidDuotone, PhosphorIcons.pillDuotone,
    PhosphorIcons.syringeDuotone, PhosphorIcons.stethoscopeDuotone, PhosphorIcons.heartbeatDuotone, PhosphorIcons.babyDuotone,
    PhosphorIcons.pawPrintDuotone, PhosphorIcons.catDuotone, PhosphorIcons.dogDuotone, PhosphorIcons.boneDuotone,
  ];

  // 3. หมวดความฝัน (Dreams)
  final List<dynamic> _dreamIcons = [
    PhosphorIcons.houseDuotone, PhosphorIcons.buildingsDuotone, PhosphorIcons.castleTurretDuotone, PhosphorIcons.tentDuotone,
    PhosphorIcons.carDuotone, PhosphorIcons.jeepDuotone, PhosphorIcons.bicycleDuotone, PhosphorIcons.motorcycleDuotone,
    PhosphorIcons.airplaneTiltDuotone, PhosphorIcons.airplaneInFlightDuotone, PhosphorIcons.parachuteDuotone, PhosphorIcons.balloonDuotone,
    PhosphorIcons.mapTrifoldDuotone, PhosphorIcons.mapPinDuotone, PhosphorIcons.globeDuotone, PhosphorIcons.globeHemisphereWestDuotone,
    PhosphorIcons.mountainsDuotone, PhosphorIcons.wavesDuotone, PhosphorIcons.treeDuotone, PhosphorIcons.treePalmDuotone,
    PhosphorIcons.cameraDuotone, PhosphorIcons.videoCameraDuotone, PhosphorIcons.guitarDuotone, PhosphorIcons.pianoKeysDuotone,
    PhosphorIcons.paletteDuotone, PhosphorIcons.paintBrushDuotone, PhosphorIcons.bookOpenDuotone, PhosphorIcons.graduationCapDuotone,
    PhosphorIcons.trophyDuotone, PhosphorIcons.medalDuotone, PhosphorIcons.flagDuotone, PhosphorIcons.flagBannerDuotone,
    PhosphorIcons.diamondDuotone, PhosphorIcons.sketchLogoDuotone, PhosphorIcons.watchDuotone, PhosphorIcons.clockDuotone,
    PhosphorIcons.babyDuotone, PhosphorIcons.usersDuotone, PhosphorIcons.heartDuotone, PhosphorIcons.handsClappingDuotone,
    PhosphorIcons.sparkleDuotone, PhosphorIcons.magicWandDuotone, PhosphorIcons.rainbowDuotone, PhosphorIcons.cloudSunDuotone,
    PhosphorIcons.sunDuotone, PhosphorIcons.moonStarsDuotone, PhosphorIcons.planetDuotone, PhosphorIcons.alienDuotone,
  ];

  final List<Color> _colors = [
    const Color(0xFFE3F2FD), // ฟ้าพาสเทล (ปรับให้สีดูละมุนขึ้น)
    const Color(0xFFE8F5E9), // เขียวพาสเทล
    const Color(0xFFFCE4EC), // ชมพูพาสเทล
    const Color(0xFFF3E5F5), // ม่วงพาสเทล
    const Color(0xFFFDF1D6), // สีกระดาษ / ครีม
  ];

  @override
  Widget build(BuildContext context) {
    List<dynamic> currentIcons;
    if (_selectedCategory == 'Income') {
      currentIcons = _incomeIcons;
    } else if (_selectedCategory == 'Expense') {
      currentIcons = _expenseIcons;
    } else {
      currentIcons = _dreamIcons;
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(title: const Text('เลือกไอคอน')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: _selectedColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.grey.shade400, // ปรับให้เข้มขึ้นจาก 300 เป็น 400
                    width: 1.5, // เพิ่มความหนาขอบนิดนึงจะได้ไม่ดูจางไป
                  ),
                ),
                child: Center(
                  // ใช้ PhosphorIcon แทน Icon และกำหนดสี Duotone
                  child: PhosphorIcon(
                    _selectedIcon,
                    size: 60,
                    color: Colors.black87,
                    duotoneSecondaryColor: Colors.white,
                    duotoneSecondaryOpacity: 1.0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCategoryTab('Income', 'รายรับ'),
                _buildCategoryTab('Expense', 'รายจ่าย'),
                _buildCategoryTab('Dream', 'ความฝัน'),
              ],
            ),
            const SizedBox(height: 16),
            
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: currentIcons.map((icon) {
                final isSelected = _selectedIcon == icon;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedIcon = icon;
                    });
                  },
                  child: Container(
                    width: 55,
                    height: 55,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue.shade50 : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: PhosphorIcon(
                      icon,
                      size: 28,
                      color: isSelected ? Colors.blue : Colors.black87,
                      duotoneSecondaryColor: isSelected ? Colors.white : Colors.grey.shade300,
                      duotoneSecondaryOpacity: 1.0,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 16),

            const Text(
              'สีพื้นหลัง',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              children: _colors.map((color) {
                final isSelected = _selectedColor == color;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = color;
                    });
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.black : Colors.grey.shade300,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTab(String categoryValue, String title) {
    final isSelected = _selectedCategory == categoryValue;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedCategory = categoryValue;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
