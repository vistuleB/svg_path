"""Generate the fixture index and first-batch table from recorded observations."""
import json
from pathlib import Path
root = Path(__file__).resolve().parent
fixtures = json.loads((root / 'fixtures.json').read_text())
results = json.loads((root / 'first-batch.json').read_text())['results']
all_results = json.loads((root / 'all-fixtures.json').read_text())['results']
reviewed = {f['file'] for f in all_results}
lines = ['# SVGO fixture index', '', 'Pinned SVGO 4.1.0; retrieved 2026-10-14. All 40 fixtures have been reviewed; see SUMMARY.md and REMAINING_FIXTURES.md.', '', '| Fixture | Input paths | Status |', '| --- | ---: | --- |']
for f in fixtures:
    lines.append(f"| {f['file']} | {len(f['inputs'])} | {'Reviewed' if f['file'] in reviewed else 'Pending'} |")
(root / 'INDEX.md').write_text('\n'.join(lines) + '\n')
cases = [c for f in results for c in f['cases']]
valid = [c for c in cases if 'actual' in c]
summary = {key: sum(c['ourBytes'] == c['svgoBytes'] if key == 'equal' else c['ourBytes'] < c['svgoBytes'] if key == 'shorter' else c['ourBytes'] > c['svgoBytes'] for c in valid) for key in ['equal', 'shorter', 'longer']}
lines = ['# First batch: convertPathData.01–05', '', '52 cases: 51 valid paths and one malformed input. Both upstream optimization passes match each complete expected SVG.', '', f"Path data bytes only: ours {sum(c['ourBytes'] for c in valid)}, SVGO {sum(c['svgoBytes'] for c in valid)}. Per path: {summary['equal']} equal size, {summary['shorter']} shorter, {summary['longer']} longer. These fixtures are not a representative size benchmark.", '', 'All 51 of our outputs parse and serialize stably on a second pass. Parameter-matched sampling at 17 points per segment (plus subpath starts) finds only expected rounding differences and floating-point noise. Sampling is not a proof or an error bound. SVGO changes segment/subpath counts in three cases, reported as null in the JSON diagnostic.', '', '| Fixture/path | Our bytes | SVGO bytes | Disposition |', '| --- | ---: | ---: | --- |']
for f in results:
    for c in f['cases']:
        lines.append(f"| {f['file']}/{c['number']} | {c.get('ourBytes', '—')} | {c.get('svgoBytes', '—')} | {c['classification']} |")
lines += ['', '## Interpretation', '', '- `identical`, `initial-move-case-only`, and `equal-size-coordinate-choice`: no practical minification gap.', '- `mixed-coordinate-selection`: optimization opportunity, not a violation of our relative serialization contract. The rounding-compensated variant already corrects accumulated decimal error; its one-byte difference is command selection.', '- `packed-arc-flags`: our SVG arc flag separators are more compact. Our parser accepts them; this audit does not constitute browser rendering verification.', '- `initial-line-choice-*`: the minifying preset suppresses the first line command, which can cost bytes compared with H/V. Intermediate marker vertices and round-cap zero-length lines are preserved by both outputs. A shortest-command chooser could improve this without changing geometry.', '- `empty-subpath-preservation`: SVGO removes an empty subpath; our serializer preserves the path structure. An explicit simplification policy would be needed.', '- `style-dependent-zero-line-removal`: SVGO knows the SVG stroke/cap context. Our serializer receives only a path. Removing these lines unconditionally would damage other use cases.', '- `straight-cubic-reduction-and-initial-line-choice`: SVGO reduces a straight cubic to a line. This particular cubic has uniform control spacing, but a general reduction must consider backtracking and parameterization. This belongs to an explicit geometry simplification operation, not an automatic serializer assumption.', '- `invalid-input-pass-through`: SVGO leaves `...` untouched; our parser returns `ParseError`. Different API contract, not a bug.', '', 'No confirmed library bug in this batch. Complete input, expected output, our output, byte counts and sampled differences are in `first-batch.json`. Original SVG context remains in `upstream/test/plugins/` and `fixtures.json`.']
(root / 'FIRST_BATCH.md').write_text('\n'.join(lines) + '\n')
print(summary)
print('total fixtures', len(fixtures), 'total paths', sum(len(f['inputs']) for f in fixtures))

all_cases = [c for f in all_results for c in f['cases']]
valid = [c for c in all_cases if 'actual' in c]
assert len(all_results) == 40 and len(all_cases) == 181
assert all(c['classification'] != 'UNREVIEWED' for c in all_cases)
assert all(all(f['upstreamPasses']) for f in all_results)
assert all(c['stable'] and c['independentParserMatches'] for c in valid)
lines = ['# SVGO convertPathData audit summary', '',
         'All 40 pinned SVGO 4.1.0 fixtures reviewed (181 paths). No pending discrepancies in this fixture set. No confirmed bug under our current API contract. No production changes.', '',
         'See FIRST_BATCH.md for fixtures 01–05 and REMAINING_FIXTURES.md for fixtures 06–40, numerical investigations, limitations and proposed follow-ups.', '',
         '## Verification', '',
         '- Complete expected SVG matches on both optimization passes for all 40 upstream fixtures.',
         '- 180 valid paths serialize, parse through our parser and SVGO’s independent parser with matching command interpretation, and remain stable on a second serialization.',
         '- One intentionally invalid input (`...`, 01:15) yields our ParseError and is passed through by SVGO.',
         '- All 29 flattened-transform cases exercise our public transform parser and path transformation, with point-mapping consistency checks.',
         '- Archived hashes and the installed SVGO optimizer/helper source are verified by the runner.',
         '- These are JavaScript audit diagnostics. No new Erlang checks or full regression suite run is claimed.', '',
         '## Size observations', '',
         f"Across the 180 valid cases, our uncompressed path-data strings total {sum(c['ourBytes'] for c in valid)} bytes versus {sum(c['svgoBytes'] for c in valid)} for SVGO.", '',
         f"Per path: {sum(c['ourBytes'] < c['svgoBytes'] for c in valid)} shorter, {sum(c['ourBytes'] == c['svgoBytes'] for c in valid)} equal size, {sum(c['ourBytes'] > c['svgoBytes'] for c in valid)} longer.", '',
         'These totals mix syntax choices, structural preservation, approximation, and adapted transform flattening. They are not a representative compression benchmark or a claim of equivalent contracts. Whole-SVG attributes and compressed size are excluded.', '',
         '## Per-case inventory', '', '| Fixture/path | Our bytes | SVGO bytes | Disposition |', '| --- | ---: | ---: | --- |']
for f in all_results:
    for c in f['cases']:
        lines.append(f"| {f['file']}/{c['number']} | {c.get('ourBytes', '—')} | {c.get('svgoBytes', '—')} | {c['classification']} |")
(root / 'SUMMARY.md').write_text('\n'.join(lines) + '\n')
