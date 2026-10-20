"""Observe short-piece decisions in an isolated copy of the current JS build."""
from pathlib import Path
import shutil
root=Path(__file__).resolve().parents[2]
target=Path('/tmp/cavalier-boolean-discard-trace')
shutil.copytree(root/'test_portable/build/dev/javascript',target,dirs_exist_ok=True)
p=target/'svg_path/svg_path/arrangement.mjs'
s=p.read_text()
start=s.index('function split_atomic_pieces_for_parameters(')
end=s.index('\nfunction ',start+1)
piece=s[start:end]
needle='let $1 = size >= minimum_length;'
assert piece.count(needle)==1
piece=piece.replace(needle,needle+'\n          if (! $1) (globalThis.auditDiscards ??= []).push({source_index,global_from,global_to,size,minimum_length,segment});')
s=s[:start]+piece+s[end:]
p.write_text(s)
probe='''import fs from 'node:fs';
import * as a from '/tmp/cavalier-boolean-discard-trace/svg_path/svg_path/arrangement.mjs';
import {toList} from '/tmp/cavalier-boolean-discard-trace/prelude.mjs';
import {path} from 'REPO/scripts/cavalier/triage-geometry.mjs';
const c=JSON.parse(fs.readFileSync('REPO/scripts/cavalier/captured-cases.json')).find(c=>c.id==='CC01059');
const ss=[...path(c.input).subpaths,...path(c.other).subpaths].flatMap(s=>[...s.segments]);
const result=a.build_with(toList(ss),1e-6,1e-5,0);
console.log(JSON.stringify({ok:result.isOk(),discards:globalThis.auditDiscards},null,2));
'''.replace('REPO',str(root))
# Use the same copied module identities for the helper's constructors.
helper=(root/'scripts/cavalier/triage-geometry.mjs').read_text().replace('../../test_portable/build/dev/javascript',str(target))
(target/'geometry.mjs').write_text(helper)
probe=probe.replace(str(root)+'/scripts/cavalier/triage-geometry.mjs',str(target)+'/geometry.mjs')
(target/'probe.mjs').write_text(probe)
