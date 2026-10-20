"""Validate saved audit bookkeeping without rerunning geometry."""
from pathlib import Path
import json,hashlib
root=Path(__file__).resolve().parent
provenance=json.loads((root/'provenance.json').read_text())
for file,expected in provenance['files'].items():
 assert hashlib.sha256((root/'upstream'/file).read_bytes()).hexdigest()==expected,file
for batch in ['captured','extra']:
 cases=json.loads((root/f'{batch}-cases.json').read_text())
 results=[json.loads(l) for l in (root/f'{batch}-results.jsonl').read_text().splitlines()]
 assert len({c['id'] for c in cases})==len(cases)
 assert len({r['id'] for r in results})==len(results)
 assert {c['id'] for c in cases}=={r['id'] for r in results}
 assert not any(r['status']=='harness-error' or r.get('error',{}).get('type') in ['TypeError','ReferenceError','SyntaxError'] for r in results)
coverage=json.loads((root/'test-coverage.json').read_text())
assert len(coverage)==287
assert len({(t['binary'],t['test']) for t in coverage})==287
assert all((root/'upstream/cavalier_contours'/t['source']).is_file() for t in coverage)
summary=json.loads((root/'comparison-summary.json').read_text())
assert summary['cases']==summary['completed']==2866
assert sum(summary['totals'].values())==2866
print('Pinned archive, 2,866 case/results pairs, 287 test records and summary totals verified.')

# Original-case closure is separate from resolution of all deferred questions.
closure = root/'original-queue-final-dispositions.json'
if closure.exists():
 queue=json.loads((root/'discrepancy-queue.json').read_text())
 latest={id:r for r in json.loads((root/'triage-dispositions.json').read_text()) for id in r['ids']}
 final=json.loads(closure.read_text())
 assert len(final)==len(queue)==437
 assert {r['id'] for r in final}=={r['id'] for r in queue}
 assert all(r['status']==latest[r['id']]['status'] for r in final)
 gaps=json.loads((root/'original-coverage-gap-dispositions.json').read_text())
 assert len(gaps)==31
 assert {(r['source'],r['test']) for r in gaps}=={(r['source'],r['test']) for r in coverage if not r['cases']}
 print('Original 437 discrepancy dispositions and 31 uncaptured-test reviews verified; deferred issues are separate.')
