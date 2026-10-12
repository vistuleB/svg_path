const fs=require('node:fs'), vm=require('node:vm'), paper=require(process.argv[2]);
if(paper.version!=='0.12.18')throw Error('Requires paper 0.12.18');
paper.setup(new paper.Size(1000,1000));
let block=-1,title; const fixtures=[],blocks=[];
function geometry(item) {
 const children=item instanceof paper.CompoundPath?item.children:[item];
 return {fillRule:item.fillRule,subpaths:children.map(p=>({closed:p.closed,
  curves:p.curves.map(c=>[0,2,4,6].flatMap(i=>{
   const pt=p.globalMatrix.transform(new paper.Point(c.values[i],c.values[i+1]));
   return [pt.x,pt.y];
  }))}))};
}
let source=fs.readFileSync(__dirname+'/upstream/PathItem_Contains.js','utf8')
 .replace(/function testPoint\(item, point, inside, message\) \{[\s\S]*?\n\}\n/,'');
vm.runInNewContext(source,{...paper,Path:paper.Path,Point:paper.Point,Size:paper.Size,
 Rectangle:paper.Rectangle,CompoundPath:paper.CompoundPath,Segment:paper.Segment,
 PathItem:paper.PathItem,QUnit:{module(){}},
 test(name,fn){block++;title=name;paper.project.clear();
  const skip=name.startsWith('Shape#')||name.includes('non-invertible');
  blocks.push({block,title,status:skip?'adapter-required':'extracted'});
  if(!skip)fn();
 },
 testPoint(item,point,expected,message){fixtures.push({id:fixtures.length,block,title,
  geometry:geometry(item),point:[point.x,point.y],expected,message:message||null,
  paperDerivedPoint:title.includes('interiorPoint')});},
 equals(){throw Error('Unhandled assertion');}
});
fs.writeFileSync(__dirname+'/containment.json',JSON.stringify({blocks,fixtures},null,2)+'\n');
console.log(`${fixtures.length} assertions from ${blocks.filter(b=>b.status==='extracted').length}/${blocks.length} blocks`);
