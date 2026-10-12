const fs=require('node:fs'),vm=require('node:vm'),paper=require(process.argv[2]);
if(paper.version!=='0.12.18')throw Error('Requires paper 0.12.18');
paper.setup(new paper.Size(1000,1000));let path,block=-1,title;const fixtures=[],blocks=[];
const add=paper.Path.prototype.add;paper.Path.prototype.add=function(...args){const result=add.apply(this,args);path=this;return result;};
vm.runInNewContext(fs.readFileSync(__dirname+'/upstream/CurveLocation.js','utf8'),{Path:paper.Path,Point:paper.Point,QUnit:{module(){}},test(name,fn){block++;title=name;blocks.push({block,title});fn();},equals(actual,expected){fixtures.push({id:fixtures.length,block,title,nodeIndex:fixtures.length,points:path.segments.map(s=>[s.point.x,s.point.y]),curves:path.curves.map(c=>c.values.slice()),actual,expected});}});
fs.writeFileSync(__dirname+'/curve-locations.json',JSON.stringify({blocks,fixtures},null,2)+'\n');console.log(`${fixtures.length} offsets preserved`);
