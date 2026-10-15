"""Copy the generated runtime and expose private functions for diagnosis only."""
from pathlib import Path
import tempfile,shutil
source=Path(__file__).resolve().parents[2]/'test_portable/build/dev/javascript'
target=Path(tempfile.mkdtemp(prefix='flatten-topology-'))/'javascript'
shutil.copytree(source,target)
p=target/'svg_path/svg_path/csg.mjs'
p.write_text(p.read_text()+'\nexport {boolean_from_arrangement as diagnostic_boolean,UnionOperation,IntersectionOperation,DifferenceOperation};\n')
p=target/'svg_path/svg_path/arrangement.mjs'
p.write_text(p.read_text()+'\nexport {cyclic_order_samples_at_radius as diagnostic_samples};\n')
print(target.as_uri()+'/')
