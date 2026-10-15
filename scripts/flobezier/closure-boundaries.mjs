import fs from 'node:fs';
import * as g from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as m from '../../test_portable/build/dev/javascript/svg_path/svg_path/measure.mjs';
const c=JSON.parse(fs.readFileSync(new URL('numeric-results.json',import.meta.url))).rows.find(r=>r.call===13594);
const s=new g.CubicBezier(...c.args[0].map(p=>new g.Point(...p)));
const length=m.segment_length(s);
const r={requested:c.args[1],measured:length[0],difference:c.args[1]-length[0],atReference:m.segment_parameter_at_length(s,c.args[1]),atOwnLength:m.segment_parameter_at_length(s,length[0])};
fs.writeFileSync(new URL('closure/length-boundary.json',import.meta.url),JSON.stringify(r,null,2)+'\n');console.log(r);
