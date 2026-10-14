"""Keep selected expensive generated regressions outside ordinary discovery."""
import re


def write_profiles(root, filename, source, slow_names, fast_omit_imports=()):
    # These generators emit imports/private helpers followed by public tests.
    starts = list(re.finditer(r'(?m)^(?://[^\n]*\n)*pub fn (\w+)\(', source))
    header = source[:starts[0].start()]
    fast, slow = [], []
    found = set()
    for i, match in enumerate(starts):
        end = starts[i + 1].start() if i + 1 < len(starts) else len(source)
        block = source[match.start():end]
        if match[1] in slow_names:
            slow.append(block)
            found.add(match[1])
        else:
            fast.append(block)
    assert found == set(slow_names), (found, slow_names)
    fast_header = header
    for module in fast_omit_imports:
        fast_header = fast_header.replace(f'import {module}\n', '')
    (root / 'test' / filename).write_text(fast_header + ''.join(fast))
    slow_filename = filename.replace('_test.gleam', '_slow_test.gleam')
    (root / 'test_slow' / slow_filename).write_text(header + ''.join(slow))
