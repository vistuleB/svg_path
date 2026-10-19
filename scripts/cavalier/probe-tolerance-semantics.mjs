// Identical straight geometry encoded with different SVG segment types.
import * as g from './probe/build/dev/javascript/svg_path/svg_path.mjs';
import * as ix from './probe/build/dev/javascript/svg_path/svg_path/intersections.mjs';
const p=(x,y)=>new g.Point(x,y);
function edge(a,b,kind){
 const mix=t=>p(a.x+(b.x-a.x)*t,a.y+(b.y-a.y)*t);
 if(kind==='line')return new g.Line(a,b);
 if(kind==='quadratic')return new g.QuadraticBezier(a,mix(.5),b);
 return new g.CubicBezier(a,mix(1/3),mix(2/3),b);
}
const rows=[];
function record(name,a,b,tolerance=1e-9){
 const opts=ix.default_options();opts.tolerance=tolerance;
 const r=ix.segment_with(a,b,opts);
 rows.push({name,tolerance,result:r.isOk()?{ok:true,hits:Array.from(r[0])}:{ok:false,error:{type:r[0].constructor.name,...r[0]}}});
}
for(const gap of [0,1e-10,2e-9]) for(const a of ['line','quadratic','cubic']) for(const b of ['line','quadratic','cubic']){
 record(`perpendicular gap=${gap} ${a}/${b}`,edge(p(0,0),p(1,0),a),edge(p(1+gap,gap),p(1+gap,1),b));
}
record('distinct constant points',new g.Line(p(0,0),p(0,0)),new g.Line(p(1e-10,0),p(1e-10,0)));
record('parallel offset lines',new g.Line(p(0,0),p(1,0)),new g.Line(p(0,1e-10),p(1,1e-10)));
console.log(JSON.stringify(rows,null,2));
