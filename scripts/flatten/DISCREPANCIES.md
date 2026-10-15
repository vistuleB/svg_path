# Discrepancy dispositions

Raw flagged comparisons, not a count of confirmed bugs. See REMAINING-TRIAGE.md for current diagnoses and open fixes; FINDINGS.md retains the history.

| Call | Upstream file and test | Observation | Disposition |
| --- | --- | --- | --- |
| `linear:66` | `test/classes/segment.js` — #Flatten.Segment #Flatten.Segment.DistanceTo Distance to Circle Case 1 Intersection - two points | RangeError: Maximum call stack size exceeded | fixed |
| `linear:67` | `test/classes/segment.js` — #Flatten.Segment #Flatten.Segment.DistanceTo Distance to Circle Case 1 Intersection - one points | RangeError: Maximum call stack size exceeded | fixed |
| `polygons:317` | `test/classes/polygon.js` — #Flatten.Polygon Can measure distance between two polygons | 30-second timeout | fixed |
| `polygons:3115` | `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Union Can perform unify. Fixed: Infinite loop for boolean union over (valid) polygons. Issue #53 | Discontinuous; adapt-upstream-output | adapter-contract-difference |
| `polygons:3380` | `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Union Can perform unify. Fixed: Infinite loop for boolean union over (valid) polygons. Issue #55 case 2 | ArrangementGraphError; native-boolean-query | fixed |
| `polygons:3497` | `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Union Can perform unify. Fixed: Infinite loop for boolean union over (valid) polygons. Issue #55 case 3 | ArrangementGraphError; native-boolean-query | fixed |
| `polygons:4033` | `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Subtraction Can perform subtract. Fixed: Infinite loop for boolean union over (valid) polygons. Issue #55 case 2 | ArrangementGraphError; native-boolean-query | fixed |
| `polygons:4150` | `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Subtraction Can perform subtract. Fixed: Infinite loop for boolean union over (valid) polygons. Issue #55 case 3 | ArrangementGraphError; native-boolean-query | fixed |
| `polygons:4278` | `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Intersection Issue #2 with intersection of circle and box | Discontinuous; adapt-upstream-output | adapter-contract-difference |
| `polygons:4279` | `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Intersection Issue #2 with intersection of circle and box | Discontinuous; adapt-left-input | adapter-contract-difference |
| `polygons:4280` | `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Intersection Issue #2 with intersection of circle and box | Discontinuous; adapt-left-input | adapter-contract-difference |
| `polygons:4281` | `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Intersection Issue #2 with intersection of circle and box | Discontinuous; adapt-left-input | adapter-contract-difference |
| `polygons:4282` | `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Intersection Issue #2 with intersection of circle and box | Discontinuous; adapt-left-input | adapter-contract-difference |
| `polygons:4291` | `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Intersection Issue #3 | Discontinuous; adapt-upstream-output | adapter-contract-difference |
| `polygons:4292` | `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Intersection Issue #3 | Discontinuous; adapt-left-input | adapter-contract-difference |
| `polygons:4293` | `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Intersection Issue #3 | Discontinuous; adapt-left-input | adapter-contract-difference |
| `polygons:4294` | `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Intersection Issue #3 | Discontinuous; adapt-left-input | adapter-contract-difference |
| `polygons:4295` | `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Intersection Issue #3 | Discontinuous; adapt-left-input | adapter-contract-difference |
| `polygons:4296` | `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Intersection Issue #3 | Discontinuous; adapt-left-input | adapter-contract-difference |
| `polygons:4354` | `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Intersection Subtract bug from flatten-js/core 1.2 onwards #15 | sampled geometry mismatch | upstream-contract-difference |
| `polygons:4682` | `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Intersection Can perform intersect. Fixed: Infinite loop for boolean union over (valid) polygons. Issue #55 case 2 | ArrangementGraphError; native-boolean-query | fixed |
| `polygons:4799` | `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Intersection Can perform intersect. Fixed: Infinite loop for boolean union over (valid) polygons. Issue #55 case 3 | ArrangementGraphError; native-boolean-query | fixed |
| `polygons:4920` | `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Intersection Fixed: Infinite Loop when intersecting Polygons (v1.3.4) #139 | ArrangementGraphError; native-boolean-query | confirmed-native-failure |
