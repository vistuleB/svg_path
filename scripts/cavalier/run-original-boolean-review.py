"""Fresh bounded scanline checks of all originally flagged Boolean records."""
import json,os,subprocess,time
from pathlib import Path
root=Path(__file__).resolve().parent
ids=[x['id'] for x in json.loads((root/'discrepancy-queue.json').read_text()) if x['kind']=='boolean']
with (root/'original-boolean-scanlines.jsonl').open('w') as out:
 for id in ids:
  for mode in ['output','stored-edges']:
   start=time.monotonic()
   env={**os.environ,'CASE_ID':id,'INPUT_MODEL':'svg'}
   if mode=='stored-edges':env['PRE_SNAP']='1'
   try:
    p=subprocess.run([os.environ.get('NODE','node'),str(root/'probe-boolean-scanlines.mjs')],env=env,capture_output=True,text=True,timeout=45)
    r=json.loads(p.stdout) if p.returncode==0 else {'id':id,'probe_error':p.stderr}
   except subprocess.TimeoutExpired:r={'id':id,'timeout_seconds':45}
   r.update(mode=mode,elapsed_seconds=time.monotonic()-start)
   out.write(json.dumps(r,separators=(',',':'))+'\n');out.flush()
  print(id,flush=True)
