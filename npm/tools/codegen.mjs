import path from 'node:path';
import { camelCase, moduleFile, parameterName } from './api-shape.mjs';
const rel = (from, to) => { const p = path.posix.relative(path.posix.dirname(from), to); return p.startsWith('.') ? p : './' + p; };
export const documentation = s => s ? `/**\n${(Array.isArray(s) ? s.join('\n') : s).trim().replaceAll('*/', '* /').split('\n').map(l => ' * ' + l).join('\n')}\n */\n` : '';
export function typeVariables(t, set = new Set()) {
    if (Array.isArray(t))
        t.forEach(v => typeVariables(v, set));
    else if (t && typeof t === 'object') {
        if (t.kind === 'variable')
            set.add(t.id);
        Object.values(t).forEach(v => typeVariables(v, set));
    }
    return set;
}
export function createTypePrinter(schema) {
    return function ts(t, m) {
        if (t.kind === 'variable')
            return `T${t.id}`;
        if (t.kind === 'tuple')
            return `readonly [${t.elements.map(e => ts(e, m)).join(', ')}]`;
        if (t.kind === 'fn')
            return `(${t.parameters.map((p, i) => `arg${i}: ${ts(p, m)}`).join(', ')}) => ${ts(t.return, m)}`;
        if (t.kind !== 'named')
            throw new Error(`Unsupported interface type kind: ${t.kind}`);
        const ps = t.parameters.map(p => ts(p, m));
        if (t.module === 'gleam') {
            if (['Float', 'Int'].includes(t.name))
                return 'number';
            if (t.name === 'String')
                return 'string';
            if (t.name === 'Bool')
                return 'boolean';
            if (t.name === 'Nil')
                return 'undefined';
            if (t.name === 'List')
                return `ReadonlyArray<${ps[0]}>`;
            if (t.name === 'Result')
                return `import('${rel(moduleFile(m), 'result.mjs')}').Result<${ps.join(', ')}>`;
            throw new Error('Unsupported built-in ' + t.name);
        }
        if (t.module === 'gleam/option')
            return `(${ps[0]} | null)`;
        if (t.module === 'gleam/order')
            return '(-1 | 0 | 1)';
        if (!schema.modules[t.module])
            throw new Error('Unsupported external type ' + t.module);
        const name = t.module === m ? t.name : `import('${rel(moduleFile(m), moduleFile(t.module) + '.mjs')}').${t.name}`;
        return name + (ps.length ? `<${ps.join(', ')}>` : '');
    };
}
export function parameterNames(source, name, count) {
    const start = source.search(new RegExp(`^pub fn ${name}\\(`, 'm'));
    if (start < 0)
        return Array.from({ length: count }, (_, i) => `arg${i}`);
    let i = source.indexOf('(', start) + 1, depth = 0, chunk = '', parts = [];
    for (; i < source.length; i++) {
        const c = source[i];
        if (c === ')' && depth === 0) {
            if (chunk.trim())
                parts.push(chunk);
            break;
        }
        if (c === ',' && depth === 0) {
            parts.push(chunk);
            chunk = '';
            continue;
        }
        if (c === '(')
            depth++;
        if (c === ')')
            depth--;
        chunk += c;
    }
    return parts.map((p, i) => { const match = p.trim().match(/^(\w+)(?:\s+(\w+))?\s*:/); const n = camelCase(match?.[2] ?? match?.[1] ?? `arg${i}`); return parameterName(n, i); });
}
// Remove metadata only from schema entries, never from symbol dictionaries.
export function runtimeSchemaOf(schema) {
    const runtime = structuredClone(schema);
    const strip = entry => {
        delete entry.documentation;
        delete entry.deprecation;
        delete entry.implementations;
    };
    for (const module of Object.values(runtime.modules)) {
        strip(module);
        for (const collection of ['types', 'type-aliases', 'functions', 'constants']) {
            for (const entry of Object.values(module[collection])) {
                strip(entry);
                for (const constructor of entry.constructors ?? [])
                    strip(constructor);
            }
        }
    }
    return runtime;
}
