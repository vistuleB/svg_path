"""Copied-build experiment; no production source edits."""
from pathlib import Path
import shutil
root=Path(__file__).resolve().parents[2]
target=Path('/tmp/cavalier-semicircle-compensated')
shutil.copytree(root/'test_portable/build/dev/javascript',target,dirs_exist_ok=True)
p=target/'svg_path/svg_path/ellipse.mjs';s=p.read_text().replace('function center_prime(', 'function original_center_prime(',1)
s+='''
// Error-free sum/product building blocks on normalized, moderate operands.
function auditSum(a,b) {const s=a+b,v=s-a;return [s,(a-(s-v))+(b-v)];}
function auditProduct(a,b) {
 const p=a*b,ca=134217729*a,cb=134217729*b;
 const ah=ca-(ca-a),al=a-ah,bh=cb-(cb-b),bl=b-bh;
 return [p,((ah*bh-p)+ah*bl+al*bh)+al*bl];
}
function auditAdd(a,b) {const s=auditSum(a[0],b[0]);return auditSum(s[0],s[1]+a[1]+b[1]);}
function auditMul(a,b) {const p=auditProduct(a[0],b[0]);return auditSum(p[0],p[1]+a[0]*b[1]+a[1]*b[0]+a[1]*b[1]);}
function center_prime(rx,ry,x,y,large,sweep) {
 const scale=2**Math.floor(Math.log2(Math.max(rx,ry,Math.abs(x),Math.abs(y))));
 const a=auditProduct(rx/scale,rx/scale),b=auditProduct(ry/scale,ry/scale);
 const c=auditProduct(x/scale,x/scale),d=auditProduct(y/scale,y/scale);
 const lhs=auditMul(a,b),u=auditMul(a,d),v=auditMul(b,c);
 const gap=auditAdd(auditAdd(lhs,[-u[0],-u[1]]),[-v[0],-v[1]]);
 const den=auditAdd(u,v),q=(gap[0]+gap[1])/(den[0]+den[1]);
 if(!Number.isFinite(q))return original_center_prime(rx,ry,x,y,large,sweep);
 const factor=(large===sweep?-1:1)*Math.sqrt(Math.max(0,q));
 return new EllipsePoint(factor*rx*y/ry,-factor*ry*x/rx);
}
''';p.write_text(s)
