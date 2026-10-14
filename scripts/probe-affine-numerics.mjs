// Diagnostic companion to the portable affine regressions.
// Run scripts/test-portable javascript first, then node scripts/probe-affine-numerics.mjs.
import * as A from '../test_portable/build/dev/javascript/svg_path/svg_path/affine.mjs';
import { Ok } from '../test_portable/build/dev/javascript/svg_path/gleam.mjs';

function outcome(m, order) {
  const result = A.decompose_with_order(m, order);
  return result instanceof Ok ? 'Ok' : result[0].constructor.name;
}

const normalization = [
  [new A.Affine(1e-300, 1e-300, 1e300, 2e300, 0, 0), new A.TranslationScaleRotationShearX()],
  [new A.Affine(1e300, 0, 1e300, 1e-300, 0, 0), new A.TranslationRotationShearXScale()],
].map(([matrix, order]) => ({ matrix, result: outcome(matrix, order) }));

const boundary = { cases: 0, outcomes: {}, unexpected: [], numericalLimits: [] };
for (const top of [1e-300, 1e-150, 1, 1e150, 1e300]) {
  for (const bottom of [1e-300, 1e-150, 1, 1e150, 1e300]) {
    for (const delta of [-1e-10, -1e-13, -1e-14, 0, 1e-14, 1e-13, 1e-10]) {
      for (const dual of [false, true]) {
        const matrix = new A.Affine(...(dual
          ? [bottom * (2 + delta), bottom, 0, top, 0, 0]
          : [top, bottom, 0, bottom * (2 + delta), 0, 0]));
        const order = dual ? new A.TranslationShearXRotationScale() : new A.TranslationScaleRotationShearX();
        const result = outcome(matrix, order);
        boundary.cases++;
        boundary.outcomes[result] = (boundary.outcomes[result] ?? 0) + 1;
        const allowed = delta < -1e-14
          ? result === 'NoFactorizationInOrder'
          : result === 'Ok' || (top !== bottom && result === 'DecompositionUnstable');
        if (!allowed) boundary.unexpected.push({ top, bottom, delta, dual, result });
        if (result === 'DecompositionUnstable') boundary.numericalLimits.push({ top, bottom, delta, dual });
      }
    }
  }
}

// Search for the suspected path: numerical scale loss followed by a singular
// translation rejection. This finite grid is diagnostic, not a proof of absence.
const subnormal = { cases: 0, impossibleReports: [] };
for (let ai = 1; ai <= 16; ai++) {
  for (let ci = -16; ci <= 16; ci++) {
    for (const b of [-10, -1, .1, 1, 10]) {
      for (const d of [-10, -1, .1, 1, 10]) {
        const det = ai * d - b * ci, k = ai * b;
        if (det === 0 || Math.abs(det) < 2 * Math.abs(k)) continue;
        const matrix = new A.Affine(ai * Number.MIN_VALUE, b, ci * Number.MIN_VALUE, d, 1, 1);
        const result = outcome(matrix, new A.ScaleTranslationRotationShearX());
        subnormal.cases++;
        if (result === 'NoFactorizationInOrder') subnormal.impossibleReports.push({ matrix, result });
      }
    }
  }
}
console.log(JSON.stringify({ normalization, boundary, subnormal }, null, 2));
if (normalization.some(x => x.result !== 'DecompositionUnstable') || boundary.unexpected.length || subnormal.impossibleReports.length) {
  process.exitCode = 1;
}
