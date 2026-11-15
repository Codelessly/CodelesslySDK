#!/usr/bin/env python3
"""Counts, over a folder of elicited answers (tool/values/elicit.py), how many use each way of writing state,
values, actions, conditions and repetition.

    python3 tool/values/tally.py <dir>
"""
import glob, os, re, sys

WAYS = [
    ('STATE', [
        ('declared: state x=…', r'(?m)^\s*state\s+\w+\s*='),
        ('declared: let / var / const', r'(?m)^\s*(let|var|const)\s+\w+'),
        ('declared: x = … on a line of its own', r'(?m)^\s*[a-z]\w*\s*=\s*[^=\n]+$'),
        ('declared: a block (state: / State / vars)', r'(?mi)^\s*(state|vars|variables|data)\s*[:{]?\s*$'),
    ]),
    ('A VALUE FROM STATE', [
        ('key:name (bare)', r'\s[a-z]\w*:[a-z]\w*(\.\w+)*(?=\s|$)'),
        ('key:{name}', r'\s[a-z]\w*:\{[^{}"]+\}'),
        ('key:expression (no mark)', r'\s[a-z]\w*:!?[a-z]\w*(\.\w+|\[\w+\])*\s*(==|!=|>|<|\?|\+|-|\*|/|&&|\|\|)|\s[a-z]\w*:![a-z]\w*'),
        ('key:=expression', r'\s[a-z]\w*:='),
        ('=name (two-way)', r'\s=[a-z]\w*(?=\s|$)'),
        ('"…{expr}…" in text', r'"[^"\n]*\{[^{}"\n]+\}[^"\n]*"'),
        ('key:$name or ${…}', r':\$\{?\w'),
    ]),
    ('WHAT A TAP DOES', [
        ('-> actions', r'\s->\s'),
        ('onX(…assignment…)', r'\bon[A-Z]\w*\([^)\n]*=[^)\n]*\)'),
        ('onX: … / onX=…', r'\bon[A-Z]\w*\s*[:=]\s*\S'),
        ('{"on": …} JSON tail', r'\{\s*"on\w*"\s*:'),
        ('on tap / on press line', r'(?mi)^\s*on\s+(tap|press|click|change)'),
    ]),
    ('HOW STATE CHANGES', [
        ('x = !x / x = value', r'\b[a-z]\w*\s*=\s*(!|true|false|"|\d|[a-z])'),
        ('x += 1 / x++ (in place)', r'\+=|\+\+|-='),
        ('list[i] = / list[i] += (in place)', r'\w+\[[^\]\n]+\]\s*(\+?=)(?!=)'),
        ('new list: map / with / append', r'\b(map|with|append|updateWhere|filter)\('),
    ]),
    ('SHOWN ONLY SOMETIMES', [
        ('if cond (a line)', r'(?m)^\s*if\s+\S'),
        ('hidden: / visible: / show: (a key)', r'\b(hidden|visible|show|when):'),
        ('cond ? a : b inside', r'\?[^:\n]+:'),
    ]),
    ('REPEATED', [
        ('each x in list', r'(?m)^\s*each\s+\w+\s+in\s'),
        ('for x in list', r'(?m)^\s*for\s+\(?\w+'),
        ('repeat / forEach / map(… => node)', r'\b(repeat|forEach)\b'),
    ]),
    ('TIME', [
        ('every … / timer / interval', r'(?mi)\b(every\s+\d|timer|interval|tick)\b'),
    ]),
]


def main():
    files = sorted(f for f in glob.glob(os.path.join(sys.argv[1], '*.txt')) if not os.path.basename(f).startswith('_'))
    texts = [open(f).read() for f in files]
    print(f'{len(texts)} answers\n')
    for group, ways in WAYS:
        print(group)
        for label, pattern in ways:
            n = sum(bool(re.search(pattern, t)) for t in texts)
            print(f'  {n:2d}  {label}')
        print()


if __name__ == '__main__':
    main()
