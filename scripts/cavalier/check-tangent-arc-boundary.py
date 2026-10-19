"""Independent line/circle comparison against analytic inward-offset boundary.
Uses exported native segments; does not call native intersection/projection.
"""
import json, math
from pathlib import Path
root=Path(__file__).resolve().parent
raw=json.loads((root/'tangent-arc-contours.json').read_text())
r=math.sqrt(2)
p=lambda v:(v['x'],v['y'])
d=math.dist
# One lobe in positive traversal; the other is its 180 degree rotation.
vs=[(r,r),(12-r,r),(12-r,10),(11,11),(10,12-r),(r,12-r)]
centers={2:(12,10),3:(10,12)}
ideal=[]
for flip in [False,True]:
 trans=lambda p:(22-p[0],22-p[1]) if flip else p
 for i,a in enumerate(vs):
  b=vs[(i+1)%len(vs)]
  ideal.append(dict(start=trans(a),end=trans(b),center=trans(centers[i]) if i in centers else None))
seen=set(); long_bounds=[]; seam_bounds=[]; small_length=0
for contour in raw['contours']:
 for item in contour['segments']:
  s=item['segment']; a,b=p(s['start']),p(s['end']); c=item['center']
  length=r*abs(math.radians(c['delta_angle'])) if c else d(a,b)
  if length<1e-5:
   # Every point is at most arc length from its first endpoint. The ideal
   # boundary contains (11,11), so this bounds all extra seam geometry.
   bound=d(a,(11,11))+length
   assert bound<1e-6
   seam_bounds.append(bound);small_length+=length;continue
  candidates=[(max(d(a,e['start']),d(b,e['end'])),i,False) for i,e in enumerate(ideal) if bool(c)==bool(e['center'])]
  candidates += [(max(d(a,e['end']),d(b,e['start'])),i,True) for i,e in enumerate(ideal) if bool(c)==bool(e['center'])]
  _,i,rev=min(candidates); e=ideal[i];assert i not in seen;seen.add(i)
  start,end=(e['end'],e['start']) if rev else (e['start'],e['end'])
  if c:
   center=p(c['center']); radius=c['radius']['x']; assert radius==c['radius']['y']
   angle=lambda q,ctr:math.atan2(q[1]-ctr[1],q[0]-ctr[0])
   wrap=lambda x:(x+math.pi)%(2*math.pi)-math.pi
   e0=abs(wrap(math.radians(c['start_angle'])-angle(start,e['center'])))
   e1=abs(wrap(math.radians(c['start_angle']+c['delta_angle'])-angle(end,e['center'])))
   # Linear interpolation of corresponding angular parameters bounds the
   # entire arcs in both directions, not just sampled points.
   expected_delta=math.pi/4 if rev else -math.pi/4
   assert abs(math.radians(c['delta_angle'])-expected_delta)<1e-5
   bound=d(center,e['center'])+abs(radius-r)+r*max(e0,e1)
  else:
   # Corresponding linear interpolation gives the segment bound.
   bound=max(d(a,start),d(b,end))
  assert bound<1e-6
  long_bounds.append(bound)
assert len(seen)==12
polygon_area=sum(vs[i][0]*vs[(i+1)%6][1]-vs[(i+1)%6][0]*vs[i][1] for i in range(6))/2
lobe_area=polygon_area+r*r*(-math.pi/4+math.sin(math.pi/4))
lobe_length=4*(12-2*r)+r*math.pi/2 # four straight edges have length 12-2r
# The two lines adjacent to arcs instead end at coordinate 10.
lobe_length=sum(d(e['start'],e['end']) if not e['center'] else r*math.pi/4 for e in ideal[:6])
result=dict(ideal_lobe_area=lobe_area,ideal_lobe_length=lobe_length,matched_ideal_pieces=len(seen),native_segments=sum(len(c['segments']) for c in raw['contours']),extra_seam_pieces=len(seam_bounds),extra_seam_length=small_length,max_corresponding_piece_bound=max(long_bounds),max_extra_seam_bound=max(seam_bounds),symmetric_boundary_distance_upper_bound=max(long_bounds+seam_bounds),method='Analytic line/arc parameter correspondence plus arc-length seam enclosure; double-precision arithmetic, not interval arithmetic.')
print(json.dumps(result,indent=2))
