// Build with `scripts/test-portable javascript`, then run:
//   node scripts/benchmark-area.mjs
// Each case uses a fresh worker (no warm-up). Times include linearization and
// arrangement; they are observations, not CI assertions or accuracy guarantees.
import { Worker, isMainThread, parentPort, workerData } from 'node:worker_threads';

if (isMainThread) {
  for (const scale of [1, 1000, 100000]) {
    for (const scaledTolerance of [false, true]) {
      const result = await new Promise((resolve) => {
        const worker = new Worker(new URL(import.meta.url), {
          workerData: { scale, scaledTolerance },
        });
        let finished = false;
        const finish = (result) => {
          if (finished) return;
          finished = true;
          clearTimeout(timer);
          void worker.terminate();
          resolve(result);
        };
        const timer = setTimeout(() => finish({ timeoutMs: 8000 }), 8000);
        worker.on('message', finish);
        worker.on('error', (error) => finish({ error: String(error) }));
        worker.on('exit', (code) => {
          if (!finished) finish({ error: `Worker exited without a result (${code})` });
        });
      });
      console.log(JSON.stringify({ scale, scaledTolerance, ...result }));
      if (result.error) process.exitCode = 1;
    }
  }
} else {
  const base = new URL('../test_portable/build/dev/javascript/svg_path/', import.meta.url);
  const svg = await import(new URL('svg_path.mjs', base));
  const area = await import(new URL('svg_path/area.mjs', base));
  const { scale, scaledTolerance } = workerData;
  const curve = new svg.QuadraticBezier(
    new svg.Point(0, 0),
    new svg.Point(50 * scale, 40 * scale),
    new svg.Point(100 * scale, 0),
  );
  const path = svg.subpath_as_path(svg.segment_as_subpath(curve));
  const defaults = svg.default_linearize_options();
  const options = new svg.LinearizeOptions(
    defaults.tolerance * (scaledTolerance ? scale : 1),
    defaults.max_depth,
  );
  const start = performance.now();
  const result = area.path_with(path, new svg.Nonzero(), options);
  const milliseconds = performance.now() - start;
  if (!result.isOk()) throw new Error(`Area failed: ${JSON.stringify(result)}`);
  const lines = svg.path_to_lines_with(path, options);
  if (!lines.isOk()) throw new Error(`Linearization failed: ${JSON.stringify(lines)}`);
  let segments = 0;
  for (const subpath of lines[0].subpaths) {
    for (const _ of subpath.segments) segments++;
  }
  parentPort.postMessage({
    segments,
    milliseconds,
    normalizedArea: result[0] / scale ** 2,
    exactNormalizedSignedArea: Math.abs(area.signed_path(path)) / scale ** 2,
  });
}
