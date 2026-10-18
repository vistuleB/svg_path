from importlib.machinery import SourceFileLoader
from pathlib import Path
m=SourceFileLoader('capture',str(Path(__file__).with_name('prepare-capture.py'))).load_module()
for name,args in [
 ('seg_arc_radius_and_center',[]),('seg_length',[]),('seg_midpoint',[]),('seg_bounding_box',[]),('seg_fast_approx_bounding_box',[]),
 ('seg_split_at_point',['point_on_seg','pos_equal_eps']),('seg_tangent_vector',['point_on_seg']),
 ('seg_closest_point',['point','epsilon']),('seg_distance_is_greater_than',['point','distance','epsilon']),('dist_from_segment_start',['point','pos_equal_eps'])]:
 args=['v1','v2']+args
 fields='format!("'+','.join('\\"'+a+'\\":{:?}' for a in args)+',\\"result\\":{:?}",'+','.join('format!("{:?}",'+a+')' for a in args)+',format!("{:?}",audit_result))'
 m.wrap('polyline/pline_seg.rs',name,fields)
m.wrap('polyline/traits.rs','find_point_at_path_length',r'''format!("\"input\":{},\"distance\":{:?},\"result\":{:?}",pline(self),target_path_length,format!("{:?}",audit_result))''')
