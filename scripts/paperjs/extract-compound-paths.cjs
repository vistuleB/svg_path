const fs=require('node:fs'),vm=require('node:vm'),paper=require(process.argv[2]);
if(paper.version!=='0.12.18')throw Error('Requires paper 0.12.18');paper.setup(new paper.Size(1000,1000));
let block=-1,title,commands=[],rectangles=[],reorientation=null;const fixtures=[],blocks=[];
for(const name of ['moveTo','lineTo']){const original=paper.CompoundPath.prototype[name];paper.CompoundPath.prototype[name]=function(p){commands.push({method:name,point:[p.x,p.y]});return original.call(this,p);};}
const rectangle=paper.Path.Rectangle;paper.Path.Rectangle=function(...args){rectangles.push(JSON.parse(JSON.stringify(args)));return Reflect.construct(rectangle,args);};
const geometry=p=>p.children.map(c=>({closed:c.closed,curves:c.curves.map(x=>x.values.slice())}));
const reorient=paper.CompoundPath.prototype.reorient;paper.CompoundPath.prototype.reorient=function(...args){const before=geometry(this);const result=reorient.apply(this,args);reorientation={before,after:geometry(this)};return result;};
vm.runInNewContext(fs.readFileSync(__dirname+'/upstream/CompoundPath.js','utf8'),{CompoundPath:paper.CompoundPath,Path:paper.Path,Point:paper.Point,QUnit:{module(){}},test(name,fn){block++;title=name;commands=[];rectangles=[];reorientation=null;paper.project.clear();blocks.push({block,title});fn();},equals(actual,expected){if(typeof actual==='function')actual=actual();fixtures.push({id:fixtures.length,block,title,commands:structuredClone(commands),rectangles:structuredClone(rectangles),reorientation,actual,expected});}});
fs.writeFileSync(__dirname+'/compound-paths.json',JSON.stringify({blocks,fixtures},null,2)+'\n');
