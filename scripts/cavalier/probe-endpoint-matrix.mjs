import {pathToFileURL} from 'node:url';
const base=process.argv[2]??'/tmp/cavalier-endpoint-experiment';
const g=await import(pathToFileURL(`${base}/svg_path/svg_path.mjs`));
const intr=await import(pathToFileURL(`${base}/svg_path/svg_path/intersections.mjs`));
const rows=[];
for(const kind of ['arc','quadratic','cubic']) for(const scale of [0.001,1,1000]) for(const shift of [0,1000]) for(const gap of [0,1e-10,2e-9]) for(const reversed of [false,true]) {
 const p=(x,y)=>new g.Point(shift+scale*x,shift+scale*y);
 let a,b;
 if(kind==='arc'){
  a=new g.Arc(p(1,0),new g.Point(scale,scale),0,false,true,p(0,1));
  b=new g.Arc(p(0,1+gap),new g.Point(scale,scale),0,false,true,p(-1,2+gap));
 }else if(kind==='quadratic'){
  a=new g.QuadraticBezier(p(1,0),p(1,1),p(0,1));
  b=new g.QuadraticBezier(p(0,1+gap),p(0,2+gap),p(-1,2+gap));
 }else{
  a=new g.CubicBezier(p(1,0),p(1,0.5),p(0.5,1),p(0,1));
  b=new g.CubicBezier(p(0,1+gap),p(0,1.5+gap),p(-0.5,2+gap),p(-1,2+gap));
 }
 const actualGap=Math.hypot(a.end.x-b.start.x,a.end.y-b.start.y);
 if(reversed){a=g.segment_reverse(a);b=g.segment_reverse(b);}
 const options=intr.default_options();options.tolerance=1e-9*scale;
 const result=intr.segment_with(a,b,options);
 rows.push({kind,scale,shift,gap,reversed,actual_gap:actualGap,tolerance:options.tolerance,
 expected_endpoint:actualGap<=options.tolerance,
 result:result.isOk()?{ok:true,hits:Array.from(result[0])}:{ok:false,error:{type:result[0].constructor.name,...result[0]}}});
}
console.log(JSON.stringify(rows,null,2));
