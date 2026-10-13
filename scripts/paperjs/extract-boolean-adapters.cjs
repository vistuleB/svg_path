// Preserve operation provenance on selected result children, including children
// subsequently joined by #757. Expected data still comes from upstream assertions.
const fs = require('node:fs');
const vm = require('node:vm');
const ids = [26, 44, 71, 73, 75, 77, 78];
let source = fs.readFileSync(__dirname + '/extract-booleans.cjs', 'utf8');
const anchor = 'provenance.set(result, trace);';
if (source.split(anchor).length !== 2) throw Error('Extraction anchor changed');
source = source.replace(anchor, anchor + '\n    for (const [selectedChild, child] of (result.children || []).entries()) provenance.set(child, {...trace, selectedChild});');
const proxy = {...fs, writeFileSync(path, data) {
  if (!path.endsWith('/booleans.json')) throw Error('Unexpected output');
  const extracted = JSON.parse(data);
  const fixtures = extracted.fixtures.filter(f => ids.includes(f.id));
  if (fixtures.length !== 7 || fixtures.some(f => !f.op || !f.left || !f.right)) throw Error('Missing provenance');
  fs.writeFileSync(__dirname + '/boolean-adapter-fixtures.json', JSON.stringify({runtime: extracted.runtime, fixtures}, null, 2) + '\n');
}};
vm.runInNewContext(source, {require: name => name === 'node:fs' ? proxy : require(name), process, __dirname, console: {log() {}}});
