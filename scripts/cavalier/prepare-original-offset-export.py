"""Generate a standalone read-only runner against the pinned upstream crate."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[2]
out=Path('/tmp/cavalier-original-offset-export');(out/'src').mkdir(parents=True,exist_ok=True)
(out/'Cargo.toml').write_text('[package]\nname="original-offset-export"\nversion="0.1.0"\nedition="2021"\n[dependencies]\ncavalier_contours={path="'+str(root/'scripts/cavalier/upstream/cavalier_contours')+'"}\n')
s='use cavalier_contours::polyline::{Polyline,PlineSource,PlineSourceMut,PlineOffsetOptions};\nfn main(){\n'
for c in json.load(open(root/'scripts/cavalier/original-offset-specific-cases.json')):
 s+=' { let mut p=Polyline::<f64>::'+('new_closed' if c['input']['closed'] else 'new')+'();\n'
 for v in c['input']['vertices']:s+='p.add('+','.join(repr(float(x)) for x in v)+');\n'
 s+='let mut options=PlineOffsetOptions::default(); options.handle_self_intersects='+str('handle_self_intersects: true' in c['options']).lower()+';\n'
 s+='let result=p.parallel_offset_opt('+repr(float(c['offset']))+',&options);\n'
 s+='println!("{{\\\"id\\\":\\\"'+c['id']+'\\\",\\\"paths\\\":[{}]}}",result.iter().map(|q|format!("{{\\\"closed\\\":{},\\\"vertices\\\":[{}]}}",q.is_closed(),q.iter_vertexes().map(|v|format!("[{:?},{:?},{:?}]",v.x,v.y,v.bulge)).collect::<Vec<_>>().join(","))).collect::<Vec<_>>().join(",")); }\n'
s+='}\n';(out/'src/main.rs').write_text(s)
print(out)
