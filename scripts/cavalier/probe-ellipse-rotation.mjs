import fs from 'node:fs';
import * as e from '../../test_portable/build/dev/javascript/svg_path/svg_path/ellipse.mjs';
import * as trig from '../../test_portable/build/dev/javascript/svg_path/svg_path/trig.mjs';
const original=JSON.parse(fs.readFileSync(new URL('./semicircle-native.json',import.meta.url)))[0];
const rows=[];
for(const ratio of [.5,2])for(const rotation of [0,17,37,73])for(const shift of [0,10000]) {
 const c=trig.cos_degrees(rotation),s=trig.sin_degrees(rotation);
 const p=([x,y])=>new e.EllipsePoint(shift+c*x-s*y*ratio,shift+s*x+c*y*ratio);
 const data=new e.EndpointArcData(p(original.start),new e.EllipsePoint(1000,1000*ratio),rotation,false,true,p(original.end));
 const result=e.endpoint_to_center(data);
 rows.push({ratio,rotation,shift,input:data,cos:c,sin:s,actual:result.isOk()?result[0]:null});
}
console.log(JSON.stringify(rows,null,2));
