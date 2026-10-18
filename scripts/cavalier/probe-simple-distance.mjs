import fs from 'node:fs';
import * as g from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as distance from '../../test_portable/build/dev/javascript/svg_path/svg_path/distance.mjs';
import * as bounds from '../../test_portable/build/dev/javascript/svg_path/svg_path/bounds.mjs';
const encode=r=>r.isOk()?{ok:r[0]}:{error:{type:r[0].constructor.name,...r[0]}};
const results=[];
for(const radius of [10,100,1000,10000,1e5,1e6,1e7,1e8,1e9])for(const x of [1,3,5]){
 const arc=new g.Arc(new g.Point(0,0),new g.Point(radius,radius),0,false,true,new g.Point(10,0));
 results.push({radius,x,result:encode(distance.segment_projection(new g.Point(x,1),arc))});
}
fs.writeFileSync(new URL('simple-distance-sweep.json',import.meta.url),JSON.stringify(results,null,2)+'\n');
for(const r of results) console.log(r.radius,r.x,JSON.stringify(r.result));
