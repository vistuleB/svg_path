// Direct reproduction independent of the capture and comparison adapters.
import * as svg from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as distance from '../../test_portable/build/dev/javascript/svg_path/svg_path/distance.mjs';
Error.stackTraceLimit=40;
const p=(x,y)=>new svg.Point(x,y);
const a=new svg.CubicBezier(p(100000,100000),p(100001,100010),p(100007,100003),p(100010,100000));
const b=new svg.Line(p(100000,100005.18996761437),p(100010,100005.18996761437));
try {console.log(distance.segment_segment_closest_pair(a,b));}
catch(error) {console.error(error.stack);process.exitCode=1;}
