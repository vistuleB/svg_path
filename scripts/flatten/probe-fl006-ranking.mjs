import fs from 'node:fs';
import * as g from '/tmp/fl006-runtime/svg_path/svg_path.mjs';
import * as ix from '/tmp/fl006-runtime/svg_path/svg_path/intersections.mjs';
const pair=JSON.parse(fs.readFileSync(new URL('remaining-continuity-4295-pair.json',import.meta.url)));
const arc=s=>new g.Arc(new g.Point(s.start.x,s.start.y),new g.Point(s.radius.x,s.radius.y),s.x_axis_rotation,s.large_arc,s.sweep,new g.Point(s.end.x,s.end.y));
const a=arc(pair.curved),b=arc(pair.cutter);
console.log('REPORT',JSON.stringify(ix.elizabeth_beam_intersections(a,b,ix.default_options())));
