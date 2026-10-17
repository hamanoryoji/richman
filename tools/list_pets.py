import re, sys

path = sys.argv[1]
txt = open(path, encoding='utf-8', errors='replace').read()
pets = []
for block in txt.split('[PROP]'):
    d = {}
    for line in block.splitlines():
        m = re.match(r'^\s*([A-Za-z0-9_]+)\s*=\s*(.*)$', line)
        if m:
            d[m.group(1)] = m.group(2).strip()
    if d.get('part') == 'PET':
        pets.append(d)

print('PET items:', len(pets))
print(f"{'indx':>5} {'enable':>6} {'saleLJ':>6} {'priceLJ':>7} {'priceLR':>8} {'level':>5}  name")
for p in pets:
    print('%5s %6s %6s %7s %8s %5s  %s' % (
        p.get('indx', ''), p.get('enable', ''), p.get('saleLJ', ''),
        p.get('priceLJ', ''), p.get('priceLR', ''), p.get('level', ''),
        p.get('name', '')[:14]))
