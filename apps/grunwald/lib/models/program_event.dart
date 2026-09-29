class ProgramEvent {
  const ProgramEvent({
    required this.id,
    required this.date,
    required this.start,
    required this.end,
    required this.title,
    required this.placeId,
    required this.description,
    required this.category,
    required this.isRehearsal,
  });

  factory ProgramEvent.fromJson(Map<String, Object?> json) {
    return ProgramEvent(
      id: json['id']! as String,
      date: DateTime.parse(json['date']! as String),
      start: json['start']! as String,
      end: json['end']! as String,
      title: json['title']! as String,
      placeId: json['placeId']! as String,
      description: (json['description'] as String?) ?? '',
      category: (json['category'] as String?) ?? 'inne',
      isRehearsal: (json['isRehearsal'] as bool?) ?? false,
    );
  }

  final String id;
  final DateTime date;
  final String start;
  final String end;
  final String title;
  final String placeId;
  final String description;
  final String category;
  final bool isRehearsal;

  DateTime startsAt() => _dateTime(start);
  DateTime endsAt() => _dateTime(end);

  bool isActiveAt(DateTime moment) {
    return !moment.isBefore(startsAt()) && moment.isBefore(endsAt());
  }

  bool isUpcomingAt(DateTime moment) => startsAt().isAfter(moment);

  DateTime _dateTime(String time) {
    final parts = time.split(':');
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }
}
