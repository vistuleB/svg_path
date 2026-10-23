import { execFileSync } from 'node:child_process';
import { mkdir, readFile, writeFile, readdir, copyFile, rm } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { camelCase as camel, fieldName as field, moduleFile, moduleNamespace as namespace, parameterName } from './api-shape.mjs';
import { documentation as doc, typeVariables as variables, parameterNames as paramNames, createTypePrinter, runtimeSchemaOf } from './codegen.mjs';
const root = fileURLToPath(new URL('../../', import.meta.url));
const here = path.join(root, 'npm');
process.env.PATH = path.dirname(process.execPath) + path.delimiter + process.env.PATH;
const output = path.join(here, 'generated');
const run = (command, args, cwd = root) => execFileSync(command, args, { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'inherit'] });
const compiler = run('gleam', ['--version']).trim();
const rootLock = await readFile(path.join(root, 'manifest.toml'), 'utf8');
const stdlibVersion = rootLock.match(/name = "gleam_stdlib", version = "([^"]+)"/)[1];
if (compiler !== 'gleam 1.18.1')
    throw new Error(`This adapter is verified with Gleam 1.18.1; found ${compiler}`);
const manifest = JSON.parse(await readFile(path.join(here, 'package/package.json'), 'utf8'));
if (manifest.name !== 'svg-path-geometry' || manifest.private === true)
    throw new Error('Expected the public svg-path-geometry distribution manifest');
if (manifest.publishConfig?.registry !== 'https://registry.npmjs.org/' || manifest.publishConfig?.access !== 'public')
    throw new Error('Distribution must target the public npm registry');
await mkdir(output, { recursive: true });
run('gleam', ['export', 'package-interface', '--out', path.join(output, 'interface.json')]);
const schema = JSON.parse(await readFile(path.join(output, 'interface.json'), 'utf8'));
const project = path.join(here, 'tools/gleam');
// Refresh only this build root's local dependency version. Dependencies stay locked.
const lock = path.join(project, 'manifest.toml');
try {
    const s = await readFile(lock, 'utf8');
    await writeFile(lock, s.replace(/(name = "svg_path", version = ")[^"]+/, `$1${schema.version}`));
}
catch (e) {
    if (e.code !== 'ENOENT')
        throw e;
}
run('gleam', ['build', '--target', 'javascript'], project);
const buildLock = await readFile(lock, 'utf8');
if (buildLock.match(/name = "gleam_stdlib", version = "([^"]+)"/)[1] !== stdlibVersion)
    throw new Error('npm build must use the same gleam_stdlib version as the root lock');
await rm(path.join(output, 'lib'), { recursive: true, force: true });
await mkdir(path.join(output, 'lib/vendor'), { recursive: true });
async function copyModules(from, to) {
    await mkdir(to, { recursive: true });
    for (const entry of await readdir(from, { withFileTypes: true })) {
        if (entry.isDirectory())
            await copyModules(path.join(from, entry.name), path.join(to, entry.name));
        else if (entry.name.endsWith('.mjs'))
            await copyFile(path.join(from, entry.name), path.join(to, entry.name));
    }
}
for (const pkg of ['svg_path', 'gleam_stdlib']) {
    await copyModules(path.join(project, 'build/dev/javascript', pkg), path.join(output, 'lib/vendor', pkg));
}
await copyFile(path.join(project, 'build/dev/javascript/prelude.mjs'), path.join(output, 'lib/vendor/prelude.mjs'));
const modules = Object.keys(schema.modules).sort();
const rel = (from, to) => { const p = path.posix.relative(path.posix.dirname(from), to); return p.startsWith('.') ? p : './' + p; };
const generic = count => count ? `<${Array.from({ length: count }, (_, i) => `T${i}`).join(", ")}>` : "";
const ts = createTypePrinter(schema);
const imports = modules.map((m, i) => `import * as m${i} from './vendor/svg_path/${m}.mjs';`).join('\n');
const runtimeSchema = runtimeSchemaOf(schema);
await writeFile(path.join(output, 'lib/registry.mjs'), `${imports}\nimport * as prelude from './vendor/svg_path/gleam.mjs';\nimport * as option from './vendor/gleam_stdlib/gleam/option.mjs';\nimport * as order from './vendor/gleam_stdlib/gleam/order.mjs';\nimport {createBridge} from './bridge.mjs';\nconst schema = ${JSON.stringify(runtimeSchema)};\nexport const bridge = createBridge(schema, {${modules.map((m, i) => `${JSON.stringify(m)}:m${i}`).join(',')}}, prelude, option, order);\n`);
for (const name of ['bridge.mjs', 'api-shape.mjs'])
    await copyFile(path.join(here, 'tools', name), path.join(output, 'lib', name));
await writeFile(path.join(output, 'lib/result.mjs'), `export {unwrap, SvgPathError} from './bridge.mjs';\n`);
await writeFile(path.join(output, 'lib/result.d.mts'), `export type Result<T, E> = { readonly ok: true; readonly value: T } | { readonly ok: false; readonly error: E };\nexport declare class SvgPathError extends Error { readonly detail: unknown; constructor(error: unknown); }\nexport declare function unwrap<T, E>(result: Result<T, E>): T;\n`);
const exports = { '.': { types: './lib/index.d.mts', import: './lib/index.mjs' }, './result': { types: './lib/result.d.mts', import: './lib/result.mjs' }, './source': './source.json' };
let api = '# JavaScript API mapping\n\nGenerated from the Gleam package interface. Functions keep Gleam argument order; names and record fields use camelCase.\n\n';
for (const m of modules) {
    const data = schema.modules[m], file = moduleFile(m);
    const source = await readFile(path.join(root, 'src', m + '.gleam'), 'utf8');
    await mkdir(path.dirname(path.join(output, 'lib', file)), { recursive: true });
    let js = `// Generated from ${m}. Do not edit.\nimport {bridge} from '${rel(file, 'registry.mjs')}';\n`;
    let dts = doc(data.documentation), names = new Set();
    const addName = n => { if (names.has(n))
        throw new Error(`Export collision ${m}.${n}`); names.add(n); };
    api += `## ${file}\n\n${data.documentation.join('\n').trim()}\n\n`;
    for (const [n, t] of Object.entries(data.types)) {
        if (!t.constructors.length) {
            dts += doc(t.documentation) + `declare const ${n}Brand: unique symbol;\nexport type ${n} = { readonly [${n}Brand]: true };\n`;
            continue;
        }
        const tagged = t.constructors.length > 1;
        const objectType = c => '{ ' + [...(tagged ? [`readonly kind: ${JSON.stringify(c.name)}`] : []), ...c.parameters.map((p, i) => `readonly ${field(p, i)}: ${ts(p.type, m)}`)].join('; ') + ' }';
        dts += doc(t.documentation) + `export type ${n}${generic(t.parameters)} = ${t.constructors.map(objectType).join(' | ')};\n`;
        for (const c of t.constructors) {
            addName(c.name);
            js += `export function ${c.name}(${c.parameters.map((_, i) => `arg${i}`).join(', ')}) { return {${[...(tagged ? [`kind:${JSON.stringify(c.name)}`] : []), ...c.parameters.map((p, i) => `${field(p, i)}:arg${i}`)].join(',')}}; }\n`;
            const used = [...variables(c.parameters)].sort((a, b) => a - b);
            const g = used.length ? `<${used.map(i => 'T' + i).join(', ')}>` : '';
            dts += doc(c.documentation) + `export declare function ${c.name}${g}(${c.parameters.map((p, i) => `${parameterName(field(p, i), i)}: ${ts(p.type, m)}`).join(', ')}): ${objectType(c)};\n`;
        }
    }
    for (const [n, t] of Object.entries(data['type-aliases']))
        dts += doc(t.documentation) + `export type ${n} = ${ts(t.alias, m)};\n`;
    for (const [n, c] of Object.entries(data.constants)) {
        const name = camel(n);
        addName(name);
        js += `export const ${name} = bridge.constant(${JSON.stringify(m)},${JSON.stringify(n)});\n`;
        dts += doc(c.documentation) + `export declare const ${name}: ${ts(c.type, m)};\n`;
    }
    for (const [n, f] of Object.entries(data.functions)) {
        if (!f.implementations['can-run-on-javascript'])
            throw new Error(`Public function unavailable on JS: ${m}.${n}`);
        const name = camel(n);
        addName(name);
        const params = paramNames(source, n, f.parameters.length);
        if (params.length !== f.parameters.length)
            throw new Error('Parameter extraction failed: ' + m + '.' + n);
        js += `export function ${name}(...args) { return bridge.call(${JSON.stringify(m)},${JSON.stringify(n)},args); }\n`;
        const ids = [...variables(f)].sort((a, b) => a - b), g = ids.length ? `<${ids.map(i => 'T' + i).join(', ')}>` : '';
        const signature = `${name}${g}(${f.parameters.map((p, i) => `${params[i]}: ${ts(p.type, m)}`).join(', ')}): ${ts(f.return, m)}`;
        dts += doc(f.documentation) + `export declare function ${signature};\n`;
        api += `### ${name}\n\n\`\`\`typescript\n${signature}\n\`\`\`\n\n${(f.documentation ?? '').trim()}\n\n`;
    }
    await writeFile(path.join(output, 'lib', file + '.mjs'), js);
    await writeFile(path.join(output, 'lib', file + '.d.mts'), dts);
    exports['./' + file] = { types: `./lib/${file}.d.mts`, import: `./lib/${file}.mjs` };
}
const index = `export * from './core.mjs';\nexport {unwrap, SvgPathError} from './result.mjs';\n` + modules.filter(m => m !== 'svg_path').map(m => `export * as ${namespace(m)} from './${moduleFile(m)}.mjs';`).join('\n') + '\n';
await writeFile(path.join(output, 'lib/index.mjs'), index);
await writeFile(path.join(output, 'lib/index.d.mts'), index + `export type {Result} from './result.mjs';\n`);
await writeFile(path.join(output, 'package.json'), JSON.stringify({ ...manifest, exports }, null, 2) + '\n');
await writeFile(path.join(output, 'API.md'), api);
await copyFile(path.join(here, 'package/README.md'), path.join(output, 'README.md'));
await copyFile(path.join(root, 'LICENSE'), path.join(output, 'LICENSE'));
await copyFile(path.join(here, 'package/THIRD-PARTY-NOTICES.txt'), path.join(output, 'THIRD-PARTY-NOTICES.txt'));
await mkdir(path.join(output, 'THIRD-PARTY-LICENSES'), { recursive: true });
await copyFile(path.join(project, 'build/packages/gleam_stdlib/LICENCE'), path.join(output, 'THIRD-PARTY-LICENSES/gleam_stdlib.txt'));
const hash = createHash('sha256');
async function hashTree(dir) { for (const e of (await readdir(dir, { withFileTypes: true })).sort((a, b) => a.name.localeCompare(b.name))) {
    const p = path.join(dir, e.name);
    if (e.isDirectory())
        await hashTree(p);
    else {
        hash.update(path.relative(root, p));
        hash.update(await readFile(p));
    }
} }
await hashTree(path.join(root, 'src'));
hash.update(await readFile(path.join(root, 'gleam.toml')));
hash.update(await readFile(path.join(project, 'manifest.toml')));
const adapterHash = createHash('sha256');
for (const file of ['tools/build.mjs', 'tools/codegen.mjs', 'tools/api-shape.mjs', 'tools/bridge.mjs', 'package/package.json', 'package/README.md', 'package/THIRD-PARTY-NOTICES.txt']) {
    adapterHash.update(file);
    adapterHash.update(await readFile(path.join(here, file)));
}
await writeFile(path.join(output, 'source.json'), JSON.stringify({ adapterSha256: adapterHash.digest('hex'), stdlibVersion, gleamVersion: schema.version, gleamCommit: run('git', ['rev-parse', 'HEAD']).trim(), sourceDirty: !!run('git', ['status', '--porcelain', '--', 'src', 'gleam.toml']).trim(), sourceSha256: hash.digest('hex'), compiler, npmVersion: manifest.version, modules: modules.length, functions: modules.reduce((n, m) => n + Object.keys(schema.modules[m].functions).length, 0) }, null, 2) + '\n');
console.log(`Built ${manifest.name}@${manifest.version}: ${modules.length} public modules in ${output}`);
