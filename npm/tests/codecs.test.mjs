import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createBridge} from '../tools/bridge.mjs';
import * as prelude from '../generated/lib/vendor/svg_path/gleam.mjs';
import * as option from '../generated/lib/vendor/gleam_stdlib/gleam/option.mjs';
import * as order from '../generated/lib/vendor/gleam_stdlib/gleam/order.mjs';
const schema=JSON.parse(await readFile(new URL('../generated/interface.json',import.meta.url),'utf8'));
const modules={};
for(const m of Object.keys(schema.modules))modules[m]=await import(`../generated/lib/vendor/svg_path/${m}.mjs`);
const named=(module,name,parameters=[])=>({kind:'named',module,name,parameters});
const string=named('gleam','String');
const fake={functions:{},types:{},constants:{},'type-aliases':{}};
schema.modules.__test=fake;modules.__test={};
const bridge=createBridge(schema,modules,prelude,option,order);
function addFunction(name,t,fn,hasArg=true) {
 fake.functions[name]={parameters:hasArg?[{type:t}]:[],return:t};modules.__test[name]=fn;
}
addFunction('subpath',named('svg_path','Subpath'),()=>modules.svg_path.subpath_empty(new modules.svg_path.Point(0,0)),false);
addFunction('matrix',named('svg_path/transform','Matrix'),()=>modules['svg_path/transform'].identity(),false);
const opaque={Subpath:bridge.call('__test','subpath',[]),Matrix:bridge.call('__test','matrix',[])};
const camel=s=>s.replace(/_([a-z0-9])/g,(_,c)=>c.toUpperCase());
function sample(t,depth=0,vars=[],ctorOverride=null) {
 if(t.kind==='variable')return vars[t.id]??'user payload';
 if(t.kind==='tuple')return t.elements.map(t=>sample(t,depth+1,vars));
 if(t.kind==='fn')return ()=>sample(t.return,depth+1,vars);
 if(t.module==='gleam') {
  if(t.name==='List')return depth>3?[]:[sample(t.parameters[0],depth+1,vars)];
  if(t.name==='Result')return {ok:true,value:sample(t.parameters[0],depth+1,vars)};
  return {Float:1.25,Int:2,String:'test',Bool:true,Nil:undefined}[t.name];
 }
 if(t.module==='gleam/option')return depth>3?null:sample(t.parameters[0],depth+1,vars);
 if(t.module==='gleam/order')return -1;
 const m=schema.modules[t.module],a=m['type-aliases'][t.name];if(a)return sample(a.alias,depth+1,vars);
 const ty=m.types[t.name];if(!ty.constructors.length)return opaque[t.name];
 const c=ctorOverride??[...ty.constructors].sort((a,b)=>a.parameters.length-b.parameters.length)[0];
 const params=t.parameters.map(p=>sample(p,depth+1,vars));
 return Object.fromEntries([...(ty.constructors.length>1?[['kind',c.name]]:[]),...c.parameters.map((p,i)=>[p.label===null?`value${i}`:camel(p.label),sample(p.type,depth+1,params)])]);
}
function comparable(x) {
 if(typeof x==='function')return '<callback>';
 if(Array.isArray(x))return x.map(comparable);
 if(x&&typeof x==='object')return Object.fromEntries(Object.entries(x).map(([k,v])=>[k,comparable(v)]));
 return x;
}
let count=0;
for(const [m,data]of Object.entries(schema.modules))for(const [name,ty]of Object.entries(data.types)) {
 const type=named(m,name,Array.from({length:ty.parameters},()=>string));
 for(const ctor of ty.constructors) {
  const id=`identity${count++}`;addFunction(id,type,x=>x);
  test(`${m}.${name}.${ctor.name} survives native→Gleam→native`,()=> {
   const value=sample(type,0,[],ctor);const actual=bridge.call('__test',id,[value]);
   assert.deepEqual(comparable(actual),comparable(value));
  });
 }
}
test('returned functions convert both arguments and results',()=> {
 const point=named('svg_path','Point');const type={kind:'fn',parameters:[point],return:point};
 addFunction('callback',type,()=>p=>new modules.svg_path.Point(p.x+1,p.y+2),false);
 const callback=bridge.call('__test','callback',[]);assert.deepEqual(callback({x:3,y:4}),{x:4,y:6});
});
test('tuple, Option and order distinguish valid representations',()=> {
 for(const [i,t,v]of [[0,named('gleam/option','Option',[string]),null],[1,named('gleam/option','Option',[string]),'some'],[2,named('gleam/order','Order'),0],[3,named('gleam/order','Order'),1]]) {
  addFunction('special'+i,t,x=>x);assert.deepEqual(bridge.call('__test','special'+i,[v]),v);
 }
});
test('every public function in the interface has a compiled implementation',()=> {
 let count=0;
 for(const [m,data]of Object.entries(schema.modules)) {
  if(m==='__test')continue;
  for(const name of Object.keys(data.functions)) {assert.equal(typeof modules[m][name],'function',`${m}.${name}`);count++;}
 }
 assert.equal(count,600);
});
