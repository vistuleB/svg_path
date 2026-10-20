import json,subprocess,os
from pathlib import Path
root=Path(__file__).resolve().parent
rows=[json.loads(l) for l in (root/'original-boolean-scanlines.jsonl').read_text().splitlines()]
with (root/'original-boolean-orthogonal-rechecks.jsonl').open('w') as out:
 for row in rows:
  if 'Unbalanced scanline' not in row.get('probe_error',''):continue
  env={**os.environ,'CASE_ID':row['id'],'SCAN_AXIS':'x','INPUT_MODEL':'svg'}
  if row['mode']=='stored-edges':env['PRE_SNAP']='1'
  p=subprocess.run([os.environ.get('NODE','node'),str(root/'probe-boolean-scanlines.mjs')],env=env,capture_output=True,text=True,timeout=45)
  r=json.loads(p.stdout) if p.returncode==0 else {'id':row['id'],'probe_error':p.stderr}
  r['mode']=row['mode'];out.write(json.dumps(r,separators=(',',':'))+'\n');out.flush()
  print(row['id'],row['mode'],r.get('maxWitnessClearance',r.get('probe_error')),flush=True)
