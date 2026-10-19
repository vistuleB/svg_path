from pathlib import Path
import shutil,re
root=Path(__file__).resolve().parents[2];target=Path('/tmp/cavalier-short-arc-overlap')
shutil.copytree(root/'test_portable/build/dev/javascript',target,dirs_exist_ok=True)
p=target/'svg_path/svg_path/internal/overlap_detection.mjs';s=p.read_text()
for name in ['endpoint_projections','arc_correspondence_directions_agree','sampled_overlap_valid','affine_correspondence_valid','merge_overlap_list']:
 pattern=r'(export )?function '+name+r'\('
 m=re.search(pattern,s)
 if not m: continue
 s=re.sub(pattern,'function audit_original_'+name+'(',s,count=1)
 s+='\n'+('export ' if m.group(1) else '')+f'''function {name}(...args) {{
 const result=audit_original_{name}(...args);
 console.error(JSON.stringify({{function:'{name}',args:args,result}}));return result;
 }}\n'''
p.write_text(s)
