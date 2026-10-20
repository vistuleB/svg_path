import fs from 'node:fs';
const build=process.env.AUDIT_JS_BUILD??new URL('../../test_portable/build/dev/javascript',import.meta.url).pathname;
const g=await import(`${build}/svg_path/svg_path.mjs`), a=await import(`${build}/svg_path/svg_path/arrangement.mjs`);
const {toList}=await import(`${build}/prelude.mjs`);const ok=r=>{if(!r.isOk())throw r[0];return r[0]};
const data=JSON.parse(fs.readFileSync(new URL('./offset-arc-reparameterization.json',import.meta.url)));
const p=q=>new g.Point(q.x,q.y),s=data.arc;
const arc=new g.Arc(p(s.start),p(s.radius),0,false,false,p(s.end));
const cut=ok(g.segment_point(arc,data.trim)),cross=ok(g.segment_point(arc,data.parameter)),center=ok(g.arc_center_data(arc)).center;
const chord=new g.Line(p(s.start),cut),line=new g.Line(p(center),new g.Point(2*cross.x-center.x,2*cross.y-center.y));
for(const [name,segments] of [['arc only',[arc]],['one cut',[arc,chord]],['cross only',[arc,line]],['endpoint then crossing',[arc,chord,line]],['crossing then endpoint',[arc,line,chord]]]){
 const r=a.build_with(toList(segments),1e-9,1e-9,1e-8);
 console.log(JSON.stringify({name,segments,result:r.isOk()?{edges:[...r[0].graph.edges].length,vertices:[...r[0].graph.vertices].length}:r[0]},(k,v)=>v&&typeof v==='object'&&!Array.isArray(v)?{type:v.constructor.name,...v}:v));
}
