"""hoist.py <answers folder> <out folder>

For answers written with the self-defining prompt (JOURNAL.md, review 3, D14): an answer defines the words it
invents in `define` blocks, usually after its last screen. The vocabulary tool expands each `### screen` on its
own and reads a definition only before its use, so this copies every answer with all of its `define` blocks
repeated at the head of each screen. It also prints, per answer, how many blocks it found. (To be folded into the
tool: a definition anywhere in an answer should hold for all of its screens.)"""
import io, pathlib, re, sys

src, out = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)
total = 0
for f in sorted(src.glob('*.txt')):
    lines = f.read_text(encoding='utf-8').splitlines()
    blocks, rest, i = [], [], 0
    while i < len(lines):
        if lines[i].startswith('define '):
            j = i + 1
            while j < len(lines) and (lines[j].startswith(' ') or lines[j].strip() == ''):
                j += 1
            # a comment line just above the block belongs to it
            lead = []
            while rest and rest[-1].startswith('//'):
                lead.insert(0, rest.pop())
            blocks.append(lead + [l for l in lines[i:j] if l.strip() != ''])
            i = j
        else:
            rest.append(lines[i])
            i += 1
    head = [l for b in blocks for l in b + ['']]
    res = []
    seen_screen = False
    for l in rest:
        res.append(l)
        if re.match(r'^###\s+\S', l):
            seen_screen = True
            res.extend(head)
    if not seen_screen:
        res = head + res
    (out / f.name).write_text('\n'.join(res) + '\n', encoding='utf-8')
    total += len(blocks)
    print(f'{f.stem}: {len(blocks)} definitions: ' + ', '.join(b[len([x for x in b if x.startswith("//")])].split()[1].split('#')[0].split('.')[0] for b in blocks))
print(total, 'definitions in', len(list(src.glob('*.txt'))), 'answers')
