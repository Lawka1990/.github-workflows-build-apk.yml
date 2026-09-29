abstract final class PolishDate {
  static const List<String> _weekdays = <String>[
    'Poniedziałek',
    'Wtorek',
    'Środa',
    'Czwartek',
    'Piątek',
    'Sobota',
    'Niedziela',
  ];
  static const List<String> _months = <String>[
    '',
    'stycznia',
    'lutego',
    'marca',
    'kwietnia',
    'maja',
    'czerwca',
    'lipca',
    'sierpnia',
    'września',
    'października',
    'listopada',
    'grudnia',
  ];

  static String full(DateTime date) {
    return '${_weekdays[date.weekday - 1]}, ${date.day} ${_months[date.month]} ${date.year}';
  }

  static String short(DateTime date) => '${date.day}.${date.month.toString().padLeft(2, '0')}';

  static String weekdayShort(DateTime date) =>
      _weekdays[date.weekday - 1].substring(0, 3).toUpperCase();
}
