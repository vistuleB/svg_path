import fs from 'node:fs';
import {path} from './triage-geometry.mjs';
import * as ix from '../../test_portable/build/dev/javascript/svg_path/svg_path/intersections.mjs';
const c=JSON.parse(fs.readFileSync(new URL('./captured-cases.json',import.meta.url))).find(c=>c.id==='CC01192');
const area=await import('../../test_portable/build/dev/javascript/svg_path/svg_path/area.mjs');
console.error('source area',area.signed_subpath([...path(c.input).subpaths][0]));
const result=ix.path_self(path(c.input));
console.log(JSON.stringify(result.isOk()?{hits:[...result[0]]}:{error:result[0]},null,2));
