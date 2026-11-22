"""The page words: the parts of an app window (a sidebar's items, a page's head, a panel, a list's row, what acts
on chosen rows), written in the notation and drawn with the Cards tokens.

    tool/page_words/components/<Name>.txt   the sources, one component each (the notation)
    tool/page_words/built/<Name>.json       each source expanded, kept beside them
    tool/page_words/built/sources.sha       what the sources were when they were last expanded

build.py copies built/*.json into components/ after the blocks and the repairs (a page word of the same name as
one of SSUI's components replaces it) and lists them in the manifest. The sources are expanded again only when
one of them changed (`tool/notation/notation.sh expand design_systems/cards/tool/page_words --no-reflow`, a fifth
of a second), so a build with nothing changed starts no other tool; where the notation's tool cannot run (a copy
of the folder elsewhere), the built documents are used as they are and the build says so.

    python3 design_systems/cards/tool/page_words.py     # expands the sources now, whatever the hash says
"""
import hashlib
import json
import os
import shutil
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, 'page_words')
BUILT = os.path.join(SRC, 'built')
SHA = os.path.join(BUILT, 'sources.sha')
# The sources that last failed to expand (not kept in git): the same ones are not tried again for a minute, so a
# notation tool that does not run for a while costs a build its seconds once, not every time.
FAILED = os.path.join(BUILT, '.failed')


def names():
    """The page words, by their sources."""
    folder = os.path.join(SRC, 'components')
    if not os.path.isdir(folder):
        return []
    return sorted(f[:-4] for f in os.listdir(folder) if f.endswith('.txt'))


def _hash():
    h = hashlib.sha256()
    for name in names():
        with open(os.path.join(SRC, 'components', name + '.txt'), 'rb') as f:
            h.update(name.encode() + b'\0' + f.read().replace(b'\r\n', b'\n') + b'\0')
    return h.hexdigest()


def stale():
    """Whether a source changed since the built documents were written, or one of them is missing."""
    try:
        with open(FAILED, encoding='utf-8') as f:
            if f.read().strip() == _hash() and time.time() - os.path.getmtime(FAILED) < 60:
                return False
    except OSError:
        pass
    if any(not os.path.exists(os.path.join(BUILT, n + '.json')) for n in names()):
        return True
    try:
        with open(SHA, encoding='utf-8') as f:
            return f.read().strip() != _hash()
    except OSError:
        return True


def _bash():
    for candidate in (os.environ.get('CODELESSLY_BASH'), r'C:\Program Files\Git\bin\bash.exe', shutil.which('bash')):
        if candidate and os.path.exists(candidate):
            return candidate
    return None


def expand(sdk):
    """Expands every source to built/<Name>.json. True when it did; False (and why, on stderr) when it could not,
    which leaves the built documents as they were."""
    tool = os.path.join(sdk, 'tool', 'notation', 'notation.sh')
    bash = _bash()
    if not os.path.exists(tool) or bash is None:
        print('page words: the sources changed but the notation tool is not here; using the built documents as they are',
              file=sys.stderr)
        return False
    os.makedirs(BUILT, exist_ok=True)
    site = {'schema': 3, 'pages': [], 'designSystem': '../../', 'components': [f'built/{n}.json' for n in names()]}
    with open(os.path.join(SRC, 'site.json'), 'w', encoding='utf-8', newline='\n') as f:
        json.dump(site, f, indent=1)
        f.write('\n')
    before = _hash()
    run = subprocess.run([bash, tool.replace('\\', '/'), 'expand', SRC.replace('\\', '/'), '--no-reflow', '--no-record'],
                         capture_output=True, text=True, encoding='utf-8', errors='replace')
    said = (run.stdout or '') + (run.stderr or '')
    # One line per source (`components/Name.txt -> built/Name.json`, with `(n issues)` when it has any). A word
    # the notation also has as a frame of a page (Panel) is said on a line of its own and makes the exit status 1:
    # a design system's component of that name is the one a page calls, so that is no failure here.
    wrote = [line for line in said.splitlines() if ' -> ' in line]
    clean = {line.split(' -> ')[1].strip() for line in wrote if 'issue' not in line}
    if run.returncode not in (0, 1) or any(f'page_words/built/{n}.json' not in clean for n in names()):
        print('page words: the sources did not expand cleanly; using the built documents as they were\n' + said.strip(),
              file=sys.stderr)
        with open(FAILED, 'w', encoding='utf-8', newline='\n') as f:
            f.write(before + '\n')
        return False
    if os.path.exists(FAILED):
        os.remove(FAILED)
    for f in os.listdir(BUILT):
        if f.endswith('.json') and f[:-5] not in names():
            os.remove(os.path.join(BUILT, f))
    with open(SHA, 'w', encoding='utf-8', newline='\n') as f:
        f.write(before + '\n')
    return True


def install(root):
    """Copies the built documents into [root]/components and returns their manifest entries, in name order."""
    out = []
    for name in names():
        built = os.path.join(BUILT, name + '.json')
        if not os.path.exists(built):
            continue
        with open(built, encoding='utf-8') as f:
            doc = json.load(f)
        with open(os.path.join(root, 'components', name + '.json'), 'w', encoding='utf-8', newline='\n') as f:
            json.dump(doc, f, indent=1, ensure_ascii=False)
            f.write('\n')
        out.append(f'components/{name}.json')
    return out


if __name__ == '__main__':
    sdk = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
    sys.exit(0 if expand(sdk) else 1)
