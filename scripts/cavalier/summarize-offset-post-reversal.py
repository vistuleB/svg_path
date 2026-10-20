"""Summarize the fresh flagged-offset replay without replacing baseline records."""
import json
from collections import Counter, defaultdict
from pathlib import Path

root = Path(__file__).resolve().parent
load = lambda name: json.loads((root / name).read_text())
cases = load('offset-post-reversal-cases.json')
rows = [json.loads(line) for line in (root / 'offset-post-reversal-results.jsonl').read_text().splitlines()]
assert len({r['id'] for r in rows}) == len(rows)
assert {r['id'] for r in rows} == {c['id'] for c in cases}, 'Replay incomplete'
baseline = {r['id']: r for r in map(json.loads, (root / 'captured-results.jsonl').read_text().splitlines())}
latest_baseline = dict(baseline)
latest_baseline.update({r['id']: r for r in map(json.loads, (root / 'timeout-results.jsonl').read_text().splitlines())})
families = defaultdict(list)
for row in rows:
    families[(row['binary'], row['test'])].append(row)
summary = {
    'revision': '1e97935',
    'target': 'JavaScript',
    'selection': 'Original captured-results discrepancy/error/timeout records of kind offset or shape_offset; not a full offset regression run.',
    'records': len(rows),
    'families': len(families),
    'statuses': dict(Counter(r['status'] for r in rows)),
    'transitions': dict(Counter(baseline[r['id']]['status'] + ' -> ' + r['status'] for r in rows)),
    'transitions_from_baseline_with_timeout_replay': dict(Counter(latest_baseline[r['id']]['status'] + ' -> ' + r['status'] for r in rows)),
    'timeouts': [r['id'] for r in rows if r['status'] == 'timeout'],
    'matches': [r['id'] for r in rows if r['status'] == 'match'],
}
(root / 'offset-post-reversal-summary.json').write_text(json.dumps(summary, indent=2) + '\n')
lines = ['# Flagged offset replay after reversal-join repair', '',
         'Revision `1e97935`, JavaScript. Historical baseline records are unchanged.', '',
         f'{len(rows)} originally flagged records across {len(families)} upstream tests. ' + ', '.join(f'{k}: {v}' for k,v in summary['statuses'].items()) + '.', '',
         'These are property comparisons, not boundary-equivalence proofs or bug counts. Matches may reflect any preceding audit repair; only the separately isolated reversal cases are attributed to the latest fix. Previously matching inputs were not selected. Timeouts remain unresolved.', '',
         '| Upstream test | Records | Current outcomes | IDs still flagged |',
         '| --- | ---: | --- | --- |']
for (_, test), group in sorted(families.items()):
    counts = ', '.join(f'{k}: {v}' for k,v in Counter(r['status'] for r in group).items())
    ids = ', '.join(r['id'] for r in group if r['status'] != 'match') or '—'
    lines.append(f'| `{test}` | {len(group)} | {counts} | {ids} |')
lines += ['', 'See `OFFSET-POST-REVERSAL-TRIAGE.md` for targeted follow-up and dispositions.', '']
(root / 'OFFSET-POST-REVERSAL-REPLAY.md').write_text('\n'.join(lines))
print(json.dumps(summary, indent=2))
