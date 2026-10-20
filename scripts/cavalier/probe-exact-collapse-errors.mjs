import fs from 'node:fs';
const build = new URL('../../test_portable/build/dev/javascript', import.meta.url).pathname;
const g = await import(`${build}/svg_path/svg_path.mjs`);
const off = await import(`${build}/svg_path/svg_path/offset.mjs`);
const {toList} = await import(`${build}/prelude.mjs`);
const unwrap = r => { if (!r.isOk()) throw r[0]; return r[0]; };
const describe = r => r.isOk() ? {ok:true} : {error:r[0].constructor.name,...r[0]};
const cases = JSON.parse(fs.readFileSync(new URL('./captured-cases.json',import.meta.url)));
const rows = cases.filter(c => ['CC01309','CC01310','CC01311','CC01312','CC01475','CC01479'].includes(c.id)).map(c => {
  const p=c.input;
  const segments=p.vertices.slice(0,p.closed?p.vertices.length:p.vertices.length-1).map((v,i)=>{
    const w=p.vertices[(i+1)%p.vertices.length], a=new g.Point(v[0],v[1]),b=new g.Point(w[0],w[1]),bulge=v[2];
    if(!bulge) return new g.Line(a,b);
    const r=Math.hypot(b.x-a.x,b.y-a.y)*(1+bulge*bulge)/(4*Math.abs(bulge));
    return new g.Arc(a,new g.Point(r,r),0,Math.abs(bulge)>1,bulge>0,b);
  });
  let sub=unwrap(g.subpath(toList(segments)));
  if(p.closed) sub=unwrap(g.subpath_close(sub));
  const path=new g.Path(toList([sub]));
  return {id:c.id,offset:-c.offset,segments:segments.map((s,index)=>({index,source:s,result:describe(off.segment(s,-c.offset,new off.Round()))})),path:describe(off.path_with(path,-c.offset,new off.Round(),new off.Butt(),off.default_options(),new off.SingleOffsetTrimming(true,new off.InBandTrimming()))),untrimmed:describe(off.path_with(path,-c.offset,new off.Round(),new off.Butt(),off.default_options(),new off.SingleOffsetTrimming(false,new off.NoTrimming())))};
});
const controls=[];
for(const reverse of [false,true]) for(const distance of [44.999,45,45.001]) {
 const a=new g.Point(reverse?320:230,0), b=new g.Point(reverse?230:320,0);
 const s=new g.Arc(a,new g.Point(45,45),0,false,!reverse,b);
 controls.push({reverse,distance,result:describe(off.segment(s,reverse?distance:-distance,new off.Round()))});
}
console.log(JSON.stringify({rows,controls},null,2));
