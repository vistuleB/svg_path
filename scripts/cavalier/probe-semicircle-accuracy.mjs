import fs from 'node:fs';
const build=process.env.AUDIT_JS_BUILD??new URL('../../test_portable/build/dev/javascript',import.meta.url).pathname;
const e=await import(`${build}/svg_path/svg_path/ellipse.mjs`);
const inputs=JSON.parse(fs.readFileSync(new URL('./semicircle-native.json',import.meta.url)));
const rows=[];
for(const input of inputs)for(const scale of [1,0.001,1024])for(const ratio of [1,2,.5]) {
 const p=([x,y])=>new e.EllipsePoint(x*scale,y*scale*ratio);
 const start=p(input.start),end=p(input.end),rx=input.radius*scale,ry=rx*ratio;
 const result=e.endpoint_to_center(new e.EndpointArcData(start,new e.EllipsePoint(rx,ry),0,false,input.bulge>0,end));
 if(!result.isOk())throw result;
 rows.push({id:input.id,scale,ratio,start:[start.x,start.y],end:[end.x,end.y],rx,ry,sweep:input.bulge>0,actual:result[0],bounds:e.arc_bounding_box(result[0])});
}
console.log(JSON.stringify(rows,null,2));
