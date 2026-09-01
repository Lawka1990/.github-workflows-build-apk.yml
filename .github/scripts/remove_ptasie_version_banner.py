from pathlib import Path
import sys


def matching_paren(text: str, open_pos: int) -> int:
    depth = 0
    quote = None
    escaped = False
    i = open_pos
    while i < len(text):
        ch = text[i]
        if quote is not None:
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == quote:
                quote = None
            i += 1
            continue
        if ch in ("'", '"'):
            quote = ch
        elif ch == '(':
            depth += 1
        elif ch == ')':
            depth -= 1
            if depth == 0:
                return i
        i += 1
    raise RuntimeError('Nie znaleziono końca widgetu opisu wersji')


def remove_banner(path: Path) -> bool:
    src = path.read_text(encoding='utf-8')
    markers = (
        'Ta wersja zawiera tylko funkcje budek',
        'Ta wersja zawiera tylko funkcje obserwacji',
        'Ta wersja zawiera tylko funkcje',
    )
    idx = -1
    for marker in markers:
        idx = src.find(marker)
        if idx >= 0:
            break
    if idx < 0:
        print(f'{path}: opisu wersji już nie ma')
        return False

    constructors = ('Container(', 'Card(', 'DecoratedBox(', 'ColoredBox(', 'Padding(')
    starts = [(src.rfind(name, 0, idx), name) for name in constructors]
    starts = [(pos, name) for pos, name in starts if pos >= 0]
    if not starts:
        raise RuntimeError('Znaleziono tekst opisu, ale nie znaleziono jego widgetu')

    # Najbliższy kontener wokół tekstu jest elementem paska informacyjnego.
    start, name = max(starts, key=lambda item: item[0])
    open_pos = src.find('(', start)
    end = matching_paren(src, open_pos)

    replacement = 'const SizedBox.shrink()'
    out = src[:start] + replacement + src[end + 1:]
    if any(marker in out for marker in markers):
        raise RuntimeError('Opis wersji nadal występuje po poprawce')

    path.write_text(out, encoding='utf-8')
    print(f'{path}: usunięto pasek opisu wersji ({name[:-1]})')
    return True


if __name__ == '__main__':
    target = Path(sys.argv[1] if len(sys.argv) > 1 else 'lib/main.dart')
    remove_banner(target)
