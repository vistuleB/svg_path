"""Capture full upstream Boolean curves in the isolated instrumented checkout."""
from pathlib import Path
import runpy
runpy.run_path(str(Path(__file__).with_name('prepare-capture.py')))
p=Path('/tmp/cavalier-audit-capture/cavalier_contours/src/audit_capture.rs')
s=p.read_text()
s=s.replace(r'\"vertices\":{}}}',r'\"vertices\":{},\"geometry\":{}}}')
s=s.replace('p.is_closed(),p.vertex_count())','p.is_closed(),p.vertex_count(),pline(p))')
p.write_text(s)
