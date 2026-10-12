// Preserve upstream literals, constructor inputs and full-precision geometry.
const fs=require('node:fs'),vm=require('node:vm'),paper=require(process.argv[2]);
if(paper.version!=='0.12.18')throw Error('Requires paper 0.12.18');
paper.setup(new paper.Size(1000,1000));let last,block=-1,title;const blocks=[],fixtures=[];
for(const kind of ['Rectangle','Circle','Ellipse','Arc','RegularPolygon','Star','Line']){
 const original=paper.Path[kind];paper.Path[kind]=function(...args){const item=Reflect.construct(original,args);last={kind,args:JSON.parse(JSON.stringify(args)),closed:item.closed,curves:item.curves.map(c=>c.values.slice()),points:item.segments.map(s=>[s.point.x,s.point.y])};return item;};
}
vm.runInNewContext(fs.readFileSync(__dirname+'/upstream/Path_Constructors.js','utf8'),{paper,Path:paper.Path,Point:paper.Point,Rectangle:paper.Rectangle,QUnit:{module(){}},test(name,fn){block++;title=name;paper.project.clear();last=null;blocks.push({block,title});fn();},equals(actual,expected,message){if(typeof actual==='function')actual=actual();fixtures.push({id:fixtures.length,block,title,...last,expected,actual,message:message??null});}});
fs.writeFileSync(__dirname+'/constructors.json',JSON.stringify({blocks,fixtures},null,2)+'\n');console.log(`${fixtures.length} assertions from ${blocks.length} blocks`);
