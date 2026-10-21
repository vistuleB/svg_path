"""Instrument only a disposable focused JS build after compiling tests."""
from pathlib import Path
p=Path('/tmp/csg-affine-focused/build/dev/javascript/svg_path/svg_path/internal/arc_reconstruction.mjs')
assert 'function interval_impl(' not in p.read_text(), 'Rebuild the focused JS module before instrumenting again'
s=p.read_text().replace('function interval(original,','function interval_impl(original,',1)
s+='''
function interval(original, parent, from, to, start, end, tolerance, depth) {
 const r=interval_impl(original,parent,from,to,start,end,tolerance,depth);
 if(r.isOk() && Array.from(r[0]).length===1){
  const segment=Array.from(r[0])[0];let maximum=0;
  for(let i=0;i<=128;i++){
   const p=$ellipse.arc_point(parent,from+(to-from)*i/128);
   const q=$svg_path.segment_point(segment,i/128);
   if(!q.isOk())throw new globalThis.Error('invalid reconstructed sample');
   maximum=Math.max(maximum,Math.hypot(p.x-q[0].x,p.y-q[0].y));
  }
  (globalThis.arcChecks??=[]).push({from,to,depth,maximum,tolerance});
 }
 return r;
}
'''
p.write_text(s)
