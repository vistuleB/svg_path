"""Compare both native targets against the preserved Paper.js assertions."""
import json
import math
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[2]
source = json.loads((root / 'scripts/paperjs/matrix.json').read_text())
fixtures = source['fixtures']
assert len(sys.argv) == 3, 'Pass Erlang and JavaScript probe logs'
reports = {}
for target, filename in zip(['erlang', 'javascript'], sys.argv[1:]):
    rows = []
    for line in Path(filename).read_text().splitlines():
        match = re.match(r'^(\d+):(.*)$', line)
        if not match:
            continue
        fixture = fixtures[int(match[1])]
        row = dict(id=fixture['id'], method=fixture['method'], message=fixture['message'], expected=fixture['expected'])
        try:
            angle, sx, sy = map(float, match[2].split(','))
            assert all(map(math.isfinite, [angle, sx, sy]))
            actual = angle if fixture['method'] == 'getRotation' else [sx, sy]
            row['actual'] = actual
            if isinstance(actual, list):
                error = max(abs(a - b) for a, b in zip(actual, fixture['expected']))
            else:
                error = abs(actual - fixture['expected'])
            if error <= 1e-10:
                status = 'match'
            elif fixture['method'] == 'getRotation' and fixture['expected'] == -180 and abs(actual - 180) <= 1e-10:
                status = 'equivalent-angle-endpoint'
            else:
                status = 'discrepancy'
            row.update(status=status, absoluteError=error, tolerance=1e-10)
        except (ValueError, AssertionError):
            row.update(status='library-error', raw=match[2])
        rows.append(row)
    assert [r['id'] for r in rows] == list(range(52)), f'Incomplete {target} output'
    reports[target] = rows
    print(target, {status: sum(r['status'] == status for r in rows) for status in sorted({r['status'] for r in rows})})
    print('Nonidentical expectations:', [r['id'] for r in rows if r['status'] != 'match'])
(root / 'scripts/paperjs/matrix-native-screening.json').write_text(json.dumps(reports, indent=2) + '\n')
blocks = []
for block in source['blocks']:
    ids = [f['id'] for f in fixtures if f['block'] == block['block']]
    rows = [row for target in reports.values() for row in target if row['id'] in ids]
    status = 'adapted-decomposition-match' if all(r['status'] in ['match', 'equivalent-angle-endpoint'] for r in rows) else 'unresolved-discrepancy'
    blocks.append(dict(block=block['block'], title=block['title'], status=status))
status = dict(blocks=blocks, preservedAssertions=52, comparedAssertions=52,
              targets=list(reports), comparisonReport='matrix-native-screening.json',
              convention='Gleam uses (-180,180]; Paper.js expects -180 in five assertions. Equivalent endpoints are classified explicitly, not counted as literal matches.',
              limitations='Upstream fixtures cover rotations, signed scales, and four rotation/scale combinations. They do not cover general shear, translation placement, singular matrices, or all 24 factor orders.')
(root / 'scripts/paperjs/matrix-status.json').write_text(json.dumps(status, indent=2) + '\n')
inventory_path = root / 'scripts/paperjs/inventory.json'
inventory = json.loads(inventory_path.read_text())
def update(value):
    if isinstance(value, dict):
        if value.get('comparison_report') == 'matrix-status.json':
            value['status'] = next(b['status'] for b in blocks if value['title_expression'] == repr(b['title']))
        for child in value.values():
            update(child)
    elif isinstance(value, list):
        for child in value:
            update(child)
update(inventory)
inventory_path.write_text(json.dumps(inventory, indent=2) + '\n')
if any(r['status'] in ['discrepancy', 'library-error'] for rows in reports.values() for r in rows):
    raise SystemExit(1)
