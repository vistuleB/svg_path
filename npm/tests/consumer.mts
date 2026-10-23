import {parse,measure,serialize,unwrap,Point,Line,Nonzero,csg,area,pathTryMapPoints,transform, type Path, type Point as PointType, type Result} from 'svg-path-geometry';
import * as offsets from 'svg-path-geometry/offset';
import * as transformParse from 'svg-path-geometry/transform/parse';
const p: Path=unwrap(parse.path('M0 0 L3 4'));
const length: number=unwrap(measure.pathLength(p));
const string: string=serialize.path(p);
const point: PointType={x:1,y:2};
const line=Line(point,Point(2,3));
const options={...offsets.defaultOptions(),innerJoin:offsets.InnerRound()};
const result=offsets.pathWith(p,1,offsets.Round(),offsets.Butt(),options,offsets.defaultSingleOffsetTrimming());
if(result.ok)serialize.path(result.value);else console.log(result.error.kind);
const mapped=pathTryMapPoints(p,q=>({ok:false as const,error:{custom:'reason'}}));
if(!mapped.ok && mapped.error.kind==='PointMapFunctionError') {
 const message: string=mapped.error.error.custom;
}
const explicit:Result<number,string>={ok:true,value:3};
// @ts-expect-error Results require narrowing before accessing success values.
parse.path('bad').value;
// @ts-expect-error Points require numeric coordinates.
Point('x',0);
// @ts-expect-error Opaque matrices cannot be constructed as plain records.
const matrix:transform.Matrix={};
// @ts-expect-error Multi-variant values require the kind discriminator.
csg.union(p,p,{});
void [length,string,line,explicit,Nonzero,area,transformParse];
