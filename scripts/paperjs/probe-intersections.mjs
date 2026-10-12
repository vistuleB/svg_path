import fs from 'node:fs';
import * as s from '../../test_portable/build/dev/javascript/svg_path/svg_path.mjs';
import * as ix from '../../test_portable/build/dev/javascript/svg_path/svg_path/intersections.mjs';
import {toList, Ok} from '../../test_portable/build/dev/javascript/svg_path/gleam.mjs';
const fixtures = JSON.parse(fs.readFileSync(new URL('./intersections.json', import.meta.url)));
function path(g) {
 let sub = s.subpath_assert(toList(g.curves.map(c => new s.CubicBezier(...[0,2,4,6].map(i => new s.Point(c[i],c[i+1]))))));
 if (g.closed) sub = s.subpath_assert_close(sub);
 return s.subpath_as_path(sub);
}
for (const [i,f] of fixtures.entries()) {
 if (f.method === 'getCrossings') continue;
 const r = f.right ? ix.path(path(f.left),path(f.right)) : ix.path_self(path(f.left));
 console.log(JSON.stringify({i,title:f.title,expected:f.expected,actual:r instanceof Ok ? [...r[0]] : {error: r[0].constructor.name}}));
}
