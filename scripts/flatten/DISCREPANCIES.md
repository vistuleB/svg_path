# Deferred discrepancy queue

Raw flagged comparisons, not a count of confirmed bugs. See FINDINGS.md for known diagnoses.

| Call | Upstream file and test | Observation | Disposition |
| --- | --- | --- | --- |
| `linear:66` | `test/classes/segment.js` — #Flatten.Segment #Flatten.Segment.DistanceTo Distance to Circle Case 1 Intersection - two points | RangeError: Maximum call stack size exceeded | confirmed-library-bug |
| `linear:67` | `test/classes/segment.js` — #Flatten.Segment #Flatten.Segment.DistanceTo Distance to Circle Case 1 Intersection - one points | RangeError: Maximum call stack size exceeded | confirmed-library-bug |
| `polygons:317` | `test/classes/polygon.js` — #Flatten.Polygon Can measure distance between two polygons | 30-second timeout | deferred investigation |
| `polygons:3115` | `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Union Can perform unify. Fixed: Infinite loop for boolean union over (valid) polygons. Issue #53 | Discontinuous; adapt-upstream-output | deferred investigation |
| `polygons:3380` | `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Union Can perform unify. Fixed: Infinite loop for boolean union over (valid) polygons. Issue #55 case 2 | ArrangementGraphError; native-boolean-query | deferred investigation |
| `polygons:3497` | `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Union Can perform unify. Fixed: Infinite loop for boolean union over (valid) polygons. Issue #55 case 3 | ArrangementGraphError; native-boolean-query | deferred investigation |
| `polygons:4033` | `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Subtraction Can perform subtract. Fixed: Infinite loop for boolean union over (valid) polygons. Issue #55 case 2 | ArrangementGraphError; native-boolean-query | deferred investigation |
| `polygons:4150` | `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Subtraction Can perform subtract. Fixed: Infinite loop for boolean union over (valid) polygons. Issue #55 case 3 | ArrangementGraphError; native-boolean-query | deferred investigation |
| `polygons:4278` | `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Intersection Issue #2 with intersection of circle and box | Discontinuous; adapt-upstream-output | deferred investigation |
| `polygons:4279` | `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Intersection Issue #2 with intersection of circle and box | Discontinuous; adapt-left-input | deferred investigation |
| `polygons:4280` | `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Intersection Issue #2 with intersection of circle and box | Discontinuous; adapt-left-input | deferred investigation |
| `polygons:4281` | `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Intersection Issue #2 with intersection of circle and box | Discontinuous; adapt-left-input | deferred investigation |
| `polygons:4282` | `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Intersection Issue #2 with intersection of circle and box | Discontinuous; adapt-left-input | deferred investigation |
| `polygons:4291` | `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Intersection Issue #3 | Discontinuous; adapt-upstream-output | deferred investigation |
| `polygons:4292` | `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Intersection Issue #3 | Discontinuous; adapt-left-input | deferred investigation |
| `polygons:4293` | `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Intersection Issue #3 | Discontinuous; adapt-left-input | deferred investigation |
| `polygons:4294` | `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Intersection Issue #3 | Discontinuous; adapt-left-input | deferred investigation |
| `polygons:4295` | `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Intersection Issue #3 | Discontinuous; adapt-left-input | deferred investigation |
| `polygons:4296` | `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Intersection Issue #3 | Discontinuous; adapt-left-input | deferred investigation |
| `polygons:4354` | `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Intersection Subtract bug from flatten-js/core 1.2 onwards #15 | sampled geometry mismatch | deferred investigation |
| `polygons:4682` | `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Intersection Can perform intersect. Fixed: Infinite loop for boolean union over (valid) polygons. Issue #55 case 2 | ArrangementGraphError; native-boolean-query | deferred investigation |
| `polygons:4799` | `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Intersection Can perform intersect. Fixed: Infinite loop for boolean union over (valid) polygons. Issue #55 case 3 | ArrangementGraphError; native-boolean-query | deferred investigation |
| `polygons:4920` | `test/algorithms/boolean_op.js` — #Algorithms.Boolean Operations #Algorithms.Boolean Intersection Fixed: Infinite Loop when intersecting Polygons (v1.3.4) #139 | ArrangementGraphError; native-boolean-query | deferred investigation |
