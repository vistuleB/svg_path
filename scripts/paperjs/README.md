# Paper.js audit and regression coverage

Start with the [file-by-file index](INDEX.md). It maps all 37 original upstream
test files to archived source, extracted fixtures, findings, passing adaptations,
diagnostic probes, and related native regressions.

This is a bug-finding and contract-comparison audit, **not a claim of complete
Paper.js parity**. A recorded API difference is not a passing equivalence test.

## Three distinct kinds of material

1. **Upstream archive and audit records:** `upstream/` preserves the original
   filenames from Paper.js `test/tests/`. The [catalog](catalog.json) and generated
   [file pages](INDEX.md) provide navigation. [inventory.json](inventory.json)
   retains the original core test titles; [final-file-screening.json](final-file-screening.json)
   records the scope and disposition of all 37 files. Downloaded or screened
   assertions are not automatically counted as executed tests.
2. **Passing contract-aware adaptations:** `test/svg_path_paper_*` and
   `test_slow/svg_path_paper_*` contain explicitly labeled comparison tests.
   An upstream file can have both fast and slow adaptations. These remain in
   ordinary release validation and CI, and can also be run as their own suite.
3. **Native regressions:** reduced cases protecting our own contracts stay in
   their domain modules. They link back to their upstream origin through the
   catalog and source comments. They are not counted as upstream assertion parity.
   The full fixture 172 adaptation is separate from its reduced native CSG test.

## Commands

```sh
# Passing Paper.js adaptations only, both targets and both speed profiles:
scripts/test-paperjs-adapted

# Select a target and speed profile:
scripts/test-paperjs-adapted javascript fast
scripts/test-paperjs-adapted erlang slow

# Complete release validation, including native and Paper.js regressions:
scripts/test-release

# Raw upstream-expectation diagnostics; documented API mismatches can fail:
scripts/test-paperjs

# Check archive hashes, adaptation registration, links, and generated indexes:
python3 scripts/paperjs/catalog.py --check
```

The adaptation command shares the generated `test_portable/test/` directory
with `test-portable`. Do not run them concurrently, or during `test-slow`'s
source-directory swap. Individual diagnostic probes are linked from each file
page; they are separate from the passing adaptation command.

## Provenance

- Source repository: <https://github.com/paperjs/paper.js>.
- Pinned source revision: `92775f5279c05fb7f0a743e9e7fa02cd40ec1e70`.
- Extraction runtime: `paper@0.12.18`. This does not identify the pinned source
  as that release; the commit is the source identity.
- First documented core review: 2026-10-12. Full archive consolidated: 2026-10-14.
- Exact download timestamps were not recorded. `catalog.json` leaves them null
  rather than inventing dates. All source hashes match the earlier screening.
- Upstream [MIT license](upstream/LICENSE.txt) and attribution are retained.

## Current disposition

The selected bug-finding review is complete. The Boolean inventory has 119
matched/adapted geometry comparisons and 59 understood overlap-contract
limitations; those counts do not imply exhaustive equivalence. See the file
pages for unexecuted assertions, unsupported APIs and diagnostic allowances.

The construction/closure crash, zero-line/arc stroke defect, and follow-up
parser tokenizer/command-dispatch overflows are fixed. Parser fixes were
committed as `7ddb2fc` and `256c5e1`; their native regressions remain fast and
portable. No parser-overflow fix remains pending from that investigation.
[Dead-code cleanup](DEFERRED_CLEANUP.md) remains deferred.

The detailed [final audit](FINAL_AUDIT.md), [performance findings](../performance/2026-10-14-findings.txt),
and [historical investigation log](HISTORY.md) retain the evidence. Historical
reports describe the state at the time and can contain superseded failure counts
or candidate fixes; they are not current release-status summaries.

## Maintaining this structure

Add provenance and file ownership to `catalog.json` when adding an adaptation,
then run `python3 scripts/paperjs/catalog.py` to regenerate navigation. The checker
rejects unindexed Paper.js test modules and adaptations missing from their
portable registry. CI checks the catalog.

Keep full upstream fixtures in named `svg_path_paper_*` modules. Keep reduced
native tests focused on our contract and record their origin. Choose fast/slow
placement for the adapted workload, not for an entire upstream file. Generated
fixtures use `test_profiles.py` to preserve the chosen split. Do not remove
expensive regressions merely to make the fast suite quicker.
