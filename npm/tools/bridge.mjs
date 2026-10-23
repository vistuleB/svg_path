import { fieldName as field } from './api-shape.mjs';
// Representation conversion only. All geometry is implemented by compiled Gleam.
export function createBridge(schema, modules, prelude, option, order) {
    const opaqueValues = new WeakMap();
    const opaqueHandles = new WeakMap();
    const bad = message => { throw new TypeError(message); };
    const object = value => value !== null && typeof value === 'object';
    const array = value => Array.isArray(value) ? value : bad('Expected an array');
    function convert(t, value, inward, vars = []) {
        if (t.kind === 'variable')
            return vars[t.id] ? convert(vars[t.id], value, inward) : value;
        if (t.kind === 'tuple') {
            const xs = array(value);
            if (xs.length !== t.elements.length)
                bad('Incorrect tuple length');
            return t.elements.map((e, i) => convert(e, xs[i], inward, vars));
        }
        if (t.kind === 'fn') {
            if (typeof value !== 'function')
                bad('Expected a synchronous function');
            return (...args) => {
                if (args.length !== t.parameters.length)
                    bad(`Callback expects ${t.parameters.length} arguments`);
                const result = value(...args.map((x, i) => convert(t.parameters[i], x, !inward, vars)));
                if (result && typeof result.then === 'function')
                    bad('Geometry callbacks must be synchronous');
                return convert(t.return, result, inward, vars);
            };
        }
        const params = t.parameters.map(p => substitute(p, vars));
        if (t.module === 'gleam') {
            switch (t.name) {
                case 'List': return inward
                    ? prelude.toList(array(value).map(x => convert(params[0], x, true)))
                    : Array.from(value, x => convert(params[0], x, false));
                case 'Result':
                    if (inward) {
                        if (!object(value) || typeof value.ok !== 'boolean')
                            bad('Expected a Result object with an ok boolean');
                        if (!Object.hasOwn(value, value.ok ? 'value' : 'error'))
                            bad('Result payload is missing');
                        return value.ok ? new prelude.Ok(convert(params[0], value.value, true))
                            : new prelude.Error(convert(params[1], value.error, true));
                    }
                    return value instanceof prelude.Ok
                        ? { ok: true, value: convert(params[0], value[0], false) }
                        : { ok: false, error: convert(params[1], value[0], false) };
                case 'Float':
                case 'Int':
                    if (inward && (typeof value !== 'number' || (t.name === 'Int' && !Number.isSafeInteger(value))))
                        bad(`Expected ${t.name === 'Int' ? 'a safe integer' : 'a number'}`);
                    return value;
                case 'String':
                    if (inward && typeof value !== 'string')
                        bad('Expected a string');
                    return value;
                case 'Bool':
                    if (inward && typeof value !== 'boolean')
                        bad('Expected a boolean');
                    return value;
                case 'Nil':
                    if (inward && value !== undefined)
                        bad('Expected undefined');
                    return undefined;
                default: return bad(`Unsupported Gleam type ${t.name}`);
            }
        }
        if (t.module === 'gleam/option') {
            return inward ? value === null ? option.Option$None$const : new option.Some(convert(params[0], value, true))
                : value instanceof option.Some ? convert(params[0], value[0], false) : null;
        }
        if (t.module === 'gleam/order') {
            if (inward) {
                if (![-1, 0, 1].includes(value))
                    bad('Expected order -1, 0, or 1');
                return value === -1 ? order.Order$Lt$const : value === 0 ? order.Order$Eq$const : order.Order$Gt$const;
            }
            return value instanceof order.Lt ? -1 : value instanceof order.Eq ? 0 : 1;
        }
        const m = schema.modules[t.module];
        const alias = m['type-aliases'][t.name];
        if (alias)
            return convert(alias.alias, value, inward, params);
        const type = m.types[t.name];
        const key = `${t.module}.${t.name}`;
        if (!type.constructors.length) {
            if (inward) {
                const entry = object(value) && opaqueValues.get(value);
                if (!entry || entry.key !== key)
                    bad(`Expected an opaque ${key} created by this package`);
                return entry.value;
            }
            let handle = opaqueHandles.get(value);
            if (!handle) {
                handle = Object.freeze(Object.create(null));
                opaqueValues.set(handle, { key, value });
                opaqueHandles.set(value, handle);
            }
            return handle;
        }
        const tagged = type.constructors.length > 1;
        if (inward && !object(value))
            bad(`Expected ${key} object`);
        const ctor = inward
            ? tagged ? type.constructors.find(c => c.name === value.kind) : type.constructors[0]
            : type.constructors.find(c => modules[t.module][`${t.name}$is${c.name}`](value));
        if (!ctor)
            bad(`Invalid variant of ${key}`);
        if (inward) {
            return modules[t.module][`${t.name}$${ctor.name}`](...ctor.parameters.map((p, i) => {
                const name = field(p, i);
                if (!Object.hasOwn(value, name))
                    bad(`Missing ${key}.${name}`);
                return convert(p.type, value[name], true, params);
            }));
        }
        const result = tagged ? { kind: ctor.name } : {};
        ctor.parameters.forEach((p, i) => { result[field(p, i)] = convert(p.type, value[p.label ?? i], false, params); });
        return result;
    }
    function substitute(t, vars) {
        if (t.kind === 'variable')
            return vars[t.id] ?? t;
        if (t.kind === 'named')
            return { ...t, parameters: t.parameters.map(p => substitute(p, vars)) };
        if (t.kind === 'tuple')
            return { ...t, elements: t.elements.map(p => substitute(p, vars)) };
        if (t.kind === 'fn')
            return { ...t, parameters: t.parameters.map(p => substitute(p, vars)), return: substitute(t.return, vars) };
        throw new TypeError(`Unsupported type kind ${t.kind}`);
    }
    return {
        call(module, name, args) {
            const f = schema.modules[module].functions[name];
            if (args.length !== f.parameters.length)
                bad(`${module}.${name} expects ${f.parameters.length} arguments`);
            const result = modules[module][name](...f.parameters.map((p, i) => convert(p.type, args[i], true)));
            return convert(f.return, result, false);
        },
        constant(module, name) { return convert(schema.modules[module].constants[name].type, modules[module][name], false); },
    };
}
export class SvgPathError extends Error {
    constructor(error) {
        super(`SVG path operation failed: ${error?.kind ?? error?.reason?.kind ?? (typeof error === 'string' ? error : 'see .detail')}`);
        this.name = 'SvgPathError';
        this.detail = error;
    }
}
export function unwrap(result) {
    if (result.ok)
        return result.value;
    throw new SvgPathError(result.error);
}
