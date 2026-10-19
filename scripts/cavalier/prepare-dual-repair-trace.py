"""Observe the repaired offset's internal failure without changing its result."""
from pathlib import Path
import shutil
root = Path(__file__).resolve().parents[2]
target = Path('/tmp/cavalier-dual-repair-trace')
shutil.copytree(root/'scripts/cavalier/probe/build/dev/javascript', target, dirs_exist_ok=True)
for name in ['offset', 'arrangement']:
    p = target/f'svg_path/svg_path/{name}.mjs'
    s = p.read_text().replace('export function public_error(error) {',
        'export function public_error(error) {\n(globalThis.auditErrors ??= []).push({module: "'+name+'", type: error.constructor.name, inner_error_type: error.error?.constructor?.name, ...error});', 1)
    if name == 'arrangement':
        s = s.replace('export function dual(graph) {', 'function original_dual(graph) {', 1)
        s += '''
export function dual(graph) {
 const r=original_dual(graph);
 (globalThis.auditDualResults??=[]).push({ok:r.isOk(),result:r.isOk()?[...r[0].faces].length:r[0].constructor.name});
 if(!r.isOk())globalThis.auditFailedGraph={vertices:[...graph.vertices],edges:[...graph.edges],cyclic_orders:[...graph.cyclic_orders]};
 return r;
}
'''
    p.write_text(s)
