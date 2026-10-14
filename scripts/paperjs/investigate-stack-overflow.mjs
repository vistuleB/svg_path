// Run against an existing JavaScript build; never changes library sources.
import { pathToFileURL } from 'node:url';
import path from 'node:path';
import fs from 'node:fs';
const base=path.resolve(process.argv[2]);
const svg=await import(pathToFileURL(path.join(base,'svg_path/svg_path.mjs')));
const parse=await import(pathToFileURL(path.join(base,'svg_path/svg_path/parse.mjs')));
const {toList}=await import(pathToFileURL(path.join(base,'prelude.mjs')));
const rows=[];
function length(list){let n=0; for(const _ of list)n++;return n;}
function summarize(result){return result.isOk()?{status:'Ok',edges:length(svg.subpath_segments(result[0]))}:{status:'Error',error:JSON.parse(JSON.stringify(result[0])),kind:result[0].constructor.name};}
function check(label,count,fn){const start=performance.now();try{rows.push({label,count,...fn(),ms:performance.now()-start});}catch(e){rows.push({label,count,status:'threw',kind:e.name,message:e.message,stack:e.stack.split('\n').slice(0,7),ms:performance.now()-start});}}
for(const count of [100,10000,100000]){
 const points=Array.from({length:count+1},(_,i)=>new svg.Point(i,0));
 const lines=toList(points.slice(1).map((p,i)=>new svg.Line(points[i],p)));
 for(const policy of [new svg.Strict(),new svg.Bridge(),new svg.Wiggle(),new svg.WiggleWith(0.01),new svg.WiggleElseBridge(),new svg.WiggleElseBridgeWith(0.01)])
  check(policy.constructor.name,count,()=>summarize(svg.subpath_with(lines,policy)));
 check('custom identity/context',count,()=>{
  let calls=0,first=0,last=0,closing=0;
  const policy=new svg.Custom((a,b,c)=>{calls++;first+=Number(c.first);last+=Number(c.last);closing+=Number(c.closing);return toList([a,b]);});
  return {...summarize(svg.subpath_with(lines,policy)),calls,first,last,closing};
 });
 check('late discontinuity',count,()=>{
  const array=Array.from(lines);array[array.length-1]=new svg.Line(new svg.Point(-1,0),new svg.Point(-2,0));return summarize(svg.subpath(toList(array)));
 });
 check('custom invalid late replacement',count,()=>summarize(svg.subpath_with(lines,new svg.Custom((a,b,c)=>c.last?toList([new svg.Line(new svg.Point(-1,0),svg.segment_end(b))]):toList([a,b])))));
 check('polygon',count,()=>summarize(svg.subpath_polygon(toList(points))));
 check('parse lines',count,()=>{const r=parse.path('M0 0'+points.slice(1).map(p=>`L${p.x} 0`).join(''));return r.isOk()?{status:'Ok',subpaths:length(svg.path_subpaths(r[0]))}:{status:'Error',kind:r[0].constructor.name};});
 check('custom bridge replacement',count,()=>{
  const gaps=toList(Array.from({length:count},(_,i)=>new svg.Line(new svg.Point(2*i,0),new svg.Point(2*i+1,0))));
  return summarize(svg.subpath_with(gaps,new svg.Custom((a,b)=>toList([a,new svg.Line(svg.segment_end(a),svg.segment_start(b)),b]))));
 });
 check('custom removes pairs',count,()=>summarize(svg.subpath_with(lines,new svg.Custom(()=>toList([])))));
}
const report={node:process.version,build:base,rows};
fs.writeFileSync(process.argv[3],JSON.stringify(report,null,2)+'\n');
console.log(rows.map(({label,count,status,kind,edges})=>({label,count,status,kind,edges})));
