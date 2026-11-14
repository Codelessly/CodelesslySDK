#!/usr/bin/env python3
"""Builds the session screen's sites and pictures (called by build.py; runs alone too).

    python3 examples/prompt_app/polish/tool/session.py [--round r2]

session/default   session.blocks.txt expanded by the notation tool, under design_systems/skip
session/pink      the same document, themes/pink.json in site.json
session/athlete   the same document, themes/athlete.json
session/kid       session.kid.blocks.txt (audience:"kid", other copy) on the pink set

Every state is reached by driving the screen as a person would: the render tool taps Start, lets time pass, taps
the pad, Pause and Finish. Nothing is set from outside, so each capture is also a test that the screen runs.
--round keeps a sheet of the default states as renders/session-<round>.png.
"""
import json
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build as b  # noqa: E402

POLISH, APP, SKIP = b.POLISH, b.APP, b.SKIP
DS = '../../../../../design_systems/skip'

taps = lambda node, n: [x for _ in range(n) for x in ('--tap', node)]
START = ['--tap', 'start/btn']
# Each step settles for about a second of the screen's own time, so taps move the clock too.
STATES = {
    'ready': [],
    'set': START,
    # the count-in, two whole rounds, then into round 3 while tapping: 6 x +10 and 14 single jumps per round or so
    'work': START + ['--wait', '3000', '--wait', '104000'] + taps('pad/plus', 17) + taps('pad/pad', 9) + ['--tap', 'pad/minus'],
    'rest': START + ['--wait', '3000', '--wait', '140000'] + taps('pad/plus', 26) + taps('pad/pad', 4),
    'paused': START + ['--wait', '3000', '--wait', '104000'] + taps('pad/plus', 17) + taps('pad/pad', 9)
              + ['--tap', 'controls/toggle', '--wait', '6000'],
    # all eight rounds run out by themselves (3 + 8 x 40 + 7 x 20 s), with a record's worth of taps on the way
    'finished': START + ['--wait', '150000'] + taps('pad/plus', 134) + taps('pad/pad', 7) + ['--wait', '200000'],
    # stopped early with Finish: no record, fewer rounds
    'finished-early': START + ['--wait', '3000', '--wait', '104000'] + taps('pad/plus', 17) + ['--tap', 'controls/finish', '--wait', '2000'],
}


def shot(site, state, name, tmp):
    b.render(site, f'{tmp}/{name}', extra=('--label', state, *STATES[state]))
    out = f'{POLISH}/renders/{name}-{state}.png'
    shutil.copy(f'{tmp}/{name}/session@390x844-{state}.png', out)
    return out


def main(rebuild=True):
    args = sys.argv[1:]
    if rebuild:
        import subprocess
        subprocess.run([sys.executable, f'{SKIP}/tool/build.py'], check=True)
    rnd = args[args.index('--round') + 1] if '--round' in args else None
    renders, tmp = f'{POLISH}/renders', f'{POLISH}/.out-session'
    for name in ('default', 'kid'):
        os.makedirs(f'{POLISH}/session/{name}', exist_ok=True)
    b.expand(f'{POLISH}/session.blocks.txt', 'session', f'{POLISH}/session/default/session.json')
    b.expand(f'{POLISH}/session.kid.blocks.txt', 'session', f'{POLISH}/session/kid/session.json')
    for name in ('default', 'pink', 'athlete', 'kid'):
        site = f'{POLISH}/session/{name}'
        os.makedirs(site, exist_ok=True)
        if name in ('pink', 'athlete'):
            shutil.copy(f'{POLISH}/session/default/session.json', f'{site}/session.json')
        manifest = {'schema': 3, 'pages': ['session.json'], 'designSystem': DS}
        if name != 'default':
            manifest['theme'] = json.load(open(f'{SKIP}/themes/{"pink" if name == "kid" else name}.json'))
        b.write(f'{site}/site.json', manifest)

    default = {s: shot(f'{POLISH}/session/default', s, 'session', tmp)
               for s in ('ready', 'set', 'work', 'rest', 'paused', 'finished', 'finished-early')}
    b.montage([default[s] for s in ('ready', 'work', 'rest', 'paused', 'finished')],
              ['Ready (before Start)', 'Working, round 3', 'Resting', 'Paused', 'Finished, a record'], f'{renders}/session-states.png')
    if rnd:
        shutil.copy(f'{renders}/session-states.png', f'{renders}/session-{rnd}.png')
        if '--quick' in args:
            return
    pink = {s: shot(f'{POLISH}/session/pink', s, 'session-pink', tmp) for s in ('work', 'rest')}
    athlete = {s: shot(f'{POLISH}/session/athlete', s, 'session-athlete', tmp) for s in ('ready', 'work', 'rest', 'paused', 'finished')}
    kid = {s: shot(f'{POLISH}/session/kid', s, 'session-kid', tmp) for s in ('ready', 'work', 'rest', 'finished')}
    b.montage([default['work'], pink['work'], athlete['work']],
              ['Default tokens', 'Pink tokens (themes/pink.json)', 'Athlete tokens (themes/athlete.json)'], f'{renders}/session-variants.png')
    b.montage([default['rest'], pink['rest'], athlete['rest']],
              ['Rest: default tokens', 'Rest: pink tokens', 'Rest: athlete tokens'], f'{renders}/session-variants-rest.png')
    b.montage([athlete[s] for s in ('ready', 'work', 'rest', 'paused', 'finished')],
              ['Athlete: ready', 'Working', 'Resting', 'Paused', 'Finished'], f'{renders}/session-athlete-states.png')
    b.montage([kid[s] for s in ('ready', 'work', 'rest', 'finished')],
              ["A child's session: ready", 'Jumping', 'Breathing', 'Finished'], f'{renders}/session-kid-states.png')
    b.montage([f'{APP}/renders/session.beginner.png', default['work'], f'{APP}/renders/session.kid.png', kid['work'],
               f'{APP}/renders/session.athlete.png', athlete['work']],
              ['Before: beginner', 'After: beginner', 'Before: kid', 'After: kid', 'Before: athlete', 'After: athlete'],
              f'{renders}/session-before-after.png')
    shutil.rmtree(tmp, ignore_errors=True)


if __name__ == '__main__':
    main()
