#!/usr/bin/env python3
"""Reconcile raw comparator flags with individually investigated dispositions.

Does not change raw outputs or waive unknown failures. Re-run after the three
comparators; unexpected flags raise an error rather than declaring closure.
"""
import collections
import hashlib
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parent

def read(name):
    return json.loads((ROOT / name).read_text())

provenance = read('provenance.json')
for entry in provenance['files']:
    assert hashlib.sha256((ROOT / 'upstream' / entry['path']).read_bytes()).hexdigest() == entry['sha256'], entry['path']

reviewed = []
for batch in ['intersections', 'numeric', 'remaining']:
    data = read(batch + '-results.json')
    for row in data['rows']:
        status = row['status']
        if status != 'needs-investigation':
            assert status != 'confirmed-overlap-classification-bug', row
            continue
        call = row['call']
        if batch == 'intersections':
            result = row['result']
            if call in {1, 16, 1994, 2009, 2994, 2999, 3582, 3583, 3584}:
                assert result.get('error') == 'NonAffineOverlapCorrespondence', row
                disposition = 'non-affine-overlap-contract-difference'
            elif call in {12, 2005, 2997}:
                assert result.get('error') == 'NonAffineOverlapCorrespondence', row
                disposition = 'default-tolerance-thin-geometry-policy'
            elif call in {13, 2006, 2998}:
                assert result['ok'] and len(result['values']) == 1 and result['residualCheck'], row
                assert result['values'][0]['left_t'] == result['values'][0]['right_t'] == 0, row
                disposition = 'canonical-constant-parameter-convention'
            else:
                assert call in {1268, 1276, 1283, 1288, 1326, 1335, 1683, 1684, 1714}, row
                assert result['ok'] and result['residualCheck'], row
                assert result['matchedReferenceCount'] == len(row['reference']), row
                disposition = 'documented-tangent-candidate-cluster'
        elif batch == 'numeric':
            assert call == 13594 and row.get('error') == 'InvalidLengthDistance', row
            evidence = read('closure/length-boundary.json')
            assert 0 < evidence['difference'] < 1e-12 and evidence['atOwnLength']['0'] == 1, evidence
            disposition = 'independently-rounded-total-length-boundary'
        else:
            assert call == 728 and 'ours' in row and 'timeout' not in row, row
            assert 0.000999 < row['ours']['distance'] < row['expected'], row
            disposition = 'different-default-closest-pair-accuracy'
        reviewed.append({'batch': batch, 'call': call, 'disposition': disposition})

summary = {
    'reviewedRevision': 'a7d8cc7',
    'upstreamRevision': provenance['revision'],
    'verifiedArchivedFiles': len(provenance['files']),
    'rawCounts': {batch: read(batch + '-results.json')['counts'] for batch in ['intersections', 'numeric', 'remaining']},
    'reviewedFlagCounts': dict(collections.Counter(r['disposition'] for r in reviewed)),
    'reviewedFlags': reviewed,
    'unclassifiedFlags': 0,
}
(ROOT / 'closure' / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
print(json.dumps({k:v for k,v in summary.items() if k != 'reviewedFlags'}, indent=2))
