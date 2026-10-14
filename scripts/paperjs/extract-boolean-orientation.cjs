// Capture the previously unextracted #973 orientation assertion and operand.
const fs=require('node:fs'),vm=require('node:vm'),paper=require(process.argv[2]);
if(paper.version!=='0.12.18')throw Error('Requires paper 0.12.18');
paper.setup([1000,1000]);let input,expected,actual,resolved;
const original=paper.PathItem.prototype.resolveCrossings;
paper.PathItem.prototype.resolveCrossings=function(){
 input={closed:this.closed,curves:this.curves.map(c=>c.values)};
 resolved=original.apply(this,arguments);return resolved;
};
vm.runInNewContext(fs.readFileSync(__dirname+'/upstream/Path_Boolean.js','utf8'),{...paper,
 Path:paper.Path, QUnit:{module(){}},test(title,fn){if(title==='#973')fn();},
 equals(observed,want){actual=observed;expected=want;},compareBoolean(){throw Error('Unexpected geometry assertion');}});
if(!input||!expected)throw Error('Missing assertion');
const paths=resolved.children||[resolved];
const samples=[];
for(let x=95;x<=255;x+=5)for(let y=125;y<=185;y+=2.5){
 const p=new paper.Point(x,y);if(resolved.getNearestPoint(p).getDistance(p)>0.001)samples.push([x,y,resolved.contains(p)]);
}
fs.writeFileSync(__dirname+'/boolean-orientation.json',JSON.stringify({runtime:paper.version,title:'#973',input,expectedClockwise:expected,runtimeClockwise:actual,
 referenceSubpaths:paths.map(p=>({closed:p.closed,curves:p.curves.map(c=>c.values),signedArea:p.area})),
 referenceFilledArea:paths.reduce((a,p)=>a+Math.abs(p.area),0),samples,derivedSamples:true},null,2)+'\n');
