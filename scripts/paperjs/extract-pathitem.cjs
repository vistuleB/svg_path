const fs=require('node:fs'),vm=require('node:vm'),paper=require(process.argv[2]);
if(paper.version!=='0.12.18')throw Error('Requires paper 0.12.18');
paper.setup(new paper.Size(1000,1000));let block=-1,title,last;const inputs=new WeakMap(),fixtures=[],blocks=[];
const create=paper.PathItem.create;paper.PathItem.create=function(arg){const item=create.call(this,arg);inputs.set(item,arg);return item;};
function geometry(p){if(!p)return null;return (p.children??[p]).map(sp=>({closed:sp.closed,curves:sp.curves.map(c=>c.values.slice())}));}
const compare=paper.PathItem.prototype.compare;paper.PathItem.prototype.compare=function(other){last={left:geometry(this),right:geometry(other)};return compare.call(this,other);};
vm.runInNewContext(fs.readFileSync(__dirname+'/upstream/PathItem.js','utf8'),{PathItem:paper.PathItem,Path:paper.Path,QUnit:{module(){}},test(name,fn){block++;title=name;blocks.push({block,title});fn();},equals(actual,expected,message){if(typeof actual==='function'){actual=actual();fixtures.push({id:fixtures.length,block,title,kind:'compare',...last,expected,actual,message});}else fixtures.push({id:fixtures.length,block,title,kind:'parse',input:inputs.get(actual),expected:inputs.get(expected),message});}});
fs.writeFileSync(__dirname+'/pathitem.json',JSON.stringify({blocks,fixtures},null,2)+'\n');console.log(`${fixtures.length} assertions preserved from ${blocks.length} blocks`);
