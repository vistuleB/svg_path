// Execute only geometric blocks of the pinned upstream file. Paper supplies
// construction/transforms; expected rectangles remain the upstream literals.
const fs=require('node:fs'),vm=require('node:vm');
const paper=require(process.argv[2]);
if(paper.version!=='0.12.18')throw Error('Requires paper 0.12.18');
paper.setup(new paper.Size(1000,1000));
const selected=new Set([7,8,9,10,11,12,13,14,16,17,18,19,20,21,22,25,26,27,28,33,34]);
let block=-1,title,last=null,depth=0;const blocks=[],fixtures=[],omitted=[];
function snapshot(item,property){
 const paths=item instanceof paper.CompoundPath?item.children:[item];
 return {property,subpaths:paths.map(p=>({closed:p.closed,start:p.firstSegment?[p.firstSegment.point.x,p.firstSegment.point.y]:null,curves:p.curves.map(c=>c.values.slice())})),matrix:item.matrix.values.slice(),stroke:!!item.strokeColor,width:item.strokeWidth,join:item.strokeJoin,cap:item.strokeCap,miterLimit:item.miterLimit,strokeScaling:item.strokeScaling,zoom:paper.view.zoom};
}
for(const cls of [paper.Path,paper.CompoundPath])for(const property of ['bounds','strokeBounds','internalBounds','position']){
 let proto=cls.prototype,desc;while(proto&&!desc){desc=Object.getOwnPropertyDescriptor(proto,property);proto=Object.getPrototypeOf(proto);}
 Object.defineProperty(cls.prototype,property,{configurable:true,get(){const outer=depth++===0;try{return desc.get.call(this);}finally{depth--;if(outer)last=snapshot(this,property);}},set:desc.set});
}
const context={paper,Path:paper.Path,CompoundPath:paper.CompoundPath,Point:paper.Point,Segment:paper.Segment,Rectangle:paper.Rectangle,view:paper.view,QUnit:{module(){}},test(name,fn){block++;title=name;last=null;paper.project.clear();paper.view.zoom=1;blocks.push({block,title,status:selected.has(block)?'extracted-geometry-subset':'scene-api-not-adapted'});if(selected.has(block))fn();},equals(actual,expected,message){if(typeof actual==='function'){last=null;actual=actual();}const call=last;last=null;if(!call||!(expected instanceof paper.Rectangle||expected instanceof paper.Point)){omitted.push({block,title,message:message??null,reason:'Non-bounds assertion (segment strings or scene hit testing).'});return;}fixtures.push({id:fixtures.length,block,title,...call,expected:expected instanceof paper.Rectangle?[expected.x,expected.y,expected.width,expected.height]:[expected.x,expected.y],paperActual:actual instanceof paper.Rectangle?[actual.x,actual.y,actual.width,actual.height]:[actual.x,actual.y],message:message??null});}};
vm.runInNewContext(fs.readFileSync(__dirname+'/upstream/Item_Bounds.js','utf8'),context);
fs.writeFileSync(__dirname+'/bounds.json',JSON.stringify({blocks,fixtures,omitted},null,2)+'\n');
console.log(`${fixtures.length} comparisons; ${selected.size}/${blocks.length} blocks; ${omitted.length} non-bounds assertions omitted`);
