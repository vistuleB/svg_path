// Isolated numerical experiment. Not imported by production code.
import fs from 'node:fs';
import {performance} from 'node:perf_hooks';
import * as ellipse from '../../test_portable/build/dev/javascript/svg_path/svg_path/ellipse.mjs';
import {solve} from './ellipse-double-double-kernel.mjs';
function native(a){return ellipse.endpoint_to_center(new ellipse.EndpointArcData(new ellipse.EllipsePoint(a.start.x,a.start.y),new ellipse.EllipsePoint(a.radius.x,a.radius.y),a.x_axis_rotation,a.large_arc,a.sweep,new ellipse.EllipsePoint(a.end.x,a.end.y)))[0];}
const originals=JSON.parse(fs.readFileSync(new URL('./ellipse-rotation-inputs.json',import.meta.url))),cases=[];
for(const r of originals)for(const large of [false,true])for(const sweep of [false,true])cases.push({family:'audit',input:{...r.input,large_arc:large,sweep}});
for(const size of [1/1024,1,1024])for(const ratio of [.5,2])for(const rotation of [-137,37,123,359])for(const chord of [.5,1,1+2**-40]){
 const angle=rotation*Math.PI/180,c=Math.cos(angle),s=Math.sin(angle),x=800*size*chord,y=600*size*ratio*chord;
 cases.push({family:'control',input:{start:{x:c*x-s*y,y:s*x+c*y},end:{x:-c*x+s*y,y:-s*x-c*y},radius:{x:1000*size,y:1000*size*ratio},x_axis_rotation:rotation,large_arc:false,sweep:true}});
}
const rows=cases.map(r=>({...r,actual:native(r.input),candidate:solve(r.input)}));
// Warmed isolated timings: kernel only vs full native center conversion. Not identical workloads.
for(let i=0;i<1000;i++){solve(cases[i%cases.length].input);native(cases[i%cases.length].input);}
const timings=[];let sink=0;
for(let pass=0;pass<5;pass++){const n=5000;let t=performance.now();for(let i=0;i<n;i++)sink+=solve(cases[i%cases.length].input).center.x;const experimentMs=performance.now()-t;t=performance.now();for(let i=0;i<n;i++)sink+=native(cases[i%cases.length].input).center.x;timings.push({calls:n,experimentMs,nativeMs:performance.now()-t});}
console.log(JSON.stringify({rows,timings,sink},null,2));
