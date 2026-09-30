#!/usr/bin/env python3
"""Scan the AiraBrowser HarmonyOS client for user-visible Chinese literals that are not
localized, and classify each one as copy (must be translated) or an intentional Chinese
value (a match marker, a protocol value, a format marker).

Usage:
    python3 scripts/localization-scan.py                 # all scopes, summary + detail
    python3 scripts/localization-scan.py --scope core/browser
    python3 scripts/localization-scan.py --summary
"""

import argparse
import collections
import json
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ETS = os.path.join(REPO, 'AiraBrowser/entry/src/main/ets')
RES = os.path.join(REPO, 'AiraBrowser/entry/src/main/resources')

CJK = re.compile(r'[\u4e00-\u9fff]')
LITERAL = re.compile(r"'([^'\\\n]*)'")

# A line that compares/matches a value rather than rendering it.
MATCH_LINE = re.compile(
    r'indexOf|includes|containsAny|startsWith|endsWith|\.test\(|\.search\(|'
    r'\bcase\b|\.has\(|===|!==|new Set\(\[|Set<string>|\.split\(|\.replace\(|'
    r'\.match\(|RegExp|normalize\('
)
# A line that renders a value.
RENDER_LINE = re.compile(
    r'title:|value:|message:|label:|text:|placeholder:|description:|helperText:|'
    r'subtitle:|footerText:|summary|Text\(|showToast\(|errorMessage|reason:|note:|'
    r'hint:|toast|confirm|Action:|accessibilityText|announce|Prompt|label:'
)


def load_resource_values():
    values = collections.defaultdict(list)
    for locale in ('base', 'zh_CN', 'en_US'):
        path = os.path.join(RES, locale, 'element/string.json')
        with open(path, encoding='utf-8') as handle:
            data = json.load(handle)
        for entry in data['string']:
            if locale == 'base':
                values[entry.get('value')].append(entry['name'])
    return values


def load_localization_keys():
    """Every Chinese value used as a `case` in a localization table."""
    keys = set()
    for root, _dirs, names in os.walk(ETS):
        for name in names:
            if not name.endswith('.ets'):
                continue
            with open(os.path.join(root, name), encoding='utf-8') as handle:
                source = handle.read()
            for match in re.finditer(r"case '([^']*)':", source):
                if CJK.search(match.group(1)):
                    keys.add(match.group(1))
    return keys


def scope_files(scope):
    base = os.path.join(ETS, scope) if scope else ETS
    out = []
    for root, _dirs, names in os.walk(base):
        if os.sep + 'test' in root:
            continue
        for name in names:
            if name.endswith('.ets'):
                out.append(os.path.join(root, name))
    return sorted(out)


# The localization tables themselves hold Chinese by design: their keys are the identities
# the rest of the code produces.
LOCALIZATION_TABLE = re.compile(r'(Copy|EnglishIndex|CatalogCopy)\.ets$')


def scan_file(path, known_values, loc_keys):
    """Classify the Chinese literals in one file."""
    with open(path, encoding='utf-8') as handle:
        source = handle.read()
    source = re.sub(r'/\*.*?\*/', '', source, flags=re.S)
    lines = [re.sub(r'//[^\n]*', '', line) for line in source.split('\n')]
    copy = collections.Counter()
    intentional = collections.Counter()
    for line in lines:
        for match in LITERAL.finditer(line):
            value = match.group(1)
            if not value or not CJK.search(value):
                continue
            if value in loc_keys or value in known_values:
                continue
            # A call argument that is already a localization key is not copy here.
            if re.search(r"localize\w*Copy\(\s*'" + re.escape(value) + r"'\s*\)", line):
                continue
            if MATCH_LINE.search(line) and not RENDER_LINE.search(line):
                intentional[value] += 1
            else:
                copy[value] += 1
    return copy, intentional


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--scope', default='')
    parser.add_argument('--summary', action='store_true')
    parser.add_argument('--limit', type=int, default=40)
    args = parser.parse_args()

    known_values = load_resource_values()
    loc_keys = load_localization_keys()

    files = scope_files(args.scope)
    total_copy = 0
    total_intentional = 0
    by_dir = collections.Counter()
    detail = collections.defaultdict(set)
    for path in files:
        if LOCALIZATION_TABLE.search(os.path.basename(path)):
            continue
        copy, intentional = scan_file(path, known_values, loc_keys)
        if copy:
            rel = os.path.relpath(path, ETS)
            by_dir[os.path.dirname(rel)] += len(copy)
            detail[rel] = set(copy)
        total_copy += len(copy)
        total_intentional += len(intentional)

    print(f'scanned {len(files)} files under {args.scope or "ets/"}')
    print(f'unlocalized copy literals (unique per file): {total_copy}')
    print(f'intentional Chinese (match/format/protocol):  {total_intentional}')
    print()
    print('by directory:')
    for directory, count in by_dir.most_common(30):
        print(f'  {count:5}  {directory}')
    if not args.summary:
        print()
        for rel in sorted(detail, key=lambda k: -len(detail[k])):
            print(f'## {rel} ({len(detail[rel])})')
            for value in sorted(detail[rel]):
                print(f'   {value}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
