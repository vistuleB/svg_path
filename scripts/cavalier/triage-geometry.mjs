import * as g from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import {toList} from '../../test_portable/build/dev/javascript/prelude.mjs';
export const unwrap=r=>{if(!r.isOk())throw r[0];return r[0]},P=v=>new g.Point(v[0],v[1]);
export function path(input){const vs=input.vertices;const ss=vs.map((a,i)=>{const b=vs[(i+1)%vs.length],bulge=a[2];if(!bulge)return new g.Line(P(a),P(b));const r=Math.hypot(b[0]-a[0],b[1]-a[1])*(1+bulge*bulge)/(4*Math.abs(bulge));return new g.Arc(P(a),new g.Point(r,r),0,Math.abs(bulge)>1,bulge>0,P(b));});return new g.Path(toList([unwrap(g.subpath_close(unwrap(g.subpath(toList(ss)))))]));}
