from pathlib import Path
import runpy
runpy.run_path(str(Path(__file__).with_name('prepare-near-tangent-trace.py')))
p=Path('/tmp/cavalier-near-tangent-offset-trace/svg_path/svg_path/intersections.mjs');s=p.read_text()
s=s.replace('function nonconstant_segment_intersections(left, right, options) {', '''function nonconstant_segment_intersections(left, right, options) {
 const candidate=audit_shared_circles(left,right,options);
 if(candidate!==null)return candidate;
''',1)
s+='''
function audit_shared_circles(left,right,options) {
 if(!(left instanceof Arc && right instanceof Arc))return null;
 const shared=[];
 for(const [a,t] of [[left.start,0],[left.end,1]])for(const [b,u] of [[right.start,0],[right.end,1]])if(a.x===b.x&&a.y===b.y)shared.push(new SegmentIntersection(t,u,a));
 if(!shared.length)return null;
 const aa=$svg_path.arc_center_data(left),bb=$svg_path.arc_center_data(right);
 if(!aa.isOk()||!bb.isOk())return null;
 const a=aa[0],b=bb[0];if(a.radius.x!==a.radius.y||b.radius.x!==b.radius.y)return null;
 const dx=b.center.x-a.center.x,dy=b.center.y-a.center.y,len=Math.hypot(dx,dy);
 if(len<=Math.max(a.radius.x,b.radius.x)*1e-8)return null;
 const nx=-dy/len,ny=dx/len,p=shared[0].point;
 const travel=-2*((p.x-a.center.x)*nx+(p.y-a.center.y)*ny);
 const q=new Point(p.x+travel*nx,p.y+travel*ny);
 const threshold=numerical_search_tolerance(left,right,options);if(!threshold.isOk())return null;
 const l=$query.segment_projection(q,left),r=$query.segment_projection(q,right);
 if(!l.isOk()||!r.isOk())return null;
 if(l[0].distance<=threshold[0]&&r[0].distance<=threshold[0]&&!shared.some(h=>h.left_t===l[0].at&&h.right_t===r[0].at))shared.push(new SegmentIntersection(l[0].at,r[0].at,q));
 console.error('CIRCLEEXPERIMENT',JSON.stringify({shared:shared.map(h=>[h.left_t,h.right_t]),travel}));
 return new Ok(toList(shared));
}
'''
p.write_text(s)
