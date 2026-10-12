// Preserve the pinned node-model assertions without claiming curve equivalence.
const fs=require('node:fs'),vm=require('node:vm'),paper=require(process.argv[2]);
if(paper.version!=='0.12.18')throw Error('Requires paper 0.12.18');
paper.setup(new paper.Size(1000,1000));
let block=-1,title,beforeReverse=null;const blocks=[],fixtures=[];
const reverse=paper.Segment.prototype.reverse;
paper.Segment.prototype.reverse=function(...args){beforeReverse={point:[this.point.x,this.point.y],handleIn:[this.handleIn.x,this.handleIn.y],handleOut:[this.handleOut.x,this.handleOut.y]};return reverse.apply(this,args);};
vm.runInNewContext(fs.readFileSync(__dirname+'/upstream/Segment.js','utf8'),{
 Segment:paper.Segment,Point:paper.Point,Size:paper.Size,Path:paper.Path,QUnit:{module(){}},
 test(name,fn){block++;title=name;beforeReverse=null;paper.project.clear();blocks.push({block,title});fn();},
 equals(actual,expected,message){if(typeof actual==='function')actual=actual();fixtures.push({id:fixtures.length,block,title,expected,actual,beforeReverse,message:message??null});}
});
fs.writeFileSync(__dirname+'/segments.json',JSON.stringify({blocks,fixtures},null,2)+'\n');
console.log(`${fixtures.length} assertions from ${blocks.length} blocks preserved`);
