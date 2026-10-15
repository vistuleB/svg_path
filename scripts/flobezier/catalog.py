#!/usr/bin/env python3
"""Rebuild the file index from pinned inventory and recorded diagnostic results."""
import collections
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parent

def read(name):
    return json.loads((ROOT/name).read_text())

inventory=read('inventory.json')
baseline=read('upstream-full-suite.json')
by_file={}
for test in baseline['testResults']:
    file='__tests__/'+test['name'].split('/__tests__/',1)[1]
    by_file[file]=test
rows=read('intersections-results.json')['rows']+read('numeric-results.json')['rows']+read('remaining-results.json')['rows']
reviews=read('remaining-review.json')
comparisons=collections.defaultdict(list)
for row in rows:
    comparisons[row['file']].append(row)

# These tests assert a representation or capability that our public API does
# not expose. Their inputs can still inform future high-level regression tests.
def screening(file):
    p=file.removeprefix('__tests__/')
    if p.startswith(('to-power-basis/','from-power-basis/','implicit-form/','x-from-y/','y-from-x/')):
        return 'Polynomial coefficients, exact expansions, or coefficient error bounds; no corresponding public representation.'
    if '/get-coeffs/' in p or '/coeffs' in p or p.startswith('get-medial-points/') and 'coeffs' in p:
        return 'Upstream solver coefficient construction/error bounds; no direct public contract to compare.'
    if p.startswith(('intersection/bezier-bezier-intersection/b-', 'intersection/bezier-bezier-intersection/bigint-', 'intersection/bezier-bezier-intersection/ensure-range')):
        return 'Upstream bigint/range utility, not a geometry-level public operation.'
    if p in ['next-up.spec.ts','next-down.spec.ts','test-helpers.spec.ts','simultaneous-properties/heap.spec.ts','stewart-error-counters.ts/stewart-error-counters.spec.ts']:
        return 'Upstream numerical or test infrastructure; no direct public geometry contract.'
    if p in ['transformation/to-expansion.spec.ts','transformation/to-estimation.spec.ts']:
        return 'Shewchuk expansion conversion; our point API stores ordinary floats.'
    return None

for item in inventory['files']:
    f=item['file']; upstream=by_file[f]; captured=comparisons[f]
    item['upstreamStatus']=upstream['status']
    item['upstreamTests']=[{'name':x['fullName'],'status':x['status']} for x in upstream['assertionResults']]
    item['comparisonCounts']=dict(collections.Counter(x['status'] for x in captured))
    item['comparisonOperations']=sorted(set(x.get('operation','bezierBezierIntersection') for x in captured))
    reason=screening(f)
    if f in reviews: item['reviewNote']=reviews[f]
    if captured:
        item['status']='selected-operations-compared'
        item['scopeNote']='Only the recorded operations/calls are compared; other assertions in this file are not implied to be covered.'
    elif f in reviews:
        item['status']='reviewed-contract-difference'
        item['scopeNote']=reviews[f]
    elif reason:
        item['status']='screened-no-direct-public-contract'
        item['scopeNote']=reason
    else:
        item['status']='pending-contract-adaptation'
        item['scopeNote']='Upstream passed. Shared-contract comparison still requires review/adaptation.'
for item in inventory['experimentalFiles']:
    item['status']='screened-no-direct-public-contract'
    item['scopeNote']='Hausdorff accuracy/timing experiment, excluded by upstream normal Jest config; no public Hausdorff API here. Source reviewed, not executed.'
(ROOT/'inventory.json').write_text(json.dumps(inventory,indent=2)+'\n')
counts=collections.Counter(i['status'] for i in inventory['files'])
lines=['# FloBezier audit file index','', 'Pinned revision: `8ad65ac79cb69989cd40b0d375a51392eb477f16`.','',
       'All 164 ordinary specification files passed upstream (326 tests). This is',
       'separate from shared-contract comparison coverage. Two excluded experiments',
       'were screened by source only. Counts below describe files, not assertions.','',
       *[f'- {n} {status}.' for status,n in sorted(counts.items())], '',
       'Selected-operations-compared is deliberately partial: see the operation list',
       'and call dispositions in `inventory.json`. Test names are recorded there; no',
       'line-number links are used. See [findings](FINDINGS.md). Raw comparator flags have reviewed dispositions in `closure/summary.json`; they are not all unresolved findings.','',
       '| Upstream file | Status | Compared calls |','| --- | --- | --- |']
for item in inventory['files']+inventory['experimentalFiles']:
    f=item['file'];lines.append(f"| [{f}](upstream/{f}) | {item['status']} | {sum(item.get('comparisonCounts',{}).values())} |")
(ROOT/'INDEX.md').write_text('\n'.join(lines)+'\n')
print(dict(counts))
