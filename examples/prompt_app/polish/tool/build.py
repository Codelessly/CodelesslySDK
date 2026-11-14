#!/usr/bin/env python3
"""Builds everything under polish/: the bar screens, the block screens, the token variants, and the pictures.

    python3 examples/prompt_app/polish/tool/build.py [--round r3] [--skip-render]

bar/       Home and History as full documents with no component and no design system: the theme is in its
           site.json, every node is a core node. (Written here in Python as calls, then inlined by inline.py.)
blocks/    The same two screens from home.blocks.txt and history.blocks.txt, expanded by the notation tool and
           rendered under design_systems/skip.
variants/  The one Home document of blocks/ under three token sets: default, pink, athlete.
renders/   The captures and the side-by-side pictures. --round keeps the bar captures as bar-<screen>-<round>.png.
"""
import json
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
POLISH = os.path.dirname(HERE)
APP = os.path.dirname(POLISH)
SDK = os.path.dirname(os.path.dirname(APP))
SKIP = f'{SDK}/design_systems/skip'
sys.path.insert(0, HERE)
import inline  # noqa: E402

FILL, HUG = {'fill': 0}, {'hug': 0}
BLOCKS = ['Screen', 'TopBar', 'HeroSession', 'StreakFlame', 'ProgressGoal', 'WeekStrip', 'SectionTitle', 'SessionRow', 'ChartCard',
          'StatTrio', 'RecordCard', 'EmptyState', 'Illustration']


def emit(event, value=None):
    a = {'type': 'componentEvent', 'event': event}
    if value is not None:
        a['value'] = value
    return a


def call(type_, on=None, layout=None, children=None, **args):
    """A component call: arguments holding ${...} are bound, the rest are literal."""
    n = {'type': type_, 'layout': layout or {'width': FILL, 'height': HUG}}
    props = {k: v for k, v in args.items() if not (isinstance(v, str) and '${' in v)}
    bind = {f'props.{k}': v for k, v in args.items() if isinstance(v, str) and '${' in v}
    if props:
        n['props'] = props
    if bind:
        n['bind'] = bind
    if children:
        n['children'] = children
    if on:
        n['actions'] = [{'trigger': {'type': 'event', 'event': 'onPressed'}, 'actions': on}]
    return n


def variables(app, canvas):
    kind = lambda v: 'integer' if isinstance(v, int) else 'map' if isinstance(v, dict) else 'list' if isinstance(v, list) else 'text'
    return {canvas: [{'name': k, 'type': kind(v), 'value': v} for k, v in app['contract']['variables'].items()]}


def home_calls():
    return {
        'page': call('Screen', layout={'width': FILL, 'height': FILL},
                     children=['top', 'hero', 'tiles', 'week', 'lastTitle', 'last']),
        'top': call('TopBar', title='Ready to jump?', eyebrow='Skip',
                    subtitle='Short and steady wins. Today takes just ${today.minutes} minutes.'),
        'hero': call('HeroSession', title='${today.name}', minutes='${today.minutes}', cta="Start today's session",
                     detail='${today.rounds} easy rounds: jump for ${today.work} seconds, then rest for ${today.rest}.',
                     on=[emit('start_session')]),
        'tiles': {'type': 'row', 'children': ['streak', 'goal'], 'layout': {'width': FILL, 'height': HUG},
                  'props': {'spacing': 12, 'crossAxisAlignment': 'center'}},
        'streak': call('StreakFlame', layout={'width': FILL, 'height': 176}, count='${streak}', label='sessions in a row',
                       note='Jump today to make it ${= streak + 1}. Keep going.'),
        'goal': call('ProgressGoal', layout={'width': FILL, 'height': 176}, title='This week', done='${sessionsThisWeek}',
                     goal='${weeklyGoal}', note='${= weeklyGoal - sessionsThisWeek} more short ones to reach your goal.'),
        'week': call('WeekStrip', done='${= map(take(sessions, sessionsThisWeek), s => s.date)}', today='Sat'),
        'lastTitle': call('SectionTitle', title='Last session', action='See all', on=[emit('open_history')]),
        'last': call('SessionRow', title='${= sessions[0].name}', detail='${= sessions[0].date} · ${= sessions[0].minutes} min',
                     value='${= sessions[0].jumps}', unit='jumps', share='${= sessions[0].jumps / max(map(sessions, s => s.jumps))}',
                     on=[emit('open_session', '${= sessions[0].date}')]),
    }


def history_calls():
    return {
        'page': call('Screen', layout={'width': FILL, 'height': FILL},
                     children=['top', 'chart', 'trio', 'record', 'listTitle', 'list']),
        'top': call('TopBar', title='Your progress', back=True, subtitle='Your weekly total is climbing. Nice work.',
                    on=[emit('open_home')]),
        'chart': call('ChartCard', layout={'width': FILL, 'height': 356}, title='Jumps this week',
                      values='${= map(weeks, w => w.jumps)}', labels='${= map(weeks, w => w.label)}', unit='jumps',
                      deltaLabel='vs last week'),
        'trio': call('StatTrio', values='${= [sum(sessions, s => s.jumps), sum(sessions, s => s.minutes), length(sessions)]}',
                     labels=['Total jumps', 'Minutes', 'Sessions']),
        'record': call('RecordCard', title='Best run without a miss', value='${= maxBy(sessions, s => s.best).best}', unit='jumps in a row',
                       detail='${= maxBy(sessions, s => s.best).name} · ${= maxBy(sessions, s => s.best).date}',
                       on=[emit('open_session', '${= maxBy(sessions, s => s.best).date}')]),
        'listTitle': call('SectionTitle', title='Past sessions'),
        'list': {'type': 'listView', 'children': ['session'], 'layout': {'width': FILL, 'height': HUG},
                 'props': {'scrollable': False, 'spacing': 12}, 'bind': {'data': '${sessions}'}},
        'session': call('SessionRow', title='${item.name}', detail='${item.date} · ${item.minutes} min',
                        value='${item.jumps}', unit='jumps', share='${= item.jumps / max(map(sessions, s => s.jumps))}',
                        on=[emit('open_session', '${item.date}')]),
    }


def page(canvas, name, calls, app, components=None):
    nodes = {canvas: {'type': 'canvas', 'name': name, 'slots': {'body': 'page'}, 'layout': {'width': 390, 'height': 844},
                      'decoration': {'fills': [{'color': 'page'}]}}}
    nodes.update(inline.inline(calls, components) if components else calls)
    return {'schema': 3, 'roots': [canvas], 'variables': variables(app, canvas), 'nodes': nodes}


def write(path, value):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w') as f:
        json.dump(value, f, indent=1, ensure_ascii=False)
        f.write('\n')


def run(cmd, **k):
    env = {**os.environ, 'PATH': '/opt/flutter/bin:' + os.environ['PATH']}
    return subprocess.run(cmd, cwd=SDK, env=env, text=True, capture_output=True, **k)


def render(site, out, sizes='390x844', extra=()):
    r = run(['tool/render/render.sh', site, '--out', out, '--sizes', sizes, '--full-page', '--now', '2026-11-14T09:00:00Z', *extra])
    lines = [l for l in (r.stdout + r.stderr).splitlines() if l.startswith(('ERROR', 'WARNING', ' ')) or 'error(s)' in l]
    print(f'  render {os.path.relpath(site, POLISH)}: ' + (lines[-1] if lines else '(no summary)'))
    for l in lines[:-1][:24]:
        print('   ', l[:300])
    return r.returncode


def expand(txt, canvas, out, contract=True):
    merged = f'{POLISH}/blocks/.{canvas}.txt'
    os.makedirs(os.path.dirname(merged), exist_ok=True)
    with open(merged, 'w') as f:
        f.write((open(f'{APP}/screens/contract.txt').read() if contract else '') + open(txt).read())
    r = run(['tool/notation/notation.sh', 'expand', merged, '--design-system', 'design_systems/skip', '--id', canvas, '--out', out])
    os.remove(merged)
    issues = [l for l in r.stderr.splitlines() if 'line ' in l]
    print(f'  expand {os.path.basename(txt)}: {len(issues)} issue(s)')
    for l in issues:
        print('   ', l.split(': ', 1)[-1])
    return r.returncode


def diff(a, b):
    """The share of pixels that differ between two captures (None when their sizes differ)."""
    from PIL import Image, ImageChops
    x, y = Image.open(a).convert('RGB'), Image.open(b).convert('RGB')
    if x.size != y.size:
        return None
    d = ImageChops.difference(x, y).convert('L').point(lambda v: 255 if v > 8 else 0)
    return sum(d.histogram()[255:]) / (x.width * x.height)


def montage(images, labels, out, gap=28, pad=28, bg=(238, 237, 245), top=40):
    from PIL import Image, ImageDraw, ImageFont
    ims = [Image.open(i).convert('RGB') for i in images]
    w = sum(i.width for i in ims) + gap * (len(ims) - 1) + 2 * pad
    h = max(i.height for i in ims) + 2 * pad + top
    sheet = Image.new('RGB', (w, h), bg)
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype('/opt/flutter/bin/cache/artifacts/material_fonts/Roboto-Medium.ttf', 17)
    except OSError:
        font = ImageFont.load_default()
    x = pad
    for im, label in zip(ims, labels):
        draw.text((x, pad - 4), label, fill=(60, 56, 90), font=font)
        sheet.paste(im, (x, pad + top))
        x += im.width + gap
    sheet.save(out)
    print(f'  wrote {os.path.relpath(out, POLISH)}')


def main():
    args = sys.argv[1:]
    rnd = args[args.index('--round') + 1] if '--round' in args else None
    subprocess.run([sys.executable, f'{SKIP}/tool/build.py'], check=True)
    app = json.load(open(f'{APP}/app.json'))
    components = inline.load_components(f'{SKIP}/components', BLOCKS)
    renders = f'{POLISH}/renders'
    tmp = f'{POLISH}/.out'
    os.makedirs(renders, exist_ok=True)

    # 1. The bar: full documents, the theme in site.json, no design system.
    theme = json.load(open(f'{SKIP}/themes/default.json'))
    write(f'{POLISH}/bar/site.json', {'schema': 3, 'pages': ['home.json', 'history.json'], 'theme': theme})
    write(f'{POLISH}/bar/home.json', page('home', 'Home', home_calls(), app, components))
    write(f'{POLISH}/bar/history.json', page('history', 'Training history', history_calls(), app, components))
    if '--skip-render' in args:
        return
    render(f'{POLISH}/bar', f'{tmp}/bar')
    for s in ('home', 'history'):
        shutil.copy(f'{tmp}/bar/{s}@390x844.png', f'{renders}/bar-{s}.png')
        if rnd:
            shutil.copy(f'{tmp}/bar/{s}@390x844.png', f'{renders}/bar-{s}-{rnd}.png')

    # 2. The blocks: the notation, expanded and rendered under the design system.
    if os.path.exists(f'{POLISH}/home.blocks.txt'):
        write(f'{POLISH}/blocks/site.json', {'schema': 3, 'pages': ['home.json', 'history.json'],
                                              'designSystem': '../../../../design_systems/skip'})
        expand(f'{POLISH}/home.blocks.txt', 'home', f'{POLISH}/blocks/home.json')
        expand(f'{POLISH}/history.blocks.txt', 'history', f'{POLISH}/blocks/history.json')
        render(f'{POLISH}/blocks', f'{tmp}/blocks')
        for s in ('home', 'history'):
            shutil.copy(f'{tmp}/blocks/{s}@390x844.png', f'{renders}/blocks-{s}.png')
        montage([f'{renders}/bar-home.png', f'{renders}/blocks-home.png', f'{renders}/bar-history.png', f'{renders}/blocks-history.png'],
                ['Home: the bar (full document, no components)', 'Home: blocks (notation, design_systems/skip)',
                 'History: the bar', 'History: blocks'], f'{renders}/bar-vs-blocks.png')

        for sc in ('home', 'history'):
            d = diff(f'{renders}/bar-{sc}.png', f'{renders}/blocks-{sc}.png')
            print(f'  bar vs blocks, {sc}: ' + ('sizes differ' if d is None else f'{d * 100:.3f}% of pixels differ'))

        # 3. Variants: the one Home document under three token sets.
        shots = []
        for name in ('default', 'pink', 'athlete'):
            site = f'{POLISH}/variants/{name}'
            os.makedirs(site, exist_ok=True)
            shutil.copy(f'{POLISH}/blocks/home.json', f'{site}/home.json')
            shutil.copy(f'{POLISH}/blocks/history.json', f'{site}/history.json')
            manifest = {'schema': 3, 'pages': ['home.json', 'history.json'], 'designSystem': '../../../../../design_systems/skip'}
            if name != 'default':
                manifest['theme'] = json.load(open(f'{SKIP}/themes/{name}.json'))
            write(f'{site}/site.json', manifest)
            render(site, f'{tmp}/variants-{name}')
            for s in ('home', 'history'):
                shutil.copy(f'{tmp}/variants-{name}/{s}@390x844.png', f'{renders}/variant-{name}-{s}.png')
            shots.append(f'{renders}/variant-{name}-home.png')
        montage(shots, ['Default tokens', 'Pink tokens (themes/pink.json)', 'Athlete tokens (themes/athlete.json)'],
                f'{renders}/variants-home.png')
        montage([f'{renders}/variant-{n}-history.png' for n in ('default', 'pink', 'athlete')],
                ['Default tokens', 'Pink tokens', 'Athlete tokens'], f'{renders}/variants-history.png')

        # 4. Every block once, with the child's illustration set; and a child's Home on the pink tokens.
        subprocess.run([sys.executable, f'{HERE}/gallery.py'], check=True)
        expand(f'{POLISH}/gallery.blocks.txt', 'gallery', f'{POLISH}/gallery/gallery.json', contract=False)
        render(f'{POLISH}/gallery', f'{tmp}/gallery', extra=('--screen', 'gallery'))
        render(f'{POLISH}/gallery', f'{tmp}/gallery', sizes='800x1100', extra=('--screen', 'art'))
        shutil.copy(f'{tmp}/gallery/gallery@390x844.png', f'{renders}/gallery-blocks.png')
        shutil.copy(f'{tmp}/gallery/art@800x1100.png', f'{renders}/gallery-illustrations.png')
        kid = f'{POLISH}/variants/kid'
        os.makedirs(kid, exist_ok=True)
        expand(f'{POLISH}/home.kid.blocks.txt', 'home', f'{kid}/home.json')
        write(f'{kid}/site.json', {'schema': 3, 'pages': ['home.json'], 'designSystem': '../../../../../design_systems/skip',
                                   'theme': json.load(open(f'{SKIP}/themes/pink.json'))})
        render(kid, f'{tmp}/kid')
        shutil.copy(f'{tmp}/kid/home@390x844.png', f'{renders}/audience-kid-home.png')
        montage([f'{renders}/variant-default-home.png', f'{renders}/audience-kid-home.png'],
                ['Adult beginner: default tokens, adult illustrations', "A child: pink tokens, audience:\"kid\", other copy"],
                f'{renders}/audiences.png')
        montage([f'{APP}/renders/home.beginner.png', f'{renders}/blocks-home.png', f'{APP}/renders/history.beginner.png',
                 f'{renders}/blocks-history.png'],
                ['Before: Home (notation over SSUI)', 'After: Home (notation over Skip blocks)', 'Before: History', 'After: History'],
                f'{renders}/before-after.png')
    shutil.rmtree(tmp, ignore_errors=True)


if __name__ == '__main__':
    main()
