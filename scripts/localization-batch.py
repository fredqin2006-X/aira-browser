#!/usr/bin/env python3
"""Batch localization helper.

Reads a TSV of `<file>\\t<chinese>` rows (as produced by localization-scan.py) plus a TSV of
`<chinese>\\t<english>` translations, generates a stable resource name for each Chinese
literal, and writes the entries into the three string catalogs.

Resource names must be ASCII identifiers, so each literal gets `<prefix>_<nn>` where the
prefix comes from the file's module. The mapping is emitted to a TSV so the render-site edit
and the localization table can both use it.

Usage:
    python3 scripts/localization-batch.py --keys in.tsv --translations en.tsv --prefix-out map.tsv
    python3 scripts/localization-batch.py --keys in.tsv --translations en.tsv --prefix-out map.tsv --apply
"""

import argparse
import json
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(REPO, 'AiraBrowser/entry/src/main/resources')
ETS = os.path.join(REPO, 'AiraBrowser/entry/src/main/ets')

# Module prefix for a file path, so a generated name says where it belongs.
PREFIX_RULES = [
    (r'^app/pages/BrowserShellPage', 'browser_shell'),
    (r'^app/pages/BookmarkFolderIconPreviewPage', 'bookmark_icon_preview'),
    (r'^app/pages/CustomHomepageDeveloperGuidePage', 'custom_home_guide'),
    (r'^app/pages/(\w+)', 'page_\\1'),
    (r'^app/components/browser/(\w+)', 'browser_ui_\\1'),
    (r'^app/components/adblock/(\w+)', 'adblock_ui_\\1'),
    (r'^app/components/sync/(\w+)', 'sync_ui_\\1'),
    (r'^app/components/translation/(\w+)', 'translation_ui_\\1'),
    (r'^app/components/wallpaper/(\w+)', 'wallpaper_ui_\\1'),
    (r'^app/components/update/(\w+)', 'update_ui_\\1'),
    (r'^app/components/onboarding/(\w+)', 'onboarding_ui_\\1'),
    (r'^app/components/membership/(\w+)', 'membership_ui_\\1'),
    (r'^app/components/customhome/(\w+)', 'custom_home_ui_\\1'),
    (r'^app/components/(\w+)/(\w+)', 'ui_\\1_\\2'),
    (r'^core/browser/(\w+)', 'browser_\\1'),
    (r'^core/onboarding/(\w+)', 'onboarding_\\1'),
    (r'^core/translation/(\w+)', 'translation_\\1'),
    (r'^core/web/(\w+)', 'web_\\1'),
    (r'^core/sync/(\w+)', 'sync_\\1'),
    (r'^core/deviceTabs/(\w+)', 'device_tabs_\\1'),
    (r'^core/download/(\w+)', 'download_\\1'),
    (r'^core/adblock/(\w+)', 'adblock_\\1'),
    (r'^core/customhome/(\w+)', 'custom_home_\\1'),
    (r'^core/wallpaper/(\w+)', 'wallpaper_\\1'),
    (r'^core/(\w+)/(\w+)', 'core_\\1_\\2'),
    (r'^services/membership/(\w+)', 'membership_\\1'),
    (r'^services/web/(\w+)', 'web_service_\\1'),
    (r'^services/translation/(\w+)', 'translation_service_\\1'),
    (r'^services/customhome/(\w+)', 'custom_home_service_\\1'),
    (r'^services/search/(\w+)', 'search_\\1'),
    (r'^services/sync/(\w+)', 'sync_service_\\1'),
    (r'^services/video/(\w+)', 'video_\\1'),
    (r'^services/adblock/(\w+)', 'adblock_service_\\1'),
    (r'^services/backup/(\w+)', 'backup_\\1'),
    (r'^services/media/(\w+)', 'media_\\1'),
    (r'^services/viewer/(\w+)', 'viewer_\\1'),
    (r'^services/system/(\w+)', 'system_\\1'),
    (r'^services/novel/(\w+)', 'novel_\\1'),
    (r'^services/(\w+)/(\w+)', 'service_\\1_\\2'),
    (r'^features/membership/(\w+)', 'membership_feature_\\1'),
    (r'^features/theme/palettes/(\w+)', 'palette_\\1'),
    (r'^features/novel/(\w+)', 'novel_feature_\\1'),
    (r'^features/(\w+)/(\w+)', 'feature_\\1_\\2'),
    (r'^data/sync/(\w+)', 'sync_data_\\1'),
    (r'^data/(\w+)/(\w+)', 'data_\\1_\\2'),
    (r'^common/(\w+)/(\w+)', 'common_\\1_\\2'),
]


def snake(name):
    name = re.sub(r'\.ets$', '', name)
    name = re.sub(r'(?<=[a-z0-9])(?=[A-Z])', '_', name)
    name = re.sub(r'[^A-Za-z0-9]+', '_', name)
    return name.strip('_').lower()


def prefix_for(rel_path):
    for pattern, replacement in PREFIX_RULES:
        match = re.match(pattern, rel_path)
        if match:
            base = replacement
            for index, group in enumerate(match.groups(), start=1):
                base = base.replace('\\' + str(index), snake(group))
            base = base.replace('\\', '_')
            return re.sub(r'[^a-z0-9_]+', '_', base.lower()).strip('_')
    return 'aira'


def load_locale(locale):
    path = os.path.join(RES, locale, 'element/string.json')
    with open(path, encoding='utf-8') as handle:
        return json.load(handle)


def save_locale(locale, data):
    path = os.path.join(RES, locale, 'element/string.json')
    with open(path, 'w', encoding='utf-8') as handle:
        handle.write(json.dumps(data, ensure_ascii=False, indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--keys', required=True)
    parser.add_argument('--translations', required=True)
    parser.add_argument('--prefix-out', required=True)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()

    rows = []
    with open(args.keys, encoding='utf-8') as handle:
        for line in handle:
            line = line.rstrip('\n')
            if not line:
                continue
            parts = line.split('\t')
            if len(parts) != 2:
                print(f'bad keys row: {line!r}', file=sys.stderr)
                return 2
            rows.append((parts[0], parts[1]))

    translations = {}
    with open(args.translations, encoding='utf-8') as handle:
        for line in handle:
            line = line.rstrip('\n')
            if not line:
                continue
            chinese, _, english = line.partition('\t')
            translations[chinese] = english

    missing = sorted({c for _f, c in rows if c not in translations})
    if missing:
        print(f'{len(missing)} literal(s) have no translation:', file=sys.stderr)
        for value in missing[:30]:
            print(f'  {value}', file=sys.stderr)
        return 1

    base = load_locale('base')
    existing_names = {entry['name'] for entry in base['string']}
    existing_values = {entry.get('value'): entry['name'] for entry in base['string']}

    mapping = {}
    counters = {}
    for rel_path, chinese in rows:
        if chinese in mapping:
            continue
        if chinese in existing_values:
            mapping[chinese] = existing_values[chinese]
            continue
        prefix = prefix_for(rel_path)
        counters[prefix] = counters.get(prefix, 0) + 1
        name = f'{prefix}_{counters[prefix]:03d}'
        while name in existing_names:
            counters[prefix] += 1
            name = f'{prefix}_{counters[prefix]:03d}'
        existing_names.add(name)
        mapping[chinese] = name

    with open(args.prefix_out, 'w', encoding='utf-8') as handle:
        for chinese, name in mapping.items():
            handle.write(f'{name}\t{chinese}\t{translations[chinese]}\n')

    reused = sum(1 for c in mapping if c in existing_values)
    print(f'{len(mapping)} literal(s): {len(mapping) - reused} new key(s), {reused} reuse an existing key')

    if not args.apply:
        print(f'wrote mapping to {args.prefix_out} (dry run)')
        return 0

    for locale in ('base', 'zh_CN', 'zh_Hant', 'en_US'):
        data = load_locale(locale)
        names = {entry['name'] for entry in data['string']}
        added = 0
        for chinese, name in mapping.items():
            if name in names:
                continue
            value = chinese if locale != 'en_US' else translations[chinese]
            data['string'].append({'name': name, 'value': value})
            names.add(name)
            added += 1
        save_locale(locale, data)
        print(f'  {locale}: +{added} -> {len(data["string"])} entries')
    return 0


if __name__ == '__main__':
    sys.exit(main())
