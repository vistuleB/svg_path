#!/usr/bin/env python3
"""Verify archived source and build a filename/test-name index (no line links)."""
import hashlib,json
from pathlib import Path
root=Path(__file__).resolve().parent
provenance=json.loads((root/'provenance.json').read_text())
for item in provenance['files']:
    assert hashlib.sha256((root/'upstream'/item['path']).read_bytes()).hexdigest()==item['sha256'],item['path']
run=root/'upstream-baseline.json'
tests=json.loads(run.read_text())['tests'] if run.exists() else []
files=sorted(p.relative_to(root/'upstream').as_posix() for p in (root/'upstream/test').rglob('*.js'))
comparisons=[]
for batch in ['arc-circle','arc-extra','linear','primitives','polygons','chains','residual']:
    results=root/f'{batch}-results.json'
    if results.exists(): comparisons += [{**c,'batch':batch} for c in json.loads(results.read_text())['rows']]
reviews=json.loads((root/'assertion-review.json').read_text()) if (root/'assertion-review.json').exists() else {}
dispositions=json.loads((root/'dispositions.json').read_text()) if (root/'dispositions.json').exists() else {}

gaps=json.loads((root/'coverage-gaps.json').read_text()) if (root/'coverage-gaps.json').exists() else []
rows=[]
for file in files:
    selected=[c for c in comparisons if c['file']==file]
    indexed=[]
    ordinal=0
    for t in tests:
        if t['file']!=file: continue
        ordinal+=1
        calls=[{'batch':c['batch'],'call':c['call'],'operation':c['operation'],'observedStatus':c['comparison']['status'],'status':dispositions.get(f"{c['batch']}:{c['call']}",{}).get('status',c['comparison']['status'])} for c in selected if c.get('testOrdinal')==ordinal]
        test_gaps=[g['id'] for g in gaps if any(x['file']==file and x['testOrdinal']==ordinal for x in g['tests'])]
        indexed.append({**t,'assertionGaps':test_gaps,'comparedCalls':calls,'auditStatus':'selected-operations-compared' if calls else ('deferred-adaptation' if test_gaps else 'scope-reviewed' if t['test'] in reviews else 'pending-assertion-review'),'review':reviews.get(t['test'])})
    rows.append({'file':file,'status':('operation comparisons recorded; see REVIEW.md' if selected else 'scope-reviewed' if indexed and all(t['auditStatus']=='scope-reviewed' for t in indexed) else 'pending'),'tests':indexed,'comparedCalls':len(selected)})
(root/'inventory.json').write_text(json.dumps({'files':rows},indent=2)+'\n')
lines=['# Flatten.js test-file inventory','','Pinned source: `'+provenance['revision']+'` ('+provenance['packageVersion']+').',
       'Statuses describe audited operations, never exhaustive assertion parity. See COVERAGE-GAPS.md for explicit deferred comparisons.','','| Upstream file | Baseline tests | Captured calls compared | Audit status |','| --- | ---: | ---: | --- |']
for row in rows:
    lines.append(f"| [{row['file']}](upstream/{row['file']}) | {len(row['tests'])} | {row['comparedCalls']} | {row['status']} |")
(root/'INDEX.md').write_text('\n'.join(lines)+'\n')
print(f"Verified {len(provenance['files'])} archived files; indexed {len(files)} test files.")

# Retain raw flags and any later adjudication; never silently count them as matches.
flags=[]
for c in comparisons:
    if c['comparison']['status']!='needs-investigation': continue
    key=f"{c['batch']}:{c['call']}"
    flags.append({'id':key,'file':c['file'],'test':c['test'],'operation':c['operation'],
                  'observation':c['comparison'],'disposition':dispositions.get(key)})
(root/'discrepancy-queue.json').write_text(json.dumps(flags,indent=2)+'\n')
queue=['# Discrepancy dispositions','','Raw flagged comparisons, not a count of confirmed bugs. See REMAINING-TRIAGE.md for current diagnoses and open fixes; FINDINGS.md retains the history.','',
       '| Call | Upstream file and test | Observation | Disposition |','| --- | --- | --- | --- |']
for f in flags:
    d=f['observation'];detail=d.get('error','30-second timeout' if d.get('timeout') else 'sampled geometry mismatch')
    if d.get('phase'): detail+='; '+d['phase']
    disposition=(f['disposition'] or {}).get('status','deferred investigation')
    queue.append(f"| `{f['id']}` | `{f['file']}` — {f['test']} | {detail} | {disposition} |")
(root/'DISCREPANCIES.md').write_text('\n'.join(queue)+'\n')
