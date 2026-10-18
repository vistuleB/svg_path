"""Instrument an isolated copy; the pinned archive remains unchanged."""
from pathlib import Path
import shutil
root=Path(__file__).resolve().parent
out=Path('/tmp/cavalier-audit-capture')
shutil.copytree(root/'upstream',out,dirs_exist_ok=True)
lib=out/'cavalier_contours/src/lib.rs'
lib.write_text(lib.read_text()+'\n#[doc(hidden)]\npub mod audit_capture;\n')
(out/'cavalier_contours/src/audit_capture.rs').write_text(r'''
use crate::polyline::PlineSource;
use std::cell::Cell;
thread_local! { static DEPTH: Cell<usize> = const { Cell::new(0) }; }
pub struct Guard { pub outer: bool }
impl Guard { pub fn new() -> Self { let n=DEPTH.with(|d|{let n=d.get();d.set(n+1);n}); Self{outer:n==0} } }
impl Drop for Guard { fn drop(&mut self) { DEPTH.with(|d|d.set(d.get()-1)); } }
pub fn pline<P:PlineSource+?Sized>(p:&P)->String {
 let vs=p.iter_vertexes().map(|v|format!("[{:?},{:?},{:?}]",v.x,v.y,v.bulge)).collect::<Vec<_>>().join(",");
 format!("{{\"closed\":{},\"vertices\":[{}]}}",p.is_closed(),vs)
}
pub fn props<P:PlineSource+?Sized>(p:&P)->String {
 let bounds=match p.extents(){None=>"null".into(),Some(b)=>format!("[{:?},{:?},{:?},{:?}]",b.min_x,b.min_y,b.max_x,b.max_y)};
 format!("{{\"area\":{:?},\"length\":{:?},\"bounds\":{},\"closed\":{},\"vertices\":{}}}",p.area(),p.path_length(),bounds,p.is_closed(),p.vertex_count())
}
pub fn emit(kind:&str,fields:String){
 let exe=std::env::current_exe().unwrap();let name=exe.file_name().unwrap().to_string_lossy();
 println!("@AUDIT@{{\"kind\":{:?},\"binary\":{:?},\"test\":{:?},{}}}",kind,name,std::thread::current().name().unwrap_or("unknown"),fields);
}
''')
def wrap(rel,name,fields,kind=None):
 p=out/'cavalier_contours/src'/rel;s=p.read_text();start=s.index('fn '+name+'(') if 'fn '+name+'(' in s else s.index('fn '+name+'<')
 a=s.index('{',start);depth=1;b=a+1
 while depth:
  if s[b]=='{':depth+=1
  elif s[b]=='}':depth-=1
  b+=1
 body=s[a+1:b-1]
 new='\nlet audit_guard=crate::audit_capture::Guard::new();\nlet audit_result=(||{'+body+'})();\nif audit_guard.outer { use crate::audit_capture::{pline,props,emit}; emit("'+(kind or name)+'",'+fields+'); }\naudit_result\n'
 p.write_text(s[:a+1]+new+s[b-1:])
wrap('polyline/traits.rs','parallel_offset_opt',r'''format!("\"input\":{},\"offset\":{:?},\"options\":{:?},\"result\":[{}]",pline(self),offset,format!("{:?}",options),audit_result.iter().map(|p|props(p)).collect::<Vec<_>>().join(","))''','offset')
wrap('polyline/traits.rs','boolean_opt',r'''format!("\"input\":{},\"other\":{},\"operation\":{:?},\"options\":{:?},\"positive\":[{}],\"negative\":[{}]",pline(self),pline(other),format!("{:?}",operation),format!("{:?}",options),audit_result.pos_plines.iter().map(|p|props(&p.pline)).collect::<Vec<_>>().join(","),audit_result.neg_plines.iter().map(|p|props(&p.pline)).collect::<Vec<_>>().join(","))''','boolean')
wrap('polyline/traits.rs','contains_opt',r'''format!("\"input\":{},\"other\":{},\"result\":{:?}",pline(self),pline(other),format!("{:?}",audit_result))''','contains')
wrap('polyline/traits.rs','winding_number',r'''format!("\"input\":{},\"point\":[{:?},{:?}],\"result\":{}",pline(self),point.x,point.y,audit_result)''')
for name in ['area','path_length','extents']:
 wrap('polyline/traits.rs',name,r'''format!("\"input\":{},\"result\":{:?}",pline(self),format!("{:?}",audit_result))''')
for rel,name,args in [
 ('core/math/line_line_intersect.rs','line_line_intr',['v1','v2','u1','u2','epsilon']),
 ('core/math/line_circle_intersect.rs','line_circle_intr',['p0','p1','radius','circle_center','epsilon']),
 ('core/math/circle_circle_intersect.rs','circle_circle_intr',['radius1','center1','radius2','center2','epsilon']),
 ('polyline/pline_seg_intersect.rs','pline_seg_intr',['v1','v2','u1','u2','pos_equal_eps'])]:
 fields='format!("'+','.join('\\"'+a+'\\":{:?}' for a in args)+',\\"result\\":{:?}",'+','.join('format!("{:?}",'+a+')' for a in args)+',format!("{:?}",audit_result))'
 wrap(rel,name,fields)
# Shape entry point protects its internal per-polyline calls from capture.
wrap('shape_algorithms/mod.rs','parallel_offset',r'''format!("\"inputs\":[{}],\"offset\":{:?},\"result\":[{}]",self.ccw_plines.iter().chain(self.cw_plines.iter()).map(|p|pline(&p.polyline)).collect::<Vec<_>>().join(","),offset,audit_result.ccw_plines.iter().chain(audit_result.cw_plines.iter()).map(|p|props(&p.polyline)).collect::<Vec<_>>().join(","))''','shape_offset')
print(out)
