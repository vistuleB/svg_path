import fs from 'node:fs';
const base=process.cwd()+'/test_portable/build/dev/javascript/svg_path';
const g=await import(base+'/svg_path.mjs');
const src=fs.readFileSync(base+'/svg_path/intersections.mjs','utf8');
fs.writeFileSync(base+'/svg_path/probe_endpoints.mjs',src+'\nexport { elizabeth_endpoint_candidates };\n');
const ix=await import(base+'/svg_path/probe_endpoints.mjs');
const text=fs.readFileSync('test/svg_path_paper_intersection_addresses_test.gleam','utf8').split('pub fn paper_address_21_test()')[1].split('let assert Ok(hits)')[0];
const ps=[...text.matchAll(/svg_path.Point\(([^,]+), ([^)]+)\)/g)].map(m=>[Number(m[1]),Number(m[2])]);
const lo=[0,1].map(i=>Math.min(...ps.map(p=>p[i]))),hi=[0,1].map(i=>Math.max(...ps.map(p=>p[i]))),d=hi.map((v,i)=>v-lo[i]);
const plain=r=>r.isOk()?[...(r[0].intersections??r[0])].map(h=>({t:h.left_t,u:h.right_t,p:h.point})):r;
for(const mode of ['original','positive','centered']){
 const pts=ps.map(p=>p.map((v,i)=>mode==='original'?v:100*((v-(lo[i]+(mode==='centered'?d[i]/2:0)))/d[i])));
 const a=new g.CubicBezier(...pts.slice(0,4).map(p=>new g.Point(...p))),b=new g.CubicBezier(...pts.slice(4).map(p=>new g.Point(...p)));
 const magnitude=Math.max(...pts.flat().map(Math.abs)),floor=Math.max(1e-13,magnitude*3.552713678800501e-15);
 console.log(JSON.stringify({mode,bounds:{lo,hi,d},startA:pts[0],startB:pts[4],gap:Math.hypot(...pts[0].map((v,i)=>v-pts[4][i])),internalTolerance:floor,beam:plain(ix.elizabeth_beam_intersections(a,b,new ix.IntersectionOptions(1e-12,64,new ix.NoParameterSnap()))),endpoints:plain(ix.elizabeth_endpoint_candidates(a,b,floor)),relaxedEndpoints:plain(ix.elizabeth_endpoint_candidates(a,b,1e-12))}));
}
const a=new g.CubicBezier(...ps.slice(0,4).map(p=>new g.Point(...p))),b=new g.CubicBezier(...ps.slice(4).map(p=>new g.Point(...p)));
console.log('public centered',JSON.stringify(plain(ix.segment(a,b))));
