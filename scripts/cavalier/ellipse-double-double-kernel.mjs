// Experimental only. Shared by the isolated accuracy and dispatch probes.
const dd=x=>[x,0],neg=a=>[-a[0],-a[1]];
function sum(a,b){const h=a+b,v=h-a;return [h,(a-(h-v))+(b-v)];}
function product(a,b){const h=a*b,ca=134217729*a,cb=134217729*b,ah=ca-(ca-a),bh=cb-(cb-b),al=a-ah,bl=b-bh;return [h,((ah*bh-h)+ah*bl+al*bh)+al*bl];}
function add(a,b){const s=sum(a[0],b[0]);return sum(s[0],s[1]+a[1]+b[1]);}
const sub=(a,b)=>add(a,neg(b));
function mul(a,b){const p=product(a[0],b[0]);return sum(p[0],p[1]+a[0]*b[1]+a[1]*b[0]+a[1]*b[1]);}
function div(a,b){const q=a[0]/b[0];let r=sub(a,mul(dd(q),b));const q2=r[0]/b[0];r=sub(r,mul(dd(q2),b));return add(sum(q,q2),dd((r[0]+r[1])/b[0]));}
function sqrt(a){if(a[0]===0&&a[1]===0)return dd(0);let x=dd(Math.sqrt(a[0]));for(let i=0;i<2;i++)x=mul(dd(.5),add(x,div(a,x)));return x;}
const val=a=>a[0]+a[1],positive=a=>a[0]>0||(a[0]===0&&a[1]>0);
function sincos(degrees){
 // Reduce first, then use exact quadrant identities. Tested finite angles only.
 const reduced=degrees%360,q=Math.round(reduced/90),r=reduced-q*90;
 const x=div(mul(dd(r),[3.141592653589793,1.2246467991473532e-16]),dd(180));
 const xx=neg(mul(x,x));let s=x,c=dd(1),st=x,ct=dd(1);
 for(let n=1;n<=18;n++){st=div(mul(st,xx),dd(2*n*(2*n+1)));ct=div(mul(ct,xx),dd((2*n-1)*2*n));s=add(s,st);c=add(c,ct);}
 switch((q%4+4)%4){case 0:return [s,c];case 1:return [c,neg(s)];case 2:return [neg(s),neg(c)];default:return [neg(c),s];}
}
export function solve(a){
 const [s,c]=sincos(a.x_axis_rotation);
 // Normalize by an exact power of two. Scope: moderate finite input exponents.
 const magnitude=Math.max(Math.abs(a.radius.x),Math.abs(a.radius.y),Math.abs(a.start.x),Math.abs(a.start.y),Math.abs(a.end.x),Math.abs(a.end.y));
 const scale=2**Math.floor(Math.log2(magnitude));
 const ax=dd(a.start.x/scale),ay=dd(a.start.y/scale),bx=dd(a.end.x/scale),by=dd(a.end.y/scale);
 let rx=dd(Math.abs(a.radius.x)/scale),ry=dd(Math.abs(a.radius.y)/scale);
 const dx=mul(dd(.5),sub(ax,bx)),dy=mul(dd(.5),sub(ay,by));
 const x=add(mul(c,dx),mul(s,dy)),y=sub(mul(c,dy),mul(s,dx));
 const rx2=mul(rx,rx),ry2=mul(ry,ry);
 const den=add(mul(rx2,mul(y,y)),mul(ry2,mul(x,x))),rprod=mul(rx2,ry2),gap=sub(rprod,den);
 const enlarged=!positive(gap);let cpX=dd(0),cpY=dd(0);
 if(positive(gap)){
  let k=sqrt(div(gap,den));if(a.large_arc===a.sweep)k=neg(k);
  cpX=div(mul(mul(k,rx),y),ry);cpY=neg(div(mul(mul(k,ry),x),rx));
 }else if(positive(neg(gap))){const factor=sqrt(div(den,rprod));rx=mul(rx,factor);ry=mul(ry,factor);}
 const cx=add(mul(dd(.5),add(ax,bx)),sub(mul(c,cpX),mul(s,cpY)));
 const cy=add(mul(dd(.5),add(ay,by)),add(mul(s,cpX),mul(c,cpY)));
 return {center:{x:val(cx)*scale,y:val(cy)*scale},radius:{x:val(rx)*scale,y:val(ry)*scale},radius_enlarged:enlarged,gap:val(gap)};
}
