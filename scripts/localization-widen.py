#!/usr/bin/env python3
"""Widen `string` declarations that receive a localized resource.

When a literal becomes `$r('app.string.name')`, whatever holds it must accept `ResourceStr`:
a struct field, an interface field, a parameter, a return type, or a callback signature. The
compiler names the exact line; this script maps that line back to the declaration and widens
it.

Only the reported line is used to locate the declaration, and a declaration is only widened
when it is a real carrier of localized text: a theme color, a token, or an id is never
touched, because those are declared with a literal default rather than a `$r` value.

Usage:
    python3 scripts/localization-widen.py <hvigor.log> [--apply]
"""

import argparse
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.path.join(REPO, 'AiraBrowser/entry/src/main/ets')

ANSI = re.compile(r'\x1b\[[0-9;]*m')
# The compiler reports the offending line; the declaration may sit on it or above it.
ERROR = re.compile(
    r"Error Message: ([^\n]*?)\s+At File: ([^\s:]+):(\d+):(\d+)"
)

# A declaration whose type is `string` and whose initializer is a resource.
FIELD_WITH_RESOURCE = re.compile(
    r'^(\s*)(?:@(?:Prop|State|Link|Provide|StorageProp|StorageLink|ObjectLink|Consume)\s*)?'
    r'(?:private\s+|public\s+|protected\s+|readonly\s+)*'
    r'(\w+)(\??)\s*:\s*string\b([^=]*)=\s*\$r\('
)
# An interface member: `  name: string;`
INTERFACE_MEMBER = re.compile(r'^(\s*)(\w+)(\??)\s*:\s*string\s*;\s*$')
# A method signature ending in `: string {` (or `: string\n` for a multi-line signature).
METHOD_RETURN = re.compile(r'^(\s*)(?:private\s+|public\s+|protected\s+)?(\w+)\s*\([^)]*\)\s*:\s*string\s*\{?\s*$')
# A callback-typed property: `name: (arg: string) => void;`
CALLBACK_PROP = re.compile(r'^(\s*)(\w+)(\??)\s*:\s*\(([^)]*)\)\s*=>\s*(\w+)\s*;?\s*$')
# A parameter inside a multi-line signature: `  name: string,`
PARAM_LINE = re.compile(r'^(\s*)(\w+)(\??)\s*:\s*string\s*[,)]\s*$')


def strip_ansi(text):
    return ANSI.sub('', text)


def widen_line(line):
    """Return `line` with its `string` type replaced by `ResourceStr`."""
    return re.sub(r':\s*string\b', ': ResourceStr', line, count=1)


def callback_with_widened_param(line):
    """Widen every `string` parameter of a callback-typed property."""
    def replace(match):
        params = re.sub(r':\s*string\b', ': ResourceStr', match.group(4))
        return f'{match.group(1)}{match.group(2)}{match.group(3)}: ({params}) => {match.group(5)};'
    return CALLBACK_PROP.sub(replace, line)


def find_declaration(lines, reported_index):
    """Locate the declaration that owns the reported line.

    Walks upward from the reported line. A parameter or callback property sits on the
    reported line; a field or method return may sit a few lines above it.
    """
    # The reported line itself can be the declaration.
    line = lines[reported_index]
    if CALLBACK_PROP.match(line):
        return reported_index, 'callback'
    if PARAM_LINE.match(line):
        return reported_index, 'param'
    if FIELD_WITH_RESOURCE.match(line):
        return reported_index, 'field'
    if INTERFACE_MEMBER.match(line):
        return reported_index, 'interface'
    if METHOD_RETURN.match(line):
        return reported_index, 'method'

    # Otherwise walk up looking for the field or method that owns the value.
    for index in range(reported_index - 1, max(-1, reported_index - 30), -1):
        candidate = lines[index]
        if FIELD_WITH_RESOURCE.match(candidate):
            return index, 'field'
        if CALLBACK_PROP.match(candidate):
            return index, 'callback'
        if METHOD_RETURN.match(candidate):
            return index, 'method'
        if INTERFACE_MEMBER.match(candidate):
            return index, 'interface'
    return None, None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('log')
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()

    with open(args.log, encoding='utf-8') as handle:
        log = strip_ansi(handle.read())

    by_file = {}
    for match in ERROR.finditer(log):
        message = match.group(1)
        # Only widen for the errors that mean a resource met a `string`.
        if not re.search(r"'Resource(Str)?' is not assignable|ResourceStr' is not assignable|"
                         r"not comparable to type 'string'|ResourceStr' is not assignable to parameter|"
                         r"'string \| Resource' is not assignable", message):
            continue
        path = match.group(2)
        line = int(match.group(3))
        by_file.setdefault(path, set()).add(line)

    changed = 0
    touched = set()
    for path, line_numbers in sorted(by_file.items()):
        if not os.path.isfile(path):
            continue
        with open(path, encoding='utf-8') as handle:
            lines = handle.read().split('\n')
        dirty = False
        for line_number in sorted(line_numbers):
            index, kind = find_declaration(lines, line_number - 1)
            if index is None:
                continue
            original = lines[index]
            if kind == 'callback':
                widened = callback_with_widened_param(original)
            else:
                widened = widen_line(original)
            if widened != original:
                lines[index] = widened
                changed += 1
                dirty = True
                print(f'{os.path.relpath(path, BASE)}:{index + 1} [{kind}]')
                print(f'  - {original.strip()[:105]}')
                print(f'  + {widened.strip()[:105]}')
        if dirty:
            touched.add(path)
            if args.apply:
                with open(path, 'w', encoding='utf-8') as handle:
                    handle.write('\n'.join(lines))

    print(f'\n{changed} declaration(s) widened in {len(touched)} file(s)')
    if not args.apply:
        print('(dry run)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
