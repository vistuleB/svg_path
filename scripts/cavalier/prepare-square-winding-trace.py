from pathlib import Path
import shutil
root=Path(__file__).resolve().parents[2]
out=Path('/tmp/cavalier-square-winding')
shutil.copytree(root/'test_portable/build/dev/javascript',out,dirs_exist_ok=True)
p=out/'svg_path/svg_path/offset.mjs';s=p.read_text()
old='''          return new Ok(
            winding_pair_matches_opinion(expected, measured[0], measured[1]),
          );'''
assert s.count(old)==1
s=s.replace(old,'''          const keep = winding_pair_matches_opinion(expected, measured[0], measured[1]);
          console.error(JSON.stringify({distance:globalThis.auditDistance,edge,expected,measured,keep}));
          return new Ok(keep);''')
p.write_text(s)
print(out)
