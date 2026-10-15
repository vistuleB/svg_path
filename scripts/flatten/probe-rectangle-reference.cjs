// Independent orientation check using pinned upstream source, no capture wrappers.
const fs=require('node:fs');
const {createRequire}=require('node:module');
const path=require('node:path');
const req=createRequire(path.join(__dirname,'upstream/package.json'));
process.chdir(path.join(__dirname,'upstream'));
req('@babel/register')({extensions:['.js'],ignore:[/node_modules/],cache:false});
const F=req('./index.js');
const {subtract}=req('./src/algorithms/boolean_op.js');
const make=ps=>new F.Polygon(ps.map(([x,y])=>F.point(x,y)));
const a=make([[200,0],[200,200],[0,200],[0,0]]);
const b=make([[100,0],[100,200],[200,200],[200,0]]);
const rows=[b,b.clone().reverse()].map(c=>{
 const result=subtract(a,c);
 return {leftOrientation:a.orientation(),rightOrientation:c.orientation(),leftValid:a.isValid(),rightValid:c.isValid(),area:result.area(),samples:[50,150].map(x=>({x,y:100,inside:result.contains(F.point(x,100))}))};
});
fs.writeFileSync(path.join(__dirname,'remaining-rectangle-reference.json'),JSON.stringify(rows,null,2)+'\n');
console.log(rows);
