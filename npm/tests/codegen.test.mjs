import test from 'node:test';
import assert from 'node:assert/strict';
import {parameterNames, runtimeSchemaOf, createTypePrinter} from '../tools/codegen.mjs';
import {fieldName, parameterName} from '../tools/api-shape.mjs';

test('parameter extraction ignores documentation and handles nested function types', () => {
  const source = `/// pub fn example(wrong: Float)
pub fn example(callback: fn(Float, Float) -> Float, with_label real_name: Float) {}`;
  assert.deepEqual(parameterNames(source, 'example', 2), ['callback', 'realName']);
});

test('reserved parameter names do not change record field names', () => {
  assert.equal(parameterName('default', 0), 'arg0');
  assert.equal(parameterName('realName', 1), 'realName');
  assert.equal(fieldName({label: 'default'}, 0), 'default');
  assert.equal(fieldName({label: null}, 2), 'value2');
});

test('runtime schema preserves symbols whose names match metadata', () => {
  const schema = {modules: {example: {
    documentation: ['module docs'], types: {}, 'type-aliases': {}, constants: {},
    functions: {documentation: {documentation: 'function docs', parameters: [], return: {kind: 'variable', id: 0}}}
  }}};
  const runtime = runtimeSchemaOf(schema);
  assert.ok(runtime.modules.example.functions.documentation);
  assert.equal(runtime.modules.example.functions.documentation.documentation, undefined);
  assert.equal(schema.modules.example.functions.documentation.documentation, 'function docs');
});

test('unknown compiler type shapes fail with a specific diagnostic', () => {
  assert.throws(() => createTypePrinter({modules: {}})({kind: 'future-kind'}, 'svg_path'), /Unsupported interface type kind: future-kind/);
});
