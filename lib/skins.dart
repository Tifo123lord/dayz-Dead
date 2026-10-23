part of 'main.dart';

// ---------------------------------------------------------------------------
// Weapon skins: purchasable cosmetic finishes for every weapon.
// Each skin has a pre-baked weapon sprite (HUD / carry / shop) and a pre-baked
// survivor pose sheet in which only the weapon pixels are recoloured.
// ---------------------------------------------------------------------------

enum SkinRarity { standard, rare, epic, legendary }

extension SkinRarityInfo on SkinRarity {
  String get title => const ['استاندارد', 'کمیاب', 'حماسی', 'افسانه‌ای'][index];
  Color get color => const [
    Color(0xFF9A9A9A),
    Color(0xFF3A8AE0),
    Color(0xFFB04AE0),
    Color(0xFFE0B050),
  ][index];
}

class WeaponSkin {
  const WeaponSkin({
    required this.id,
    required this.weapon,
    required this.name,
    required this.desc,
    required this.rarity,
    required this.price,
    required this.sprite,
    required this.poses,
    this.tracer = const Color(0xFFFFF4C8),
  });

  final String id;
  final Weapon weapon;
  final String name, desc;
  final SkinRarity rarity;
  final int price;

  /// Stand-alone weapon image (same size as the stock sprite).
  final String sprite;

  /// Survivor aim/crouch/jump pose sheet holding this skin.
  final String poses;

  /// Bullet tracer colour while this skin is equipped.
  final Color tracer;

  bool get isDefault => price == 0;

  static WeaponSkin byId(String id) =>
      weaponSkins.firstWhere((s) => s.id == id, orElse: () => weaponSkins[0]);

  static List<WeaponSkin> forWeapon(Weapon w) =>
      weaponSkins.where((s) => s.weapon == w).toList();

  static String defaultId(Weapon w) => w == Weapon.ak ? 'ak_stock' : 'de_stock';
}

const List<WeaponSkin> weaponSkins = [
  // ---- AK-47 ----
  WeaponSkin(
    id: 'ak_stock',
    weapon: Weapon.ak,
    name: 'کلاسیک',
    desc: 'فولاد سیاه و قنداق چوب گردو؛ همان کلاشی که کنار در افتاده بود.',
    rarity: SkinRarity.standard,
    price: 0,
    sprite: 'assets/images/ak47.png',
    poses: 'assets/images/survivor_poses.png',
  ),
  WeaponSkin(
    id: 'ak_desert',
    weapon: Weapon.ak,
    name: 'طوفان شن',
    desc: 'استتار خاکی صحرا؛ مناسب خیابان‌های خاکستر گرفته.',
    rarity: SkinRarity.rare,
    price: 300,
    sprite: 'assets/skins/ak_desert.png',
    poses: 'assets/skins/poses_ak_desert.png',
    tracer: Color(0xFFFFE2A8),
  ),
  WeaponSkin(
    id: 'ak_arctic',
    weapon: Weapon.ak,
    name: 'زمستان هسته‌ای',
    desc: 'استتار برفی خاکستری-سفید؛ سرد مثل شب‌های بعد از روز صفر.',
    rarity: SkinRarity.rare,
    price: 450,
    sprite: 'assets/skins/ak_arctic.png',
    poses: 'assets/skins/poses_ak_arctic.png',
    tracer: Color(0xFFD8F0FF),
  ),
  WeaponSkin(
    id: 'ak_blood',
    weapon: Weapon.ak,
    name: 'دست خونین',
    desc: 'قنداق سرخ خون و خال‌های قرمز روی بدنه؛ نشان بازماندگان.',
    rarity: SkinRarity.epic,
    price: 800,
    sprite: 'assets/skins/ak_blood.png',
    poses: 'assets/skins/poses_ak_blood.png',
    tracer: Color(0xFFFF6A50),
  ),
  WeaponSkin(
    id: 'ak_toxic',
    weapon: Weapon.ak,
    name: 'اسپور سمی',
    desc: 'سبز رادیواکتیو با رگه‌های قارچی؛ از لانه‌ی قارچ‌ها بیرون آمده.',
    rarity: SkinRarity.epic,
    price: 1100,
    sprite: 'assets/skins/ak_toxic.png',
    poses: 'assets/skins/poses_ak_toxic.png',
    tracer: Color(0xFFB8FF6A),
  ),
  WeaponSkin(
    id: 'ak_gold',
    weapon: Weapon.ak,
    name: 'شاه طلایی',
    desc: 'بدنه‌ی تمام طلا با قنداق آبنوس؛ برای پادشاه ویرانه‌ها.',
    rarity: SkinRarity.legendary,
    price: 2000,
    sprite: 'assets/skins/ak_gold.png',
    poses: 'assets/skins/poses_ak_gold.png',
    tracer: Color(0xFFFFD86A),
  ),

  // ---- Desert Eagle ----
  WeaponSkin(
    id: 'de_stock',
    weapon: Weapon.deagle,
    name: 'کروم',
    desc: 'استیل براق کارخانه با دسته‌ی لاستیکی مشکی.',
    rarity: SkinRarity.standard,
    price: 0,
    sprite: 'assets/images/deagle.png',
    poses: 'assets/images/survivor_poses_deagle.png',
  ),
  WeaponSkin(
    id: 'de_blackout',
    weapon: Weapon.deagle,
    name: 'خاموشی',
    desc: 'پوشش سیاه مات؛ در تاریکی تونل مترو دیده نمی‌شود.',
    rarity: SkinRarity.rare,
    price: 250,
    sprite: 'assets/skins/deagle_blackout.png',
    poses: 'assets/skins/poses_deagle_blackout.png',
    tracer: Color(0xFFE8E8E8),
  ),
  WeaponSkin(
    id: 'de_ocean',
    weapon: Weapon.deagle,
    name: 'اقیانوس',
    desc: 'آنودایز آبی عمیق؛ یادگاری از دنیای قبل از سقوط.',
    rarity: SkinRarity.rare,
    price: 400,
    sprite: 'assets/skins/deagle_ocean.png',
    poses: 'assets/skins/poses_deagle_ocean.png',
    tracer: Color(0xFF8AD8FF),
  ),
  WeaponSkin(
    id: 'de_crimson',
    weapon: Weapon.deagle,
    name: 'زرشکی',
    desc: 'کروم سرخ براق؛ هر شلیک امضای خونین توست.',
    rarity: SkinRarity.epic,
    price: 750,
    sprite: 'assets/skins/deagle_crimson.png',
    poses: 'assets/skins/poses_deagle_crimson.png',
    tracer: Color(0xFFFF6A50),
  ),
  WeaponSkin(
    id: 'de_toxic',
    weapon: Weapon.deagle,
    name: 'زهرآگین',
    desc: 'سبز فسفری درخشان؛ قارچ‌پشت‌ها از آن می‌ترسند.',
    rarity: SkinRarity.epic,
    price: 1000,
    sprite: 'assets/skins/deagle_toxic.png',
    poses: 'assets/skins/poses_deagle_toxic.png',
    tracer: Color(0xFFB8FF6A),
  ),
  WeaponSkin(
    id: 'de_gold',
    weapon: Weapon.deagle,
    name: 'عقاب طلایی',
    desc: 'ورق طلای ۲۴ عیار؛ افسانه‌ای‌ترین سلاح کمری ویرانه.',
    rarity: SkinRarity.legendary,
    price: 1800,
    sprite: 'assets/skins/deagle_gold.png',
    poses: 'assets/skins/poses_deagle_gold.png',
    tracer: Color(0xFFFFD86A),
  ),
];
