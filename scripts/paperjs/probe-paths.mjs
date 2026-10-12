import fs from 'node:fs';
import * as s from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as measure from '../../test_portable/build/dev/javascript/svg_path/svg_path/measure.mjs';
import * as area from '../../test_portable/build/dev/javascript/svg_path/svg_path/area.mjs';
import {toList,Ok} from '../../test_portable/build/dev/javascript/svg_path/gleam.mjs';
const {blocks}=JSON.parse(fs.readFileSync(new URL('./paths.json',import.meta.url)));
function sub(g){let p=s.subpath_assert(toList(g.curves.map(c=>new s.CubicBezier(...[0,2,4,6].map(i=>new s.Point(c[i],c[i+1]))))));return g.closed?s.subpath_assert_close(p):p;}
function clean(v){return v&&typeof v==='object'?{type:v.constructor.name,...Object.fromEntries(Object.entries(v).map(([k,x])=>[k,clean(x)]))}:v;}
const results=[];
for(const b of blocks)for(const [index,o] of b.operations.entries()) {
 let r;const p=o.left?sub(o.left):null;
 switch(o.method){
 case 'length':r=measure.subpath_length(p);break;
 case 'area':r=area.signed_subpath(p);break;
 case 'getTimeAt': {const c=new s.CubicBezier(...[0,2,4,6].map(i=>new s.Point(o.curve[i],o.curve[i+1])));r=measure.segment_parameter_at_length(c,o.distance);break;}
 case 'join':r=s.subpath_join(toList([p,sub(o.args[0])]));break;
 case 'reverse':r=s.subpath_reverse(p);break;
 case 'flatten': {r=s.path_to_lines_with(s.subpath_as_path(p),new s.LinearizeOptions(o.args[0]??0.25,20));if(r instanceof Ok){const g=r[0].subpaths.head;r={segments:[...g.segments].length,closed:g.closed};}break;}
 case 'splitAt': {const d=typeof o.args[0]==='number'?o.args[0]:o.args[0].offset;const at=measure.subpath_parameter_at_length(p,d);r=at instanceof Ok?s.subpath_split(p,at[0]):at;break;}
 default:continue;
 }
 results.push({block:b.block,index,method:o.method,result:clean(r)});
}
fs.writeFileSync(new URL('./path-screening.json',import.meta.url),JSON.stringify(results,null,2)+'\n');
console.log(results.filter(r=>['length','getTimeAt','area','flatten','join'].includes(r.method)));
