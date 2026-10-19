import fs from 'node:fs';
import * as g from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as off from '../../test_portable/build/dev/javascript/svg_path/svg_path/offset.mjs';
import * as area from '../../test_portable/build/dev/javascript/svg_path/svg_path/area.mjs';
import * as serialize from '../../test_portable/build/dev/javascript/svg_path/svg_path/serialize.mjs';
import {path} from './triage-geometry.mjs';
const fixtures=JSON.parse(fs.readFileSync(new URL('./offset-simple-fixtures.json',import.meta.url)));
const rows=[];
for(const name of ['circle_collapsed','square_collapsed']){
 const f=fixtures.find(x=>x.name===name),source=Array.from(path(f).subpaths)[0];
 for(const distance of [.5,1,1.5,2,2.5,3])for(const mode of ['default','no-offside','offside-only','none']){
  const trimming=new off.SingleOffsetTrimming(mode==='default'||mode==='offside-only',mode==='default'||mode==='no-offside'?new off.InBandTrimming():new off.NoTrimming());
  const r=off.subpath_with(source,-distance,new off.Round(),new off.Butt(),off.default_options(),trimming);
  rows.push({name,distance,mode,result:r.isOk()?{ok:true,subpaths:Array.from(r[0].subpaths,s=>({area:area.signed_subpath(s),svg:serialize.subpath(s)}))}:{ok:false,error:{type:r[0].constructor.name,...r[0]}}});
 }
}
console.log(JSON.stringify(rows,null,2));
