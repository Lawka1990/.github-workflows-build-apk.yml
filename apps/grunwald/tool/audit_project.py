from datetime import datetime
import json
from pathlib import Path
import re
import struct


root = Path(__file__).resolve().parents[1]
places = json.loads(
    (root / 'assets/data/places.json').read_text(encoding='utf-8')
)
events = json.loads(
    (root / 'assets/data/program_2026.json').read_text(encoding='utf-8')
)

pubspec = (root / 'pubspec.yaml').read_text(encoding='utf-8')
assert re.search(r'^version:\s*0\.12\.0\+13\s*$', pubspec, re.MULTILINE), (
    'Nieprawidłowa wersja V12 w pubspec.yaml.'
)

place_ids = [place['id'] for place in places]
event_ids = [event['id'] for event in events]
assert len(place_ids) == len(set(place_ids)), 'Powielone identyfikatory miejsc.'
assert len(event_ids) == len(set(event_ids)), 'Powielone identyfikatory wydarzeń.'
assert all(
    0 <= place['x'] <= 1 and 0 <= place['y'] <= 1 for place in places
), 'Punkt poza mapą.'

missing = sorted({event['placeId'] for event in events} - set(place_ids))
assert not missing, f'Wydarzenia wskazują nieistniejące miejsca: {missing}'

time_pattern = re.compile(r'^([01]\d|2[0-3]):[0-5]\d$')
for event in events:
    assert time_pattern.match(event['start']), f'Błędny czas startu: {event}'
    assert time_pattern.match(event['end']), f'Błędny czas końca: {event}'
    start = datetime.fromisoformat(f"{event['date']}T{event['start']}:00")
    end = datetime.fromisoformat(f"{event['date']}T{event['end']}:00")
    assert end > start, f'Wydarzenie kończy się przed startem: {event}'

map_path = root / 'assets/images/mapa_grunwald_2026.png'
assert map_path.exists(), 'Brak mapy.'
map_bytes = map_path.read_bytes()
if map_bytes[:8] == b'\x89PNG\r\n\x1a\n':
    map_width, map_height = struct.unpack('>II', map_bytes[16:24])
elif map_bytes[:2] == b'\xff\xd8':
    offset = 2
    map_width = map_height = 0
    while offset + 9 < len(map_bytes):
        if map_bytes[offset] != 0xFF:
            offset += 1
            continue
        marker = map_bytes[offset + 1]
        offset += 2
        if marker in {0xD8, 0xD9}:
            continue
        segment_length = struct.unpack('>H', map_bytes[offset:offset + 2])[0]
        if marker in {0xC0, 0xC1, 0xC2, 0xC3}:
            map_height, map_width = struct.unpack(
                '>HH', map_bytes[offset + 3:offset + 7]
            )
            break
        offset += segment_length
else:
    raise AssertionError('Mapa nie jest obsługiwanym plikiem PNG/JPEG.')
assert (map_width, map_height) == (1536, 1024), (
    f'Nieprawidłowy rozmiar mapy: {map_width}x{map_height}.'
)

sanitary = next(
    place for place in places if place['id'] == 'sanitariaty_prysznice'
)
assert abs(sanitary['x'] - 0.7421875) < 0.000001
assert abs(sanitary['y'] - 0.8740234) < 0.000001

required_v12_files = [
    'lib/services/map_navigation.dart',
    'lib/utils/category_catalog.dart',
    'lib/utils/search_text.dart',
    'lib/widgets/event_details_sheet.dart',
    'lib/widgets/place_details_sheet.dart',
    'test/map_navigation_test.dart',
    'test/search_text_test.dart',
]
for relative_path in required_v12_files:
    assert (root / relative_path).exists(), f'Brak pliku V12: {relative_path}'

banned = ['.withOpacity(', '..translate(', '..scale(', 'desiredAccuracy:']
dart_files = list((root / 'lib').rglob('*.dart'))
for dart in dart_files:
    content = dart.read_text(encoding='utf-8')
    assert content.strip(), f'Pusty plik Dart: {dart.relative_to(root)}'
    for token in banned:
        assert token not in content, (
            f'Zakazane lub przestarzałe API {token} '
            f'w {dart.relative_to(root)}'
        )

print(
    'OK V12: '
    f'{len(places)} miejsc, {len(events)} wydarzeń, mapa 1536x1024, '
    'spójne dane, nawigacja, filtry i brak zakazanych API.'
)
