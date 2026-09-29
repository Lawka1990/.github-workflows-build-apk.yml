import 'package:flutter_test/flutter_test.dart';
import 'package:grunwald_navigator/models/program_event.dart';

void main() {
  test('wydarzenie poprawnie rozpoznaje czas trwania', () {
    final event = ProgramEvent(
      id: 'x',
      date: DateTime(2026, 7, 17),
      start: '11:00',
      end: '12:30',
      title: 'Test',
      placeId: 'pole_bitwy',
      description: '',
      category: 'walki',
      isRehearsal: false,
    );

    expect(event.isActiveAt(DateTime(2026, 7, 17, 11, 30)), isTrue);
    expect(event.isActiveAt(DateTime(2026, 7, 17, 10, 59)), isFalse);
    expect(event.isActiveAt(DateTime(2026, 7, 17, 12, 30)), isFalse);
  });
}
