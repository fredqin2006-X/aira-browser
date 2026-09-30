#!/usr/bin/env python3
"""Apply `$r(...)` replacements only at render sites.

A Chinese literal can be copy (rendered) or an identity (compared, matched, or used as a
key). Replacing an identity breaks the code, so this script only rewrites a literal when
every occurrence in the file sits in a position that renders it: a property assignment to a
known copy field, a `Text(...)` argument, a toast/message call, or a returned value.

Usage:
    python3 scripts/localization-apply.py --map /tmp/map.tsv [--apply]
"""

import argparse
import collections
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ETS = os.path.join(REPO, 'AiraBrowser/entry/src/main/ets')

# Fields that carry rendered copy. A literal assigned to one of these is safe to localize.
COPY_FIELD = re.compile(
    r'(?:^|[\s{,(])(title|subtitle|message|label|text|placeholder|description|helperText|'
    r'summary|footerText|detailText|emptyTitle|emptyMessage|confirmLabel|cancelLabel|'
    r'primaryActionLabel|secondaryActionLabel|tertiaryActionLabel|detailLabel|'
    r'accessibilityLabel|accessibilityText|toast|reason|helperMessage|statusText|'
    r'fallbackLabel|userVisibleStatus|versionTitle|moreButtonTitle|appLanguageLabel|'
    r'homeLayoutLabel|customHomepageLabel|startupBehaviorLabel|tabAutoCloseLabel|'
    r'defaultBrowserLabel|historyRetentionLabel|privateBrowsingLabel|themeTitle)\s*:'
)
# Calls that render their argument.
COPY_CALL = re.compile(
    r'(?:showToast|showMessage|showNativeToast|showPlayerToast|showDialog|showRiskPrompt|'
    r'setHelperMessage|publishHelper|showHelper|emitMessage|buildInfoLine|buildRowLabel|'
    r'buildEmptyState|buildMessageState|buildRuleSourceSection|buildSecurityRow|'
    r'buildTabContextMenuItem|buildDesktopShortcutContextMenuItem|buildStorageSection|'
    r'buildDetailRow|buildDisplayModeMenuItemContent|buildOuterButton|Text)\s*\('
)
# A comparison, key, or identity use that must stay a plain string.
IDENTITY = re.compile(
    r'===|!==|\.indexOf\(|\.includes\(|\.startsWith\(|\.endsWith\(|\.test\(|\.has\(|'
    r'\.get\(|\.set\(|case |new Set\(|\.split\(|\.replace\(|\.match\(|\.trim\(\)\s*[=!]'
)


def occurrences(lines, value):
    """Every line index and column where `'value'` appears."""
    needle = "'" + value + "'"
    found = []
    for index, line in enumerate(lines):
        start = 0
        while True:
            column = line.find(needle, start)
            if column < 0:
                break
            found.append((index, column, line))
            start = column + 1
    return found


def is_render_site(line):
    return COPY_FIELD.search(line) is not None or COPY_CALL.search(line) is not None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--map', required=True)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()

    mapping = {}
    with open(args.map, encoding='utf-8') as handle:
        for line in handle:
            line = line.rstrip('\n')
            if not line:
                continue
            name, chinese, _english = line.split('\t')
            mapping[chinese] = name

    # Group the literals by the file that first produced them, then apply to every file.
    skipped_identity = []
    applied = 0
    files = collections.defaultdict(list)
    for root, _dirs, names in os.walk(ETS):
        for name in names:
            if not name.endswith('.ets'):
                continue
            path = os.path.join(root, name)
            with open(path, encoding='utf-8') as handle:
                lines = handle.read().split('\n')
            changed = False
            for chinese, resource in mapping.items():
                hits = occurrences(lines, chinese)
                if not hits:
                    continue
                if any(IDENTITY.search(line) and not is_render_site(line) for _i, _c, line in hits):
                    skipped_identity.append((os.path.relpath(path, ETS), chinese))
                    continue
                if not all(is_render_site(line) for _i, _c, line in hits):
                    skipped_identity.append((os.path.relpath(path, ETS), chinese))
                    continue
                for index, column, line in reversed(hits):
                    lines[index] = line[:column] + f"$r('app.string.{resource}')" + line[column + len(chinese) + 2:]
                changed = True
                applied += 1
            if changed:
                files[path] = lines
                if args.apply:
                    with open(path, 'w', encoding='utf-8') as handle:
                        handle.write('\n'.join(lines))

    print(f'{applied} literal(s) at render sites across {len(files)} file(s)')
    print(f'{len(skipped_identity)} literal(s) left alone (identity or mixed use):')
    for rel, chinese in sorted(set(skipped_identity))[:25]:
        print(f'  {rel}: {chinese}')
    if not args.apply:
        print('(dry run)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
