"""Change only source-normalization tolerance in a copied generated build."""
from pathlib import Path
import shutil
root=Path(__file__).resolve().parents[2];target=Path('/tmp/cavalier-shape-normalization')
shutil.copytree(root/'test_portable/build/dev/javascript',target,dirs_exist_ok=True)
p=target/'svg_path/svg_path/offset.mjs';s=p.read_text().replace('export function normalize_source_subpath(subpath, options) {','function original_normalize_source_subpath(subpath, options) {',1)
s+='''
export function normalize_source_subpath(subpath, options) {
 const fitting=new FittingOptions(0.0001, options.fitting.samples, options.fitting.max_depth);
 return original_normalize_source_subpath(subpath,new Options(fitting,options.stalled_offset_diameter,options.tangent_heal_angle_degrees,options.inner_join));
}
''';p.write_text(s)
s=(root/'scripts/cavalier/probe-shape-case3.mjs').read_text().replace('../../test_portable/build/dev/javascript',str(target))
(root/'scripts/cavalier/probe-shape-case3-normalization-experiment.mjs').write_text(s)
