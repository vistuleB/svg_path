"""Isolated generated-JS experiment; does not implement parameter remapping."""
from pathlib import Path
import shutil, re
root=Path(__file__).resolve().parents[2]
dest=Path('/tmp/cavalier-offset-straightening')
shutil.copytree(root/'test_portable/build/dev/javascript', dest, dirs_exist_ok=True)
p=dest/'svg_path/svg_path/offset.mjs'
s=p.read_text()
needle='function offset_segment_arrangement(indexed) {'
assert s.count(needle)==1
s=s.replace(needle,needle+'''
  indexed=$list.map(indexed,item=>{

    const r=$degeneracy.segment_linearize_if_degenerate(item.segment,1e-9);
    if (!r.isOk()) throw r[0];
    if (!(r[0] instanceof Some)) return item;
    const pieces=[...r[0][0]];
    if(pieces.length!==1 || !(pieces[0] instanceof $svg_path.Line)) return item;
    if (!(item.segment instanceof $svg_path.Line)) console.error(JSON.stringify({group:item.group.constructor.name,straightened:item.segment,replacement:pieces[0]}));
    return new IndexedOffsetSegment(item.group,item.subpath_index,pieces[0],item.winding_opinion,item.winding_change);
  });
''')
s=s.replace('export function public_error(error) {', 'export function public_error(error) { console.error(JSON.stringify(error,(k,v)=>v&&typeof v==="object"&&!Array.isArray(v)?{type:v.constructor.name,...v}:v));')
p.write_text(s)
p=dest/'svg_path/svg_path/arrangement.mjs';s=p.read_text()
# Include the enclosing function at every normalization-error construction.
parts=re.split(r'(?=^(?:export )?function )',s,flags=re.M)
for i,part in enumerate(parts):
    match=re.match(r'(?:export )?function ([^(]+)',part)
    if match:
        name=match[1]
        part=part.replace('new Error(InternalError$InternalNormalizationError$const)',f'(console.error(JSON.stringify({{normalizationSite:"{name}"}})), new Error(InternalError$InternalNormalizationError$const))')
        if name=='certify_segment_edge_geometry':
            part=part.replace('normalizationSite:"'+name+'"','normalizationSite:"'+name+'",source,image,segment,source_a,source_b,edge_a,edge_b,tolerance')
        if name=='unique_vertex_for_endpoint_loop':
            part=part.replace('normalizationSite:"'+name+'"','normalizationSite:"'+name+'",endpoint,point,id,found,vertex_tolerance')
        parts[i]=part
p.write_text(''.join(parts))
print(dest)
p=dest/'svg_path/svg_path/internal/overlap_detection.mjs';s=p.read_text()
s=re.sub(r'return new Error\(\s*\$svg_path.Error\$NonAffineOverlapCorrespondence\$const,\s*\);', 'console.error(JSON.stringify({nonAffine:true,left:{type:left.constructor.name,...left},right:{type:right.constructor.name,...right},tolerance}));return new Error($svg_path.Error$NonAffineOverlapCorrespondence$const);',s)
p.write_text(s)
