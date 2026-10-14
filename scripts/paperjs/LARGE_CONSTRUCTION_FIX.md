# Stack-safe construction and closure — 2026-10-14

Constructing long valid paths could overflow the JavaScript call stack.
The endpoint reconciliation loop recursively called itself inside a
`result.try` continuation, preventing the compiler from turning that branch
into a loop. All built-in endpoint policies and custom policies shared it.
After addressing that recursion, long polygon closure independently overflowed
in `split_last`, which rebuilt the list while returning from recursive calls.

The fix makes the reconciliation step an explicit `Error`/`Ok` case with a
direct tail call, and makes `split_last` use a reversed accumulator. Both now
compile to JavaScript loops. Error propagation, replacement order, callback
context and public signatures are unchanged.

Five portable regressions cover:

- 100,000-point polylines with distinct and coincident points;
- every built-in endpoint policy and custom first/last/closing context;
- invalid late boundaries and custom replacements with exact error indices;
- custom insertion and deletion of segments;
- construction and custom-policy rebuilding of a 100,001-edge closed polygon,
  checking complete edge order and closure.

`scripts/test-release` completed successfully: **1,982 fast**, **26 slow**,
**724 portable Erlang**, and **724 portable JavaScript** tests. Formatting
and `git diff --check` passed. Validation used the current working tree,
including pre-existing uncommitted work excluded from this commit. Published
figures were not separately regenerated.

This change does not fix the independent tokenizer and command-dispatch
recursion in `parse.path` on very long SVG strings. No parser source or public
API was changed. The separate zero-length-line stroke fix is already committed.
