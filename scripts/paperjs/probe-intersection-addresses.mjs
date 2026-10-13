// Read-only audit of pinned intersection addresses and local classifications.
// Run after scripts/test-portable javascript. Optional fixture id argument.
import fs from 'node:fs';
import * as s from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as ix from '../../test_portable/build/dev/javascript/svg_path/svg_path/intersections.mjs';
import * as encounters from '../../test_portable/build/dev/javascript/svg_path/svg_path/encounters.mjs';
import {toList, Ok} from '../../test_portable/build/dev/javascript/svg_path/gleam.mjs';
const fixtures=JSON.parse(fs.readFileSync(new URL('./intersections.json',import.meta.url)));
const shape=g=>{
 let p=s.subpath_assert(toList(g.curves.map(c=>new s.CubicBezier(...[0,2,4,6].map(i=>new s.Point(c[i],c[i+1]))))));
 return g.closed?s.subpath_assert_close(p):p;
};
const clean=x=>x&&typeof x==='object'?{type:x.constructor.name,...Object.fromEntries(Object.entries(x).map(([k,v])=>[k,clean(v)]))}:x;
const dist=(a,b)=>Math.hypot(a.x-b.x,a.y-b.y);
const results=[];
for(const [id,f] of fixtures.entries()){
 if(f.method==='getCrossings'||(process.argv[2]!==undefined&&id!==Number(process.argv[2])))continue;
 const a=shape(f.left),b=f.right?shape(f.right):a;
 const pathA=s.subpath_as_path(a),pathB=s.subpath_as_path(b);
 const raw=f.right?ix.path(pathA,pathB):ix.path_self(pathA);
 const record={id,title:f.title,query:raw instanceof Ok?'Ok':raw[0].constructor.name,expected:f.expected,hits:[]};
 let hits;
 if(raw instanceof Ok){hits=[...raw[0]].map(h=>({point:h.point,left:f.right?[...h.left_parameters].map(p=>p.at):[h.parameters[0].at],right:f.right?[...h.right_parameters].map(p=>p.at):[h.parameters[1].at]}));}
 else if(raw[0] instanceof s.OverlappingSegments&&f.right){
  const found=encounters.subpath(a,b);
  if(!(found instanceof Ok)){record.encounterError=clean(found);results.push(record);continue;}
  record.overlaps=[...found[0].overlaps].map(clean);
  hits=[...found[0].intersections].map(h=>({point:h.point,left:[...h.left_parameters],right:[...h.right_parameters]}));
 }else{results.push(record);continue;}
 for(const hit of hits){
  const pairs=[];
  for(const l of hit.left)for(const r of hit.right){
   const lp=s.subpath_point(a,l),rp=s.subpath_point(b,r);
   const classification=ix.classify_subpath_intersection(a,b,l,r);
   pairs.push({left:l,right:r,leftEvaluation:clean(lp),rightEvaluation:clean(rp),
    separation:lp instanceof Ok&&rp instanceof Ok?dist(lp[0],rp[0]):null,
    leftPointResidual:lp instanceof Ok?dist(lp[0],hit.point):null,rightPointResidual:rp instanceof Ok?dist(rp[0],hit.point):null,
    classification:clean(classification)});
  }
  record.hits.push({point:hit.point,pairs});
 }
 results.push(record);
 console.log(id,f.title,record.query,'hits',record.hits.length,'classes',record.hits.flatMap(h=>h.pairs.map(p=>p.classification['0']?.type)).join(','));
 fs.writeFileSync(new URL(process.argv[2]===undefined?'./intersection-address-findings.json':`./intersection-address-${process.argv[2]}-findings.json`,import.meta.url),JSON.stringify({tolerance:ix.default_options().tolerance,results},null,2)+'\n');
}
