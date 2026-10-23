import { execFileSync } from 'node:child_process';
import { readFile, writeFile, mkdir, mkdtemp, rm } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import assert from 'node:assert/strict';
import { build } from 'esbuild';
import { chromium } from 'playwright';
const root = fileURLToPath(new URL('../../', import.meta.url));
const npmRoot = path.join(root, 'npm');
process.env.PATH = path.dirname(process.execPath) + path.delimiter + process.env.PATH;
const run = (cmd, args, cwd = root) => execFileSync(cmd, args, { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'inherit'] });
await mkdir(path.join(npmRoot, 'test-output'), { recursive: true });
await rm(path.join(npmRoot, 'test-output/report.json'), { force: true });
run(process.execPath, [path.join(npmRoot, 'tools/build.mjs')]);
console.log(run(process.execPath, ['--test', path.join(npmRoot, 'tests/codecs.test.mjs'), path.join(npmRoot, 'tests/codegen.test.mjs')]));
const output = path.join(npmRoot, 'generated');
const pkg = JSON.parse(await readFile(path.join(output, 'package.json'), 'utf8'));
await mkdir(path.join(npmRoot, 'artifacts'), { recursive: true });
const pack = JSON.parse(run('npm', ['pack', '--json', '--ignore-scripts', '--cache', path.join(npmRoot, 'test-output/cache'), '--pack-destination', path.join(npmRoot, 'artifacts')], output))[0];
assert.equal(pkg.private, true);
assert.equal(pkg.dependencies, undefined);
for (const f of pack.files) {
    assert.ok(!/node_modules|\/test\/|\/tools\//.test(f.path), `Unexpected shipped tooling ${f.path}`);
    assert.ok(!f.path.endsWith('.gleam'), `Unexpected source ${f.path}`);
}
const consumer = await mkdtemp(path.join(npmRoot, 'test-output/consumer-'));
await writeFile(path.join(consumer, 'package.json'), JSON.stringify({ name: 'svg-path-package-consumer-test', version: '0.0.0', type: 'module', private: true }));
run('npm', ['install', '--offline', '--ignore-scripts', '--no-audit', '--no-fund', '--cache', path.join(npmRoot, 'test-output/cache'), path.join(npmRoot, 'artifacts', pack.filename)], consumer);
assert.deepEqual(JSON.parse(await readFile(path.join(consumer, 'node_modules', pkg.name, 'source.json'), 'utf8')), JSON.parse(await readFile(path.join(output, 'source.json'), 'utf8')));
for (const f of ['consumer.test.mjs', 'consumer.mts', 'browser.mjs']) {
    const content = (await readFile(path.join(npmRoot, 'tests', f), 'utf8')).replaceAll('svg-path-geometry-preview', pkg.name);
    await writeFile(path.join(consumer, f), content);
}
// Exercise the README shipped in the archive, rather than a copied recipe.
const installedRoot = path.join(consumer, 'node_modules', pkg.name);
const readme = await readFile(path.join(installedRoot, 'README.md'), 'utf8');
const recipes = [...readme.matchAll(/^```js\r?\n([\s\S]*?)^```/gm)].map(match => match[1]);
assert.ok(recipes.length > 0, 'The package README must contain executable examples');
const recipeTypes = [];
for (const [index, code] of recipes.entries()) {
    const file = `readme-${index + 1}`;
    await writeFile(path.join(consumer, `${file}.mjs`), code);
    await writeFile(path.join(consumer, `${file}.mts`), code);
    run(process.execPath, [`${file}.mjs`], consumer);
    recipeTypes.push(`${file}.mts`);
}
console.log(`Executed ${recipes.length} examples extracted from the installed README.`);
for (const file of ['LICENSE', 'THIRD-PARTY-NOTICES.txt', 'THIRD-PARTY-LICENSES/gleam_stdlib.txt', 'API.md']) {
    assert.ok((await readFile(path.join(installedRoot, file), 'utf8')).trim(), `Missing or empty ${file}`);
}
console.log(run(process.execPath, ['--test', 'consumer.test.mjs'], consumer));
console.log(run(process.execPath, [path.join(npmRoot, 'tools/node_modules/typescript/bin/tsc'), '--noEmit', '--strict', '--module', 'NodeNext', '--target', 'ES2022', 'consumer.mts', ...recipeTypes], consumer));
// Import every advertised module from the installed tarball, not the build tree.
await writeFile(path.join(consumer, 'exports.mjs'), `import assert from 'node:assert/strict';\n` + Object.keys(pkg.exports).filter(k => k !== './source').map(k => `assert.ok(await import(${JSON.stringify(pkg.name + (k === '.' ? '' : k.slice(1)))}));`).join('\n'));
run(process.execPath, ['exports.mjs'], consumer);
const bundle = path.join(consumer, 'browser-bundle.js');
await build({ entryPoints: [path.join(consumer, 'browser.mjs')], bundle: true, platform: 'browser', format: 'iife', target: ['es2022'], outfile: bundle, metafile: true }).then(async (r) => {
    assert.ok(Object.values(r.metafile.outputs).every(o => o.imports.length === 0), 'Browser bundle has external imports');
    await writeFile(path.join(npmRoot, 'test-output/browser-metafile.json'), JSON.stringify(r.metafile, null, 2));
});
const browser = await chromium.launch({ headless: true, ...(process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH ? { executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH } : {}) });
const browserVersion = browser.version();
try {
    const page = await browser.newPage();
    const errors = [];
    page.on('pageerror', e => errors.push(e.message));
    await page.setContent('<!doctype html><html><body></body></html>');
    await page.addScriptTag({ path: bundle });
    assert.equal(await page.evaluate(() => globalThis.__geometryTestPassed), true);
    assert.deepEqual(errors, []);
    console.log('Browser bundled geometry and SVG DOM checks passed (Chromium).');
}
finally {
    await browser.close();
}
console.log(`Verified installed tarball: ${pack.filename}; ${pack.size} bytes packed, ${pack.unpackedSize} bytes unpacked; ${Object.keys(pkg.exports).length} export entries.`);
await writeFile(path.join(npmRoot, 'test-output/report.json'), JSON.stringify({ package: pkg.name, version: pkg.version, tarball: pack.filename, size: pack.size, unpackedSize: pack.unpackedSize, integrity: pack.integrity, node: process.version, browser: browserVersion, consumer, checks: ['429 generator, representation and API implementation checks', '17 Node installed-package tests', `${recipes.length} installed README examples executed and type-checked`, 'TypeScript strict consumer and all declarations', 'all module exports', 'browser bundle without externals', 'Chromium geometry and DOM'], source: JSON.parse(await readFile(path.join(output, 'source.json'), 'utf8')) }, null, 2) + '\n');
