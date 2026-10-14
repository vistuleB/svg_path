"""Extract pinned fixtures, preserving complete SVG context for SVGO."""
import json
import re
from pathlib import Path
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parent
fixtures = []
for file in sorted((root / 'upstream/test/plugins').glob('convertPathData.*.svg.txt')):
    text = file.read_text().strip()
    description = re.split(r'\s*===\s*', text)
    if len(description) == 2:
        text = description[1]
    parts = re.split(r'\s*@@@\s*', text)
    original, expected = parts[:2]
    def paths(svg):
        return [dict(e.attrib) for e in ET.fromstring(svg).iter() if 'd' in e.attrib]
    before, after = paths(original), paths(expected)
    fixtures.append(dict(file=file.name, original=original, expected=expected,
                         params=json.loads(parts[2]) if len(parts) > 2 else {},
                         inputs=before, outputs=after))
(root / 'fixtures.json').write_text(json.dumps(fixtures, indent=2) + '\n')
