// Shared naming rules for generated declarations, adapters, and runtime records.
// This module contains no geometry or compiler-specific runtime operations.
export const camelCase = name => name.replace(/_([a-z0-9])/g, (_, c) => c.toUpperCase());
export const fieldName = (parameter, index) => parameter.label === null
    ? `value${index}` : camelCase(parameter.label);
export const moduleFile = name => name === 'svg_path' ? 'core' : name.slice('svg_path/'.length);
export const moduleNamespace = name => camelCase(moduleFile(name).replaceAll('/', '_'));
const reservedParameters = new Set([
    'await', 'break', 'case', 'catch', 'class', 'const', 'continue', 'debugger',
    'default', 'delete', 'do', 'else', 'enum', 'export', 'extends', 'false',
    'finally', 'for', 'function', 'if', 'implements', 'import', 'in', 'instanceof',
    'interface', 'let', 'new', 'null', 'package', 'private', 'protected', 'public',
    'return', 'static', 'super', 'switch', 'this', 'throw', 'true', 'try', 'typeof',
    'var', 'void', 'while', 'with', 'yield',
]);
export const parameterName = (name, index) => reservedParameters.has(name)
    ? `arg${index}` : name;
