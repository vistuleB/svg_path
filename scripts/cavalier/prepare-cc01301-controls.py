from pathlib import Path
import shutil,re
root=Path(__file__).resolve().parents[2]
# Historical controls require the pre-repair build (commit 3425b9e).
source = root/'test_portable/build/dev/javascript/svg_path/svg_path/arrangement.mjs'
if 'function stable_arc_parameters(' in source.read_text():
 raise SystemExit('Historical controls require a portable JS build of 3425b9e, before adaptive arc subdivision.')
for mode in ['baseline','precise-circles','split-arcs']:
 dest=Path('/tmp/cc01301-'+mode)
 shutil.copytree(root/'test_portable/build/dev/javascript',dest,dirs_exist_ok=True)
 p=dest/'svg_path/svg_path/offset.mjs';s=p.read_text().replace('export function public_error(error) {','export function public_error(error) { console.error(JSON.stringify(error,(k,v)=>v&&typeof v==="object"&&!Array.isArray(v)?{type:v.constructor.name,...v}:v));');p.write_text(s)
 if mode=='precise-circles':
  p=dest/'svg_path/svg_path/ellipse.mjs';s=p.read_text();assert '(rx !== ry) &&' in s;s=s.replace('(rx !== ry) &&','');p.write_text(s)
 if mode=='split-arcs':
  p=dest/'svg_path/svg_path/arrangement.mjs';s=p.read_text();needle='''(pieces) => {
              let images = initial_segment_images(indexed);''';assert s.count(needle)==1
  s=s.replace(needle,'''(pieces) => {
              pieces = $list.flat_map(pieces, piece => {
                if (!(piece.segment instanceof $svg_path.Arc)) return toList([piece]);
                const r=$svg_path.arc_center_data(piece.segment);
                if (!(r instanceof Ok) || Math.abs(r[0].delta_angle)<179.9) return toList([piece]);
                const n=Math.ceil(Math.abs(r[0].delta_angle)/90);
                const cuts=toList(Array.from({length:n-1},(_,i)=>(i+1)/n));
                const split=split_atomic_piece(piece,cuts,vertex_tolerance,minimum_length);
                if (!(split instanceof Ok)) throw split[0];
                return split[0];
              });
              let images = initial_segment_images(indexed);''');p.write_text(s)
 print(dest)
# Narrower diagnostic control: only subdivide a split interval whose reconstructed
# arc fails a sampled comparison against its parent. Not a certified bound.
dest=Path('/tmp/cc01301-adaptive-arcs')
shutil.copytree(root/'test_portable/build/dev/javascript',dest,dirs_exist_ok=True)
p=dest/'svg_path/svg_path/arrangement.mjs';s=p.read_text()
s+='''
function auditStableArcCuts(segment, parameters, tolerance) {
 if (!(segment instanceof $svg_path.Arc)) return parameters;
 const ts=[...parameters]; if(ts.length<=2) return parameters;
 const result=[ts[0]];
 function visit(a,b,depth) {
  const r=$svg_path.segment_between(segment,a,b); if(!(r instanceof Ok)) throw r[0];
  let residual=0;
  for(const t of [.25,.5,.75]) {
   const x=$svg_path.segment_point(segment,a+(b-a)*t), y=$svg_path.segment_point(r[0],t);
   if(!(x instanceof Ok)||!(y instanceof Ok)) {residual=Infinity;break}
   residual=Math.max(residual,Math.hypot(x[0].x-y[0].x,x[0].y-y[0].y));
  }
  if(residual>tolerance/4 && depth<8) {
   console.error(JSON.stringify({adaptiveArcSplit:{a,b,residual,tolerance,depth}}));
   const mid=(a+b)/2;visit(a,mid,depth+1);visit(mid,b,depth+1);
  } else {if(residual>tolerance/4)console.error(JSON.stringify({unresolvedArcResidual:residual})); result.push(b);}
 }
 for(let i=1;i<ts.length;i++) visit(ts[i-1],ts[i],0);
 return toList(result);
}
'''
for name in ['split_atomic_piece','split_progressive_graph_edge']:
 a=s.index('function '+name+'(');b=s.index('\nfunction ',a+10)
 part=s[a:b];needle='(parameters) => {';assert part.count(needle)==1
 part=part.replace(needle,needle+'\n parameters=auditStableArcCuts(segment,parameters,tolerance);')
 s=s[:a]+part+s[b:]
p.write_text(s)
p=dest/'svg_path/svg_path/offset.mjs';s=p.read_text().replace('export function public_error(error) {','export function public_error(error) { console.error(JSON.stringify(error,(k,v)=>v&&typeof v==="object"&&!Array.isArray(v)?{type:v.constructor.name,...v}:v));');p.write_text(s)
print(dest)
# Replace sample-only acceptance by a conservative bound for the two center-form
# parameterizations. Same axis rotation; phases are unwrapped to the parent.
bounded=Path('/tmp/cc01301-bounded-arcs')
shutil.copytree(dest,bounded,dirs_exist_ok=True)
p=bounded/'svg_path/svg_path/arrangement.mjs';s=p.read_text()
a=s.index('  let residual=0;',s.index('function auditStableArcCuts'))
b=s.index('  if(residual>tolerance/4',a)
s=s[:a]+'''  const parent=$svg_path.arc_center_data(segment),child=$svg_path.arc_center_data(r[0]);
  let residual=Infinity;
  if(parent instanceof Ok && child instanceof Ok) {
    const x=parent[0],y=child[0];
    const expectedStart=x.start_angle+a*x.delta_angle;
    const expectedDelta=(b-a)*x.delta_angle;
    const startDiff=((y.start_angle-expectedStart+180)%360+360)%360-180;
    const endDiff=startDiff+y.delta_angle-expectedDelta;
    const angle=Math.max(Math.abs(startDiff),Math.abs(endDiff))*Math.PI/180;
    residual=Math.hypot(x.center.x-y.center.x,x.center.y-y.center.y)
      +Math.max(Math.abs(x.radius.x-y.radius.x),Math.abs(x.radius.y-y.radius.y))
      +Math.max(x.radius.x,x.radius.y)*Math.min(2,angle);
  }
'''+s[b:]
p.write_text(s)
print(bounded)
# The center bound is loose for very short arcs: centers may differ while their
# small traces agree. Also bound the difference by endpoint interpolation plus
# the second-derivative remainder, and take the smaller bound.
combined=Path('/tmp/cc01301-combined-bound-arcs')
shutil.copytree(bounded,combined,dirs_exist_ok=True)
p=combined/'svg_path/svg_path/arrangement.mjs';s=p.read_text()
s='import * as $auditEllipse from "./ellipse.mjs";\n'+s
needle='''      +Math.max(x.radius.x,x.radius.y)*Math.min(2,angle);'''
assert s.count(needle)==1
s=s.replace(needle,needle+'''
    const distance=(u,v)=>Math.hypot(u.x-v.x,u.y-v.y);
    const endpointError=Math.max(
      distance($auditEllipse.arc_point(x,a),$auditEllipse.arc_point(y,0)),
      distance($auditEllipse.arc_point(x,b),$auditEllipse.arc_point(y,1)));
    const radians=Math.PI/180;
    const secondDerivativeBound=(Math.max(x.radius.x,x.radius.y)*(expectedDelta*radians)**2
      +Math.max(y.radius.x,y.radius.y)*(y.delta_angle*radians)**2)/8;
    residual=Math.min(residual,endpointError+secondDerivativeBound);
''')
p.write_text(s)
print(combined)
