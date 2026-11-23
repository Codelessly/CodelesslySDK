#!/usr/bin/env python3
"""The notation's own words on every Cards component, whatever it was made from.

SSUI's components come with SSUI's names (a `placeholder`, sizes `sm`, `md`, `lg`, a tone `error`); a block
designed on demand and kept in components/ has the names of the day it was written. A writer learns one word for
each thing from the notation, so build.py runs this last, over every component document:

- a tone is `info`, `success`, `warning`, `danger` or `neutral` (`error`, `critical` and `bad` are `danger`,
  `good` is `success`, `warn` is `warning`); a tone the scale lacks (`accent`, `primary`, a palette) is kept;
- a size is `small`, `medium` or `large` (`sm`, `md`, `lg`);
- a field's `placeholder` is its `hint`, its `keyboard` its `type` (`emailAddress` is `email`), `obscure` is
  `password`: the names and values an `Input` has.

The prop, its values, its default, its previews, every formula of the component that reads it, and every other
component that draws it with a value written out follow. It changes nothing in a document that is already in
these words, so it is safe on its own output.

    python3 design_systems/cards/tool/core_words.py      # applies it to components/ in place
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

TONES = {'error': 'danger', 'critical': 'danger', 'bad': 'danger', 'good': 'success', 'warn': 'warning'}
SIZES = {'sm': 'small', 'md': 'medium', 'lg': 'large'}
KEYBOARDS = {'emailAddress': 'email'}
# A prop under another name than the notation's, by its old name (in order: a name freed first).
KEYS = [('placeholder', 'hint'), ('searchPlaceholder', 'searchHint'), ('keyboard', 'type'), ('obscure', 'password')]
# A prop that already has the name another is to take, and what it is called instead.
MOVED = {('PromptInput', 'hint'): 'note'}
# A tone by another prop's name.
TONE_PROPS = {'tone', 'avatarTone'}
ALSO_TONES = {('StatusDot', 'status')}


def _strings(x, f, path=()):
    """[x] with every string in it replaced by f(string, path)."""
    if isinstance(x, dict):
        return {k: _strings(v, f, path + (k,)) for k, v in x.items()}
    if isinstance(x, list):
        return [_strings(v, f, path + (i,)) for i, v in enumerate(x)]
    return f(x, path) if isinstance(x, str) else x


def _words(text, names):
    return re.sub(r'\b(%s)\b' % '|'.join(map(re.escape, names)), lambda m: names[m.group(1)], text)


def plan(name, doc):
    """What [doc] renames: its props' keys (old to new, in order) and, by a prop's old key, its values."""
    props = doc.get('widget', {}).get('props', [])
    have = {p['key'] for p in props}
    keys = []
    for old, new in KEYS:
        if old not in have:
            continue
        if new in have:
            moved = MOVED.get((name, new))
            if moved is None or moved in have:
                raise SystemExit(f'core_words: {name} has both {old} and {new}: say in MOVED what {new} becomes')
            keys.append((new, moved))
        keys.append((old, new))
    values = {}
    text = json.dumps(doc)
    for p in props:
        key, declared = p['key'], p.get('type', {}).get('values') or []
        if key in TONE_PROPS or (name, key) in ALSO_TONES:
            used = set(declared) | set(re.findall(r"props\.%s\s*[=!]=\s*'([A-Za-z]+)'" % key, text))
            if used & set(TONES):
                values[key] = TONES
        elif key == 'size' and set(declared) & set(SIZES):
            values[key] = SIZES
        elif key == 'keyboard' and set(declared) & set(KEYBOARDS):
            values[key] = KEYBOARDS
    return keys, values


def own(name, doc):
    """[doc] in the notation's words, and what it renamed (its plan)."""
    keys, values = plan(name, doc)
    if not keys and not values:
        return doc, (keys, values)

    def formula(s, path):
        if path[:1] == ('widget',):
            return s
        for key, names in values.items():
            s = re.sub(r"(props\.%s\s*[=!]=\s*)'(%s)'" % (key, '|'.join(names)), lambda m: "%s'%s'" % (m.group(1), names[m.group(2)]), s)
        for old, new in keys:
            s = re.sub(r'\bprops\.%s\b' % old, 'props.' + new, s)
        return s

    doc = _strings(doc, formula)
    widget = doc['widget']
    for p in widget.get('props', []):
        names = values.get(p['key'])
        if names:
            declared = p.get('type', {}).get('values')
            if declared:
                p['type']['values'] = list(dict.fromkeys(names.get(v, v) for v in declared))
            if isinstance(p.get('default'), str):
                p['default'] = names.get(p['default'], p['default'])
            if 'doc' in p:
                p['doc'] = _words(p['doc'], names)
    for old, new in keys:
        for p in widget.get('props', []):
            if p['key'] == old:
                p['key'] = new
    # The line a component is taught by, and what it says of itself.
    spoken = {}
    for key, names in values.items():
        if names is not TONES:
            spoken.update(names)
        else:
            spoken.update({'%s=%s' % (key, a): '%s=%s' % (key, b) for a, b in names.items()})
            spoken.update({'%s="%s"' % (key, a): '%s="%s"' % (key, b) for a, b in names.items()})
    for field in ('doc', 'signature', 'example'):
        if isinstance(widget.get(field), str):
            text = widget[field]
            for a, b in spoken.items():
                text = re.sub(r'(?<![A-Za-z0-9_])%s(?![A-Za-z0-9_])' % re.escape(a), b, text)
            # Its tones listed in a sentence (`tone neutral, accent, warn or good colors the dot`).
            if any(names is TONES for names in values.values()):
                text = re.sub(r'[Tt]one[^.]*', lambda m: _words(m.group(0), TONES), text)
            for old, new in keys:
                text = re.sub(r'(?<![A-Za-z0-9_.])%s(?==)' % old, new, text)
            widget[field] = text
    for preview in doc.get('previews', []):
        given = preview.get('props', {})
        for key, names in values.items():
            if isinstance(given.get(key), str):
                given[key] = names.get(given[key], given[key])
        for old, new in keys:
            if old in given:
                given[new] = given.pop(old)
    # A keyboard by the notation's name is the document's own where the field reads it.
    for node in doc.get('nodes', {}).values():
        bind = node.get('bind') if isinstance(node, dict) else None
        if bind and bind.get('props.keyboardType') == '${props.type}' and 'keyboard' in values:
            bind['props.keyboardType'] = "${= props.type == 'email' ? 'emailAddress' : props.type}"
    return doc, (keys, values)


def uses(doc, plans):
    """[doc] where it draws another component with a prop or a value that component renamed."""
    for node in doc.get('nodes', {}).values():
        if not isinstance(node, dict) or node.get('type') not in plans:
            continue
        keys, values = plans[node['type']]
        given, bind = node.get('props'), node.get('bind')
        for key, names in values.items():
            if isinstance(given, dict) and isinstance(given.get(key), str):
                given[key] = names.get(given[key], given[key])
            if isinstance(bind, dict) and isinstance(bind.get('props.' + key), str):
                bind['props.' + key] = re.sub(r"'(%s)'" % '|'.join(names), lambda m: "'%s'" % names[m.group(1)], bind['props.' + key])
        for old, new in keys:
            if isinstance(given, dict) and old in given:
                given[new] = given.pop(old)
            if isinstance(bind, dict) and 'props.' + old in bind:
                bind['props.' + new] = bind.pop('props.' + old)
    return doc


def apply(root=ROOT, quiet=True):
    folder = f'{root}/components'
    docs, plans = {}, {}
    for f in sorted(os.listdir(folder)):
        if not f.endswith('.json'):
            continue
        with open(f'{folder}/{f}', encoding='utf-8') as file:
            before = json.load(file)
        name = f[:-5]
        after, renamed = own(name, json.loads(json.dumps(before)))
        docs[name] = (before, after)
        if renamed[0] or renamed[1]:
            plans[name] = renamed
    changed = []
    for name, (before, after) in docs.items():
        after = uses(after, plans)
        if after != before:
            with open(f'{folder}/{name}.json', 'w', encoding='utf-8') as file:
                json.dump(after, file, indent=1, ensure_ascii=False)
                file.write('\n')
            changed.append(name)
    if not quiet:
        for name in changed:
            keys, values = plans.get(name, ([], {}))
            print(name, ', '.join(['%s -> %s' % k for k in keys] + ['%s: %s' % (k, '/'.join(v)) for k, v in values.items()]) or 'follows a component it draws')
    return changed


if __name__ == '__main__':
    apply(quiet=False)
