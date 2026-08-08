import 'package:flutter/material.dart' as material;

import '../settings/app_settings.dart';

/// Drop-in text widget that keeps legacy screens in sync with the app locale.
/// User-entered text that is not in the UI phrase table is left unchanged.
class Text extends material.StatelessWidget {
  const Text(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.semanticsIdentifier,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : textSpan = null;

  const Text.rich(
    this.textSpan, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.semanticsIdentifier,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : data = null;

  final String? data;
  final material.InlineSpan? textSpan;
  final material.TextStyle? style;
  final material.StrutStyle? strutStyle;
  final material.TextAlign? textAlign;
  final material.TextDirection? textDirection;
  final material.Locale? locale;
  final bool? softWrap;
  final material.TextOverflow? overflow;
  final material.TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final String? semanticsIdentifier;
  final material.TextWidthBasis? textWidthBasis;
  final material.TextHeightBehavior? textHeightBehavior;
  final material.Color? selectionColor;

  @override
  material.Widget build(material.BuildContext context) {
    final effectiveStyle = _adaptiveStyle(context, style);
    if (textSpan != null) {
      return material.Text.rich(
        _localizedSpan(textSpan!),
        style: effectiveStyle,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
        semanticsIdentifier: semanticsIdentifier,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      );
    }
    return material.Text(
      _localized(data ?? ''),
      style: effectiveStyle,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel == null
          ? null
          : _localized(semanticsLabel!),
      semanticsIdentifier: semanticsIdentifier,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }
}

material.InlineSpan _localizedSpan(material.InlineSpan span) {
  if (span is! material.TextSpan) return span;
  return material.TextSpan(
    text: span.text == null ? null : _localized(span.text!),
    children: span.children?.map(_localizedSpan).toList(growable: false),
    style: span.style,
    recognizer: span.recognizer,
    mouseCursor: span.mouseCursor,
    onEnter: span.onEnter,
    onExit: span.onExit,
    semanticsLabel: span.semanticsLabel == null
        ? null
        : _localized(span.semanticsLabel!),
    semanticsIdentifier: span.semanticsIdentifier,
    locale: span.locale,
    spellOut: span.spellOut,
  );
}

material.TextStyle? _adaptiveStyle(
  material.BuildContext context,
  material.TextStyle? style,
) {
  if (style?.color == null ||
      material.Theme.of(context).brightness != material.Brightness.dark) {
    return style;
  }
  final value = style!.color!.toARGB32();
  const primaryDarkText = {0xFF0F172A, 0xFF111827, 0xFF1E293B, 0xFF334155};
  const secondaryDarkText = {0xFF475569, 0xFF64748B, 0xFF6B7280, 0xFF94A3B8};
  final scheme = material.Theme.of(context).colorScheme;
  if (primaryDarkText.contains(value)) {
    return style.copyWith(color: scheme.onSurface);
  }
  if (secondaryDarkText.contains(value)) {
    return style.copyWith(color: scheme.onSurfaceVariant);
  }
  return style;
}

String _localized(String source) {
  if (AppSettings.locale.value.languageCode != 'en' || source.isEmpty) {
    return source;
  }
  final exact = _thaiToEnglish[source];
  if (exact != null) return exact;
  var result = source;
  for (final entry in _dynamicThaiToEnglish.entries) {
    result = result.replaceAll(entry.key, entry.value);
  }
  return result;
}

const Map<String, String> _dynamicThaiToEnglish = {
  'ระบุจำนวนเงินเป้าหมายเพื่อคำนวณเวลา': 'Enter target amount to estimate timeframe',
  'เป้าหมายสำเร็จแล้ว! เงินเริ่มต้นถึงเป้าหมายแล้ว 🎉': 'Goal achieved! Starting balance meets target 🎉',
  'ระบุยอดเงินที่ต้องการเก็บต่อเดือน': 'Enter monthly savings to calculate timeframe',
  'คุณจะบรรลุเป้าหมายนี้ได้ในอีกประมาณ ': 'You will achieve this goal in about ',
  ' เดือน 🚀': ' months 🚀',
  'วันนี้ ฿': 'Today ฿',
  'เดือนนี้ ฿': 'This month ฿',
  'รายการเดือน': 'Entries for ',
  'รายการล่าสุด': 'Recent entries',
  ' รายการ': ' entries',
  'ครบวันที่ ': 'Due on ',
  'จำนวนเงิน (บาท)': 'Amount (THB)',
  'จำนวนเงินออมครั้งนี้ (บาท)': 'Savings amount (THB)',
  'ภาพรวมเดือนนี้': 'This month overview',
  'ภาพรวมเดือนก่อน': 'Previous month overview',
  'ภาพรวม 30 วัน': '30-day overview',
  'ภาพรวมทั้งหมด': 'All-time overview',
  'หยอดกระปุก: ': 'Save toward: ',
  'รวม ฿': 'Total ฿',
  'เป้าหมาย ฿': 'Target ฿',
  'เป้าหมาย: เก็บเดือนละ ฿': 'Target: save ฿',
  'คงเหลือ ฿': 'Balance ฿',
  'หยอดแล้ว ': 'Saved ',
  ' ครั้ง': ' times',
  'จากเป้าหมายตามแผนทั้งหมด ฿': 'of planned total ฿',
  'รายรับ (': 'Income (',
  'รายจ่าย (': 'Expenses (',
  '% สำเร็จแล้ว': '% complete',
};

// Long phrases are intentionally listed before their component words.
const Map<String, String> _thaiToEnglish = {
  'สวัสดีครับ ผมผู้ช่วยการเงินของคุณ พิมพ์รายการพร้อมจำนวนเงินได้เลย เช่น “ค่าห้อง 3500” หรือกดรายการด้านล่างเพื่อเติมชื่อให้อัตโนมัติ':
      'Hi, I’m your finance assistant. Type an item and amount, such as “Rent 3500”, or tap a shortcut below.',
  'บันทึกเงินออมเรียบร้อยแล้วครับ ความฝันเข้าใกล้อีกก้าวแล้วนะครับ':
      'Savings recorded. You are one step closer to your dream.',
  'ขออภัยครับ ฉันไม่เข้าใจรูปแบบของคุณ ลองป้อนใหม่ เช่น "ข้าวผัด 60" หรือ "+เงินเดือน 20000" นะครับ':
      'Sorry, I could not understand that. Try “Lunch 60” or “+Salary 20000”.',
  'เข้าสู่ระบบเพื่อใช้งานระบบบนคลาวด์': 'Sign in to use cloud sync',
  'สมัครสมาชิกเพื่อเริ่มบันทึกข้อมูลบนคลาวด์':
      'Create an account to start cloud syncing',
  'ยังไม่มีบัญชี? สมัครสมาชิกที่นี่': 'No account yet? Sign up here',
  'มีบัญชีอยู่แล้ว? เข้าสู่ระบบที่นี่': 'Already have an account? Sign in here',
  'โปรไฟล์และการตั้งค่า': 'Profile & settings',
  'ความช่วยเหลือและการสนับสนุน': 'Help & support',
  'ข้อมูลและความปลอดภัยของบัญชี': 'Account data and security',
  'ชื่อที่แสดงและข้อมูลเข้าสู่ระบบ': 'Display name and sign-in information',
  'รายการที่ตั้งไว้': 'Plans',
  'แดชบอร์ดการเงิน': 'Financial dashboard',
  'ภาพรวมที่ช่วยให้ตัดสินใจง่ายขึ้น': 'A clearer view for better decisions',
  'ภาพรวมเดือนก่อน': 'Previous month overview',
  'ภาพรวมเดือนนี้': 'This month overview',
  'ภาพรวม 30 วัน': '30-day overview',
  'ภาพรวมทั้งหมด': 'All-time overview',
  'ยังไม่มีรายการในช่วงนี้': 'No entries in this period',
  'วันนี้ยังไม่ได้จดรายการ': 'No entries recorded today',
  'แตะวันที่เพื่อดูสิ่งที่จดไว้': 'Tap a date to view its entries',
  'ยังไม่มีรายการแผนรายจ่ายประจำของคุณ': 'No recurring expense plans yet',
  'ยังไม่มีรายการแผนรายรับประจำของคุณ': 'No recurring income plans yet',
  'พิมพ์รายการและจำนวนเงิน…': 'Type an item and amount…',
  'กำลังบันทึกข้อมูล . . .': 'Saving…',
  'บันทึกรายรับเรียบร้อยแล้วครับ': 'Income recorded.',
  'บันทึกรายจ่ายเรียบร้อยแล้วครับ': 'Expense recorded.',
  'ยืนยันรหัสผ่านใหม่': 'Confirm new password',
  'เปลี่ยนรหัสผ่าน': 'Change password',
  'รหัสผ่านเดิม': 'Current password',
  'รหัสผ่านใหม่': 'New password',
  'อย่างน้อย 8 ตัวอักษร': 'At least 8 characters',
  'ตั้งค่าบัญชี': 'Account settings',
  'ความเป็นส่วนตัว': 'Privacy',
  'การแจ้งเตือน': 'Notifications',
  'เตือนรายการและเป้าหมายที่กำหนดไว้': 'Scheduled item and goal reminders',
  'คำถามที่พบบ่อยและการติดต่อ': 'FAQ and contact',
  'ออกจากระบบ': 'Sign out',
  'สมัครสมาชิก': 'Sign up',
  'เข้าสู่ระบบ': 'Sign in',
  'กรุณากรอกอีเมลและรหัสผ่าน': 'Please enter your email and password.',
  'ไม่สามารถประมวลผลข้อมูลโปรไฟล์ได้': 'Unable to process your profile.',
  'เกิดข้อผิดพลาดจากหลังบ้าน': 'A server error occurred.',
  'ไม่สามารถติดต่อเซิร์ฟเวอร์หลังบ้านได้': 'Unable to reach the server.',
  'รหัสผ่าน': 'Password',
  'อีเมล': 'Email',
  'ยืนยันการลบ': 'Confirm deletion',
  'ยืนยันลบ': 'Delete',
  'คุณแน่ใจหรือไม่ว่าต้องการลบเป้าหมายความฝันนี้? ข้อมูลเงินออมทั้งหมดในเป้าหมายนี้จะหายไปอย่างถาวร':
      'Delete this dream goal? All savings in this goal will be permanently removed.',
  'คุณแน่ใจหรือไม่ว่าต้องการลบรายการรายจ่ายประจำนี้? ข้อมูลนี้จะหายไปอย่างถาวร':
      'Delete this recurring expense? This information will be permanently removed.',
  'คุณแน่ใจหรือไม่ว่าต้องการลบรายการรายรับประจำนี้? ข้อมูลนี้จะหายไปอย่างถาวร':
      'Delete this recurring income? This information will be permanently removed.',
  'แก้ไข': 'Edit',
  'ลบ': 'Delete',
  'ลบข้อมูล': 'Delete',
  'ยกเลิก': 'Cancel',
  'ย้อนกลับ': 'Back',
  'บันทึกการแก้ไข': 'Save changes',
  'แก้ไขรายละเอียดเป้าหมาย': 'Edit goal details',
  'แก้ไขหมวดหมู่เป้าหมาย': 'Edit goal category',
  'เลือกหมวดหมู่เป้าหมาย': 'Choose goal category',
  'กรอกรายละเอียดเป้าหมาย': 'Enter goal details',
  'สร้างเป้าหมาย': 'Create goal',
  'หยอดกระปุก': 'Add savings',
  'ยืนยันหยอดกระปุก': 'Add savings',
  'ชื่อเป้าหมาย': 'Goal name',
  'จำนวนเงินเป้าหมาย (บาท)': 'Target amount (THB)',
  'วันที่ต้องการทำให้สำเร็จ': 'Target date',
  'เป้าหมายความฝัน': 'Dream goals',
  'ความฝัน / เป้าหมายการออม': 'Dreams / savings goals',
  'กระปุกความฝัน': 'Dream savings',
  'หมวดหมู่ความฝัน': 'Dream category',
  'เป้าหมายที่อยากทำให้สำเร็จ': 'Goals you want to achieve',
  'ยังไม่มีเป้าหมายความฝันของคุณ': 'No dream goals yet',
  'หมวดหมู่รายจ่าย': 'Expense category',
  'แก้ไขรายละเอียดรายจ่าย': 'Edit expense details',
  'แก้ไขหมวดหมู่รายจ่าย': 'Edit expense category',
  'เลือกหมวดหมู่รายจ่าย': 'Choose expense category',
  'กรอกรายละเอียดรายจ่าย': 'Enter expense details',
  'หมวดหมู่รายรับ': 'Income category',
  'แก้ไขรายละเอียดรายรับ': 'Edit income details',
  'แก้ไขหมวดหมู่รายรับ': 'Edit income category',
  'เลือกหมวดหมู่รายรับ': 'Choose income category',
  'กรอกรายละเอียดรายรับ': 'Enter income details',
  'จำนวนเงินออมครั้งนี้': 'Savings amount',
  'จำนวนเงิน': 'Amount',
  'เงินตั้งต้นที่มีอยู่แล้ว (บาท)': 'Starting balance (THB)',
  'เป้าหมายที่ต้องเก็บต่อเดือน (บาท)': 'Monthly savings target (THB)',
  'จำนวนเงินที่ต้องการเก็บ (บาท)': 'Target amount (THB)',
  'เงินออมเริ่มต้นที่มี (บาท)': 'Starting balance (THB)',
  'ตั้งเป้าเก็บเงินต่อเดือน (บาท)': 'Monthly savings target (THB)',
  'ชื่อรายจ่าย': 'Expense name',
  'ชื่อรายรับ': 'Income name',
  'เช่น ค่าเช่าห้อง': 'For example, room rent',
  'เช่น เงินเดือน': 'For example, salary',
  'วันที่ได้รับ': 'Pay date',
  'ครบกำหนด': 'Due date',
  '+ เพิ่มรายจ่ายประจำ': '+ Add recurring expense',
  '+ เพิ่มรายรับประจำ': '+ Add recurring income',
  'รายงานประจำเดือน': 'Monthly report',
  'เปรียบเทียบรายเดือน': 'Monthly comparison',
  'ปัดซ้าย–ขวาเพื่อดูเดือนอื่น': 'Swipe left or right to view other months',
  'วิเคราะห์แดชบอร์ด': 'Dashboard analysis',
  'คำแนะนำการเงินส่วนตัว': 'Personal finance guidance',
  'รายการล่าสุด': 'Recent entries',
  'อัตราการออม': 'Savings rate',
  'ใช้ต่อรายรับ': 'Spent from income',
  'คงเหลือสุทธิ': 'Net balance',
  'รายรับรวม': 'Total income',
  'รายจ่ายรวม': 'Total expenses',
  'เงินออมสะสม': 'Total savings',
  'ปฏิทินรายจ่าย': 'Expense calendar',
  'ปฏิทินรายการ': 'Entry calendar',
  'ดูรายจ่ายแยกตามวัน': 'View expenses by date',
  'ไม่มีรายจ่ายในเดือนนี้': 'No expenses this month',
  'ไม่มีรายการ': 'No entries',
  'ไม่มีงบ': 'No budget',
  'คงเหลือ': 'Balance',
  'ไม่มีการแจ้งเตือน': 'No notifications',
  'การแจ้งเตือนของคุณจะแสดงที่นี่': 'Your notifications will appear here.',
  'ทำเครื่องหมายว่าอ่านแล้ว': 'Mark as read',
  'อ่านแล้ว': 'Read',
  'ยังไม่ได้อ่าน': 'Unread',
  'เลือกวันที่': 'Select date',
  'รายการของวันนี้': 'Today’s entries',
  'ไม่มีรายการในวันนี้': 'No entries on this date',
  'รายการทางลัด': 'Shortcuts',
  'รายการ': 'entries',
  'เดือนที่แล้ว': 'Previous month',
  'เดือนก่อน': 'Previous month',
  'เดือนนี้': 'This month',
  'ทั้งหมด': 'All',
  'วันนี้': 'Today',
  'ต่อไป': 'Next',
  'ครบวันที่': 'Due on',
  'ยังไม่ได้ชำระเดือนนี้': 'Not paid this month',
  'ยังไม่ได้จ่าย': 'Not paid',
  'ชำระแล้ว': 'Paid',
  'จ่ายแล้ว': 'Paid',
  'รายจ่ายประจำ': 'Recurring expenses',
  'รายรับประจำ': 'Recurring income',
  'ค่าใช้จ่ายที่ต้องจ่ายทุกเดือน': 'Monthly expenses',
  'รายรับที่ได้รับเป็นประจำ': 'Recurring income',
  'รายรับ': 'Income',
  'รายจ่าย': 'Expenses',
  'เงินออม': 'Savings',
  'ความฝัน': 'Dreams',
  'สรุปยอด': 'Dashboard',
  'ปฏิทิน': 'Calendar',
  'บัญชีของฉัน': 'My account',
  'รูปโปรไฟล์': 'Profile picture',
  'เลือกรูปจากเครื่อง': 'Choose from device',
  'ถ่ายรูปใหม่': 'Take a photo',
  'ลบรูปโปรไฟล์': 'Remove profile picture',
  'ชื่อที่แสดง': 'Display name',
  'เปลี่ยนชื่อที่ใช้แสดงภายในแอป': 'Change the name shown in the app',
  'บันทึกการเปลี่ยนแปลง': 'Save changes',
  'ภาษาไทย': 'Thai',
  'ภาษา': 'Language',
  'ธีมของแอป': 'App theme',
  'ธีม': 'Theme',
  'สว่าง': 'Light',
  'มืด': 'Dark',
  'ตามระบบ': 'System',
  'การตั้งค่า': 'Settings',
  'รีเฟรช': 'Refresh',
  'ปิดหน้าต่าง': 'Close',
  'ยอดชำระรายจ่ายสะสมเดือนนี้': 'Expenses paid this month',
  'ยอดรับรายรับสะสมเดือนนี้': 'Income received this month',
  'ประเภทรายรับ': 'Income type',
  'รับวันที่': 'Received on',
  'หมวดหมู่: ค่าใช้จ่ายรายวัน': 'Category: daily expense',
  'หยอด': 'Save',
  'อา': 'Sun',
  'อา.': 'Sun',
  'จ': 'Mon',
  'จ.': 'Mon',
  'อ': 'Tue',
  'อ.': 'Tue',
  'พ': 'Wed',
  'พ.': 'Wed',
  'พฤ': 'Thu',
  'พฤ.': 'Thu',
  'ศ': 'Fri',
  'ศ.': 'Fri',
  'ส': 'Sat',
  'ส.': 'Sat',
  'เมนูหน้าหลัก': 'Home menu',
  'ตั้งค่าโปรไฟล์': 'Profile settings',
  'บาท': 'THB',
  'มกราคม': 'January',
  'กุมภาพันธ์': 'February',
  'มีนาคม': 'March',
  'เมษายน': 'April',
  'พฤษภาคม': 'May',
  'มิถุนายน': 'June',
  'กรกฎาคม': 'July',
  'สิงหาคม': 'August',
  'กันยายน': 'September',
  'ตุลาคม': 'October',
  'พฤศจิกายน': 'November',
  'ธันวาคม': 'December',
  'บ้าน': 'Home',
  'รถยนต์': 'Car',
  'มอเตอร์ไซค์': 'Motorcycle',
  'ท่องเที่ยว': 'Travel',
  'กล้อง': 'Camera',
  'เรียนต่อ': 'Education',
  'แต่งงาน': 'Wedding',
  'กองทุน': 'Fund',
  'หุ้น': 'Stocks',
  'ทองคำ': 'Gold',
  'คริปโต': 'Crypto',
  'ร้านอาหาร': 'Restaurant',
  'ธุรกิจ': 'Business',
  'เกษียณ': 'Retirement',
  'สุขภาพ': 'Health',
  'เสื้อผ้า': 'Clothes',
  'รองเท้า': 'Shoes',
  'นาฬิกา': 'Watch',
  'กระเป๋า': 'Bag',
  'เครื่องเสียง': 'Audio',
  'เกม': 'Gaming',
  'อื่นๆ': 'Other',
  'ค่าเช่า': 'Rent',
  'ผ่อนรถ': 'Car payment',
  'ค่าไฟ': 'Electricity',
  'ค่าน้ำ': 'Water',
  'ค่าอินเทอร์เน็ต': 'Internet',
  'ค่ามือถือ': 'Mobile phone',
  'ค่าเรียน': 'Education',
  'ค่าประกัน': 'Insurance',
  'สมาชิกยิม': 'Gym membership',
  'สมาชิก Netflix': 'Netflix',
  'สมาชิก Spotify': 'Spotify',
  'ค่าอาหาร': 'Food',
  'ค่ารักษา': 'Medical',
  'ออมเงิน': 'Savings',
  'เงินเดือน': 'Salary',
  'ลงทุน': 'Investment',
  'ขายของ': 'Sales',
  'โบนัส': 'Bonus',
  'ค่าคอมมิชชั่น': 'Commission',
  'ค่าตอบแทน': 'Compensation',
  'รายได้เสริม': 'Extra income',
  'ทั่วไป': 'General',
};
