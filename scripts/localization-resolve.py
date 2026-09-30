#!/usr/bin/env python3
"""Resolve a resource to text where a plain `string` is required.

Not every receiver can take a `ResourceStr`: an interface that already exists in a data
model, an accessibility text, a persisted value, or a callback typed `(message: string)`.
Widening those cascades through unrelated modules, so the localized value is resolved to
text at the boundary instead — `$r('app.string.name')` becomes
`resolveAppResourceText($r('app.string.name'))`.

The compiler names the exact line and column; this script rewrites only the `$r(...)` call
at that position.

Usage:
    python3 scripts/localization-resolve.py <hvigor.log> [--apply]
"""

import argparse
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.path.join(REPO, 'AiraBrowser/entry/src/main/ets')

ANSI = re.compile(r'\x1b\[[0-9;]*m')
ERROR = re.compile(
    r"Error Message: (Argument of type 'Resource' is not assignable to parameter of type 'string'|"
    r"Type 'Resource' is not assignable to type 'string')"
    r"[^\n]*? At File: ([^\s:]+):(\d+):(\d+)"
)
# A `$r('app.string.name')` call, with its full argument list.
RESOURCE_CALL = re.compile(r"\$r\('app\.string\.[^']*'[^)]*\)")


def strip_ansi(text):
    return ANSI.sub('', text)


def find_resource_call(line, column):
    """The `$r(...)` call to wrap.

    The compiler points at the argument's position, which for an object-literal property is
    the property name rather than the call. The call on the reported line is therefore
    preferred, and the column is only used to choose between several.
    """
    matches = list(RESOURCE_CALL.finditer(line))
    if not matches:
        return None
    for match in matches:
        if match.start() <= column <= match.end():
            return match
    # The column can sit on the property name; the only `$r` on the line is the value.
    if len(matches) == 1:
        return matches[0]
    # Several resources on one line (a ternary): pick the one nearest the column.
    return min(matches, key=lambda match: abs(match.start() - column))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('log')
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()

    with open(args.log, encoding='utf-8') as handle:
        log = strip_ansi(handle.read())

    by_file = {}
    for match in ERROR.finditer(log):
        path = match.group(2)
        line = int(match.group(3))
        column = int(match.group(4))
        by_file.setdefault(path, []).append((line, column))

    changed = 0
    touched = set()
    unresolved = []
    for path, positions in sorted(by_file.items()):
        if not os.path.isfile(path):
            continue
        with open(path, encoding='utf-8') as handle:
            lines = handle.read().split('\n')
        dirty = False
        # Apply from the end of each line so earlier columns stay valid.
        for line_number, column in sorted(positions, reverse=True):
            line = lines[line_number - 1]
            call = find_resource_call(line, column)
            if call is None:
                unresolved.append(f'{os.path.relpath(path, BASE)}:{line_number}')
                continue
            if line[max(0, call.start() - 24):call.start()].endswith('resolveAppResourceText('):
                continue
            lines[line_number - 1] = (
                line[:call.start()] + 'resolveAppResourceText(' + call.group(0) + ')' + line[call.end():]
            )
            changed += 1
            dirty = True
        if dirty:
            # The resolver is a plain function, so the file has to import it.
            source = '\n'.join(lines)
            if os.path.basename(path) == 'AppResourceText.ets':
                pass
            elif 'resolveAppResourceText' in source and not re.search(
                r"import \{[^}]*resolveAppResourceText", source
            ):
                rel = os.path.relpath(path, BASE)
                # From `core/browser/X.ets` the target is `../../core/resources/...`: one
                # `..` per directory level, because the path is relative to the file.
                depth = rel.count(os.sep)
                prefix = '../' * depth
                import_line = f"import {{ resolveAppResourceText }} from '{prefix}core/resources/AppResourceText';"
                insert_at = 0
                for index, candidate in enumerate(lines):
                    if candidate.startswith('import '):
                        insert_at = index + 1
                        if not candidate.rstrip().endswith(';'):
                            while insert_at < len(lines) and not lines[insert_at - 1].rstrip().endswith(';'):
                                insert_at += 1
                    elif candidate.strip() == '' and insert_at > 0:
                        break
                    else:
                        break
                lines.insert(insert_at, import_line)
                touched.add(path)
            touched.add(path)
            if args.apply:
                with open(path, 'w', encoding='utf-8') as handle:
                    handle.write('\n'.join(lines))

    print(f'{changed} resource(s) resolved to text in {len(touched)} file(s)')
    if unresolved:
        print(f'{len(unresolved)} position(s) had no $r(...) call to wrap:')
        for item in sorted(set(unresolved))[:15]:
            print(f'  {item}')
    if not args.apply:
        print('(dry run)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
