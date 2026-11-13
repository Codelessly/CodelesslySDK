# Throwaway: rewrites Relay pricing (m05 c2 saas-landing-B) as a site of
# a page of section calls plus one document per component.
import json, os, re, sys, copy
src = sys.argv[1]; out = sys.argv[2]
d = json.load(open(src))
N = d['nodes']
V = {v['name']: v for v in d['variables']['pricing']}

def kids(n):
    x = N[n]; return list((x.get('slots') or {}).values()) + list(x.get('children') or [])
def sub(n):
    r = [n]
    for c in kids(n):
        if c in N: r += sub(c)
    return r

CALL_LAYOUT = {'width','height','flex','squeezable','constraints','margin','x','y','align','rotation','aspectRatio','widthFactor','heightFactor','order','basis'}

def rename_expr(s, mapping):
    """mapping: name -> replacement, inside ${...} only."""
    def fix(expr):
        # leave quoted strings alone
        parts = re.split(r"('(?:[^'\\]|\\.)*')", expr)
        for i in range(0, len(parts), 2):
            for k, v in mapping.items():
                parts[i] = re.sub(r'(?<![\w.$])' + re.escape(k) + r'(?![\w])', v, parts[i])
        return ''.join(parts)
    outp = []; i = 0
    while True:
        j = s.find('${', i)
        if j < 0: outp.append(s[i:]); break
        outp.append(s[i:j])
        depth = 0; k = j + 1
        while k < len(s):
            if s[k] == '{': depth += 1
            elif s[k] == '}':
                depth -= 1
                if depth == 0: break
            k += 1
        outp.append('${' + fix(s[j+2:k]) + '}'); i = k + 1
    return ''.join(outp)

def rename(v, mapping, var_mapping):
    if isinstance(v, dict):
        o = {}
        for k, x in v.items():
            if k == 'variable' and isinstance(x, str) and x in var_mapping:
                o[k] = var_mapping[x]
            else:
                o[k] = rename(x, mapping, var_mapping)
        return o
    if isinstance(v, list): return [rename(x, mapping, var_mapping) for x in v]
    if isinstance(v, str) and '${' in v: return rename_expr(v, mapping)
    return v

def split_root(root):
    """The root's size/placement (static, media, bound) goes to the call."""
    r = copy.deepcopy(root)
    call_layout = {k: v for k, v in (r.get('layout') or {}).items() if k in CALL_LAYOUT}
    r['layout'] = {k: v for k, v in (r.get('layout') or {}).items() if k not in CALL_LAYOUT}
    if not r['layout']: r['layout'] = {'width': call_layout.get('width', 0), 'height': call_layout.get('height', 0)}
    else:
        r['layout'] = {**{k: call_layout[k] for k in ('width','height') if k in call_layout}, **r['layout']}
    call_media = []; root_media = []
    for m in r.get('media', []):
        lay = (m.get('patch') or {}).get('layout') or {}
        cl = {k: v for k, v in lay.items() if k in CALL_LAYOUT}
        rest = {k: v for k, v in lay.items() if k not in CALL_LAYOUT}
        if cl:
            call_media.append({**{k: v for k, v in m.items() if k != 'patch'}, 'patch': {'layout': cl}})
        patch = {k: v for k, v in m['patch'].items() if k != 'layout'}
        if rest: patch['layout'] = rest
        if patch: root_media.append({**{k: v for k, v in m.items() if k != 'patch'}, 'patch': patch})
    if 'media' in r:
        if root_media: r['media'] = root_media
        else: del r['media']
    call_bind = {k: v for k, v in (r.get('bind') or {}).items() if k.startswith('layout.') and k.split('.')[1].split('[')[0] in CALL_LAYOUT}
    if 'bind' in r:
        r['bind'] = {k: v for k, v in r['bind'].items() if k not in call_bind}
        if not r['bind']: del r['bind']
    return r, call_layout, call_media, call_bind

def prop(key, kind, default, **extra):
    t = {'kind': kind, **extra}
    return {'key': key, 'type': t, 'default': default}

def var_prop(key, of):
    return {'key': key, 'type': {'kind': 'variable', 'of': {'kind': of}}, 'default': ''}

components = {}
def component(type_, root, *, doc, props=(), events=(), own_vars=(), mapping={}, var_mapping={}, nodes=None, exclude=()):
    ids = nodes if nodes is not None else sub(root)
    ns = {}
    for i in ids:
        if i in exclude: continue
        n = N[i] if not isinstance(i, tuple) else i[1]
        ns[i] = rename(n, mapping, var_mapping)
    r, cl, cm, cb = split_root(ns[root])
    ns[root] = r
    w = {'type': type_, 'doc': doc, 'props': list(props)}
    if events: w['events'] = list(events)
    doc_ = {'schema': 2, 'id': type_, 'roots': [root], 'widget': w}
    if own_vars: doc_['variables'] = {root: [V[v] for v in own_vars]}
    doc_['nodes'] = ns
    components[type_] = doc_
    return cl, cm, cb

def call(type_, cl, cm, cb, props=None, bind=None, extra=None):
    n = {'type': type_, 'layout': cl}
    if props: n['props'] = props
    b = {**(cb or {}), **(bind or {})}
    if b: n['bind'] = b
    if cm: n['media'] = cm
    if extra: n.update(extra)
    return n

calls = {}
# Header and menu share the page's menuOpen.
cl, cm, cb = component('SiteHeader', 'hdr', doc='The site header: logo, navigation at desktop, a menu button below it.',
    props=[var_prop('menuOpen', 'boolean')], mapping={'menuOpen': 'props.menuOpen'}, var_mapping={'menuOpen': 'props.menuOpen'})
calls['header'] = call('SiteHeader', cl, cm, cb, props={'menuOpen': 'menuOpen'})
cl, cm, cb = component('MobileMenu', 'menu', doc='The full-screen menu below desktop, open while menuOpen holds.',
    props=[var_prop('menuOpen', 'boolean')], mapping={'menuOpen': 'props.menuOpen'}, var_mapping={'menuOpen': 'props.menuOpen'})
calls['menu'] = call('MobileMenu', cl, cm, cb, props={'menuOpen': 'menuOpen'})
cl, cm, cb = component('PricingHero', 'hero', doc='The pricing hero: headline, intro and the billing toggle, which writes annual.',
    props=[var_prop('annual', 'boolean')], mapping={'annual': 'props.annual'}, var_mapping={'annual': 'props.annual'})
calls['hero'] = call('PricingHero', cl, cm, cb, props={'annual': 'annual'})

# The plan card: one component, the plans grid's item template.
pc = sub('pc'); feats = set(sub('pcFeats')) - {'pcFeats'}
card_nodes = {}
for i in pc:
    m = {'annual': 'props.annual', 'seats': 'props.seats'}
    if i not in feats: m['item'] = 'props.plan'
    card_nodes[i] = rename(N[i], m, {})
pr, pcl, pcm, pcb = split_root(card_nodes['pc'])
card_nodes['pc'] = pr
components['PlanCard'] = {'schema': 2, 'id': 'PlanCard', 'roots': ['pc'],
    'widget': {'type': 'PlanCard', 'doc': 'One pricing plan: name, price for the billing period, the estimate for the seats, call to action, features.',
               'props': [prop('plan', 'json', {}, flutter='Plan'), prop('annual', 'boolean', False, flutter='bool'), prop('seats', 'integer', 10, flutter='int', min=1)]},
    'previews': [{'name': 'Team, annual', 'size': [432, 980], 'props': {'plan': V['plans']['value'][1], 'annual': True, 'seats': 10}}],
    'nodes': card_nodes}
card_call = call('PlanCard', pcl, pcm, pcb, bind={'props.plan': '${item}', 'props.annual': '${props.annual}', 'props.seats': '${seats}'})
plan_ids = [i for i in sub('plansSec') if i not in pc]
cl, cm, cb = component('PlansSection', 'plansSec', doc='The seat estimator, the plan cards, the enterprise row and the disclaimer.',
    props=[var_prop('annual', 'boolean')], own_vars=['seats', 'seatsText', 'seatsValid'],
    mapping={'annual': 'props.annual'}, var_mapping={'annual': 'props.annual'}, nodes=plan_ids)
components['PlansSection']['nodes']['pc'] = card_call
calls['plans'] = call('PlansSection', cl, cm, cb, props={'annual': 'annual'})

cl, cm, cb = component('CompareSection', 'cmpSec', doc='The plan comparison table, wide and narrow.')
calls['compare'] = call('CompareSection', cl, cm, cb)

# The FAQ: its own open items; one FaqItem per question.
fq = sub('fq')
item_nodes = {i: rename(N[i], {'item': 'props.item', 'index': 'props.index', 'faqOpen': 'props.open'}, {'faqOpen': 'props.open'}) for i in fq}
fr, fcl, fcm, fcb = split_root(item_nodes['fq'])
item_nodes['fq'] = fr
components['FaqItem'] = {'schema': 2, 'id': 'FaqItem', 'roots': ['fq'],
    'widget': {'type': 'FaqItem', 'doc': 'One question; tapping it opens or closes its answer in the open list.',
               'props': [prop('item', 'json', {}, flutter='Faq'), prop('index', 'integer', 0, flutter='int'), var_prop('open', 'list')]},
    'nodes': item_nodes}
faq_ids = [i for i in sub('faqSec') if i not in fq]
cl, cm, cb = component('FaqSection', 'faqSec', doc='Questions and answers in two columns from tablet up; several may be open.',
    own_vars=['faqOpen'], nodes=faq_ids)
components['FaqSection']['nodes']['fq'] = call('FaqItem', fcl, fcm, fcb, props={'open': 'faqOpen'}, bind={'props.item': '${item}', 'props.index': '${index}'})
calls['faq'] = call('FaqSection', cl, cm, cb)

cl, cm, cb = component('FinalCta', 'ctaSec', doc='The closing call to action.')
calls['cta'] = call('FinalCta', cl, cm, cb)
cl, cm, cb = component('SiteFooter', 'foot', doc='The footer: brand, link columns, bottom bar.')
calls['footer'] = call('SiteFooter', cl, cm, cb)

order = {'hdr': 'header', 'hero': 'hero', 'plansSec': 'plans', 'cmpSec': 'compare', 'faqSec': 'faq', 'ctaSec': 'cta', 'foot': 'footer'}
page_nodes = {
    'pricing': N['pricing'],
    'root': {**N['root'], 'children': ['page', 'menu']},
    'page': {**N['page'], 'children': [order[c] for c in N['page']['children']]},
    **calls,
}
page = {'schema': 2, 'id': 'pricing', 'roots': ['pricing'],
        'variables': {'pricing': [V['annual'], V['menuOpen']]}, 'nodes': page_nodes}
content = ['billing', 'estimator', 'plans', 'cmp', 'faqs', 'footer', 'menuLinks']
site = {'schema': 2, 'pages': ['pages/pricing.json'], 'variables': [V[v] for v in content]}
if 'breakpoints' in d: site['breakpoints'] = d['breakpoints']

os.makedirs(f'{out}/pages', exist_ok=True); os.makedirs(f'{out}/components', exist_ok=True)
def write(path, j):
    with open(f'{out}/{path}', 'w') as f: json.dump(j, f, indent=1, ensure_ascii=False); f.write('\n')
write('site.json', site)
write('pages/pricing.json', page)
for t, c in components.items(): write(f'components/{t}.json', c)
# Counts.
def mini(j): return len(json.dumps(j, separators=(',', ':'), ensure_ascii=False).encode())
print('before', len(N), 'nodes', mini(d), 'min bytes', os.path.getsize(src), 'pretty')
total_n = len(page_nodes); total_b = mini(site) + mini(page)
rows = [('site.json', 0, mini(site), os.path.getsize(f'{out}/site.json')), ('pages/pricing.json', len(page_nodes), mini(page), os.path.getsize(f'{out}/pages/pricing.json'))]
for t, c in components.items():
    rows.append((f'components/{t}.json', len(c['nodes']), mini(c), os.path.getsize(f'{out}/components/{t}.json')))
    total_n += len(c['nodes']); total_b += mini(c)
for r in rows: print(*r)
print('after', total_n, 'nodes', total_b, 'min bytes', sum(r[3] for r in rows), 'pretty')
