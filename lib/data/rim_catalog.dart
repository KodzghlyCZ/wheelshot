/// Common rim / OEM wheel brands.
const List<String> kRimBrands = [
  'Volkswagen',
  'Audi',
  'Škoda',
  'Seat',
  'BMW',
  'Mercedes-Benz',
  'Honda',
  'Toyota',
  'Ford',
  'Opel',
  'Hyundai',
  'Kia',
  'Mazda',
  'Renault',
  'Peugeot',
  'Citroën',
  'Volvo',
  'Porsche',
  'Ronal',
  'ATS',
  'AEZ',
  'Alutec',
  'Dezent',
  'Borbet',
  'OZ Racing',
  'BBS',
  'Enkei',
  'Mak',
  'RC Design',
  'MSW',
];

/// Bolt counts for PCD dials.
const List<int> kPcdBoltCounts = [4, 5, 6, 8];

/// Common PCD circle diameters (mm) for the second dial.
const List<double> kPcdDiameters = [
  98.0,
  100.0,
  105.0,
  108.0,
  110.0,
  112.0,
  114.3,
  115.0,
  120.0,
  120.65,
  127.0,
  130.0,
  139.7,
  150.0,
  160.0,
  165.1,
  170.0,
];

String formatPcd(int bolts, double diameter) {
  final cleaned = diameter == diameter.roundToDouble()
      ? diameter.toInt().toString()
      : ((diameter * 100).round() % 10 == 0
          ? diameter.toStringAsFixed(1)
          : diameter.toStringAsFixed(2));
  return '${bolts}x$cleaned';
}

/// Common hub / center bore diameters (mm) across EU OEM + aftermarket.
const List<double> kCommonCenterBores = [
  52.1, // some Fiat / older
  54.1, // BMW older / Mini
  56.1, // Toyota / Lexus some
  56.6, // Honda / Mitsubishi
  57.1, // VAG MQB/PQ (VW Škoda Audi Seat)
  58.1, // Opel / some PSA
  59.1, // Kia / Hyundai some
  60.1, // Toyota / Lexus / Ford some
  63.4, // Honda / Ford Focus older
  64.1, // Renault / Nissan / Dacia
  65.1, // Mercedes / some Ford
  66.1, // aftermarket / Toyota
  66.45, // Platin / aftermarket rings hub
  66.5,
  66.6, // aftermarket / older VAG hub
  67.1, // Volvo / Land Rover some
  70.1, // Mazda / Ford
  70.3, // Mercedes
  71.5, // BMW
  71.6, // BMW
  72.5, // Mercedes
  72.6, // Mercedes
  74.1, // Mercedes / Audi older
  75.1, // Chrysler / Jeep / some MB
  78.1, // Mitsubishi / Hyundai
  84.1, // Ford Transit / commercial
  92.0, // Porsche some
  98.0,
  100.1,
  106.1,
  108.0,
  110.1,
  112.0,
  124.9, // some truck / van
];
