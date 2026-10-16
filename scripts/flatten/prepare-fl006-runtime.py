"""Diagnostic generated-runtime copy only: baseline, closest, or budget mode."""
from pathlib import Path
import shutil
repo = Path(__file__).resolve().parents[2]
root=Path('/tmp/fl006-runtime')
shutil.copytree(repo/'test_portable/build/dev/javascript',root,dirs_exist_ok=True)
p=root/'svg_path/svg_path/intersections.mjs'
s=p.read_text()
s += '\nexport { elizabeth_window_overlaps, elizabeth_terminal_candidates, WindowPreservingWindow };\n'
s=s.replace('let kept = selection[0];','''let kept = selection[0];
 const contains = w => w.left_from <= .4491226685739814 && w.left_to >= .4491226685739814 && w.right_from <= .5001326962232043 && w.right_to >= .5001326962232043;
 console.log(JSON.stringify({generation,pending:[...pending].length,survivors:[...survivors].length,kept:[...kept].length,rootPending:[...pending].filter(x=>contains(x[0])),rootSurvivors:[...survivors].filter(x=>contains(x[0])),rootKept:[...kept].filter(x=>contains(x[0]))}));''')
p.write_text(s)
s=p.read_text()
s=s.replace('let crossings = $list.filter(ranked,', '''const rows=[...ranked];
 console.log('RANK',JSON.stringify(rows.map((x,i)=>({rank:i+1,window:x[0][0],crossing:x[1],score:x[2],location:x[3]})).filter(x=>x.window.left_from<=.4491226685739814 && x.window.left_to>=.4491226685739814 && x.window.right_from<=.5001326962232043 && x.window.right_to>=.5001326962232043)));
 let crossings = $list.filter(ranked,''')
import sys
mode=sys.argv[1] if len(sys.argv)>1 else 'baseline'
if mode=='closest':
 s=s.replace('let parameters$1 = _block;', '''const cp=window_preserving_chord_closest_parameters(first[0][0],last[0][0],first[0][1],last[0][1]);
 let parameters$1 = $list.append(_block,toList([[a+cp[0]*(b-a),c+cp[1]*(d-c)]]));''')
if mode=='budget':
 s=s.replace('let total_budget = crossing_budget + other_budget;', 'let total_budget = 10000;')
p.write_text(s)
