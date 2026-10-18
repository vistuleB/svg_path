from pathlib import Path
import json,re,collections
root=Path(__file__).resolve().parent
cases=json.loads((root/'captured-cases.json').read_text())+json.loads((root/'extra-cases.json').read_text())
results=[]
for name in ['captured-results.jsonl','extra-results.jsonl']:
 results += [json.loads(l) for l in (root/name).read_text().splitlines() if l]
# Longer serial replay is an additional observation; keep the original outcome too.
replay_file=root/'timeout-results.jsonl'
replays={r['id']:r for r in map(json.loads,replay_file.read_text().splitlines())} if replay_file.exists() else {}
results=[{**replays[r['id']], 'initial_timeout_seconds':10} if r['id'] in replays else r for r in results]
results.sort(key=lambda r:r['id'])
lookup={r['id']:r for r in results};tests=[];binary=None
def source(binary,name):
 if binary!='cavalier_contours':return 'tests/'+binary+'.rs'
 parts=name.split('::')
 for n in range(len(parts),0,-1):
  f='src/'+'/'.join(parts[:n])+'.rs'
  if (root/'upstream/cavalier_contours'/f).exists():return f
 return 'src/lib.rs'

for line in (root/'upstream-baseline.log').read_text().splitlines():
 m=re.search(r'Running (?:unittests|tests/[^ ]+) .*\((?:[^()]*/)?([^/()]+)-[0-9a-f]+\)',line)
 if m:binary=m[1]
 m=re.match(r'test (.+?) \.\.\. (?:ok|ignored)',line)
 if m:tests.append({'binary':binary,'test':m[1]})
assert len(tests)==287,len(tests)
for t in tests:
 refs=[c for c in cases if any(r['binary']==t['binary'] and r['test']==t['test'] for r in c['references'])]
 t['source']=source(t['binary'],t['test']);t['cases']=[c['id'] for c in refs];t['statuses']=dict(collections.Counter(lookup.get(c['id'],{}).get('status','pending') for c in refs))
 t['coverage']='selected-operation comparisons' if any(not c.get('helper_only') for c in refs) else 'helper-only capture' if refs else 'not adapted'
(root/'test-coverage.json').write_text(json.dumps(tests,indent=2)+'\n')
print('Coverage',collections.Counter(t['coverage'] for t in tests))
for t in tests:
 if t['coverage']=='not adapted':print(t['binary'],t['test'])
summary={'cases':len(cases),'completed':len(results),'by_kind':{k:dict(collections.Counter(r['status'] for r in results if r['kind']==k)) for k in sorted({r['kind'] for r in results})},'totals':dict(collections.Counter(r['status'] for r in results)),'test_coverage':dict(collections.Counter(t['coverage'] for t in tests))}
(root/'comparison-summary.json').write_text(json.dumps(summary,indent=2)+'\n')
flags=[{**r,'references':next(c['references'] for c in cases if c['id']==r['id'])} for r in results if r['status'] in ['error','discrepancy','timeout','harness-error']]
(root/'discrepancy-queue.json').write_text(json.dumps(flags,indent=2)+'\n')
groups=collections.defaultdict(list)
for r in flags:
 for ref in r['references']:groups[(ref['file'],ref['test'],r['kind'])].append(r)
lines=['# Comparative discrepancy inventory','', 'Raw flags only: not a confirmed-bug count. Comparison and adapter limits are in `REVIEW.md`.','', '| Original file / test | Operation | Flags | Outcomes | Representative case |','| --- | --- | ---: | --- | --- |']
for (f,t,k),rs in sorted(groups.items()):
 outcomes=', '.join(f'{a}: {b}' for a,b in collections.Counter(r.get('error',{}).get('type',r['status']) for r in rs).items())
 lines.append(f'| `{f}` / `{t}` | `{k}` | {len(rs)} | {outcomes} | `{rs[0]["id"]}` |')
lines+=['','Full inputs are in `captured-cases.json` and `extra-cases.json`; native outcomes are in the matching results JSONL files. `discrepancy-queue.json` contains every raw flag. The same case may occur in multiple tests; rows do not count independent bugs.']
(root/'DISCREPANCIES.md').write_text('\n'.join(lines)+'\n')
lines=['# Core test coverage ledger','','All 287 tests passed upstream; a native comparison below covers selected operations, not every assertion.','','| Binary / original test | Coverage | Cases | Outcomes |','| --- | --- | ---: | --- |']
for t in tests:lines.append(f'| `{t["source"]}` / `{t["test"]}` | {t["coverage"]} | {len(t["cases"])} | '+', '.join(f'{k}: {v}' for k,v in t['statuses'].items())+' |')
(root/'TEST-COVERAGE.md').write_text('\n'.join(lines)+'\n')
lines=['# Cavalier Contours core-suite inventory','','Pinned revision and provenance: `README.md`. Per-test detail: `TEST-COVERAGE.md`.','All core files are inventoried; selected-operation capture is not full assertion coverage.','','| Source | Upstream tests | With selected captured operations | Without selected captures |','| --- | ---: | ---: | ---: |']
for f in sorted({t['source'] for t in tests}):
 ts=[t for t in tests if t['source']==f];n=sum(bool(t['cases']) for t in ts)
 lines.append(f'| `{f}` | {len(ts)} | {n} | {len(ts)-n} |')
lines+=['','The 31 uncaptured tests and assertion-level gaps are explicitly discussed in `REVIEW.md`. FFI, UI, examples and doctests are outside this collection.']
(root/'INDEX.md').write_text('\n'.join(lines)+'\n')
