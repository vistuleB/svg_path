# Consumer review — 2026-10-22

## Verdict

The installed preview is usable from JavaScript and TypeScript without Gleam
installed. This pass found documentation and verification gaps, but no new runtime
adapter defect in the exercised operations. It does not establish correctness
for every public operation or eliminate the limitations below.

## Addressed in this pass

- The verifier now extracts every `js` code block from the installed README,
  executes each in its own ESM module, and type-checks each under strict
  TypeScript. Previously a separate test duplicated the introductory recipe.
- Four recipes cover parsing/measurement, offset configuration, structured
  errors, and synchronous point mapping.
- Documentation clarifies explicit `null` optional values, full configuration
  records, constructor calls, snapshot records, opaque handles tied to one
  package instance, and the Gleam syntax retained in generated API documentation.
- Two additional installed-package tests check missing/undefined optional fields
  and verify that editing inspected segments does not mutate opaque subpaths.
- Verification checks required documentation and license files in the installed
  archive. Existing checks cover blocked internal exports, dependency-free
  packing, metadata agreement, structured error payloads, callback exceptions,
  asynchronous-callback rejection, and forged/wrong-kind opaque handles.
- CI now requests both Node 20 (the advertised minimum) and Node 24.

## Before publication (updated for release preparation)

1. Release preparation now selects `svg-path-geometry@0.1.0`; the distribution
   is public and the tools remain private. Registry availability was checked
   on 2026-10-22 (HTTP 404). Actual publication remains a separate action.
2. Obtain successful CI results for Node 20 and 24. Node 20 is not installed
   locally; this pass verified Node 24.10.0 and Chromium 156.0.8078.4 only.
3. Commit the final adapter/docs, rebuild and verify the final archive, and retain
   its integrity and source report. `gleamCommit` records build-time repository
   HEAD; `sourceDirty` covers geometry source/configuration only, not adapter
   changes. The separate adapter fingerprint identifies adapter contents. A
   pre-commit preview archive must not be mistaken for the final release archive.

## Optional follow-ups, not blockers for the documented preview

- Native JavaScript task-oriented documentation beyond the four README recipes.
  Generated API text still contains Gleam examples and argument conventions.
- Browser testing beyond Chromium, conversion-cost benchmarks, and better
  tree shaking. The registry imports all public modules eagerly.
- More representative end-to-end calls across the 600 functions. Constructor
  conversion coverage is broad; operation coverage is deliberately selective.

Opaque handles are not JSON/worker-transferable and are specific to their loaded
package instance. ESM, explicit Results, complete option records, and synchronous
callbacks are intentional conventions, not pending bugs. No CommonJS contract is
promised. No Gleam geometry, F# port, publication, or push was part of this pass.
