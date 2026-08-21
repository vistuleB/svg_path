# Arrangement Graph construction new plan

- no normalization before construction; this is the caller's problem

- arrangement.build takes a List(Segment)

- there should be forward <-> backward maps delivered on successful construction:

    - for each Segment, List of #(ta, tb, edge_id, Bool, Bool) where #(ta, tb) are the start-end parameters, first Bool denotes reversal and second Bool denotes  'own': if this Segment is the originator of that Edge, or if this portion was overlapped 

    - for each Edge, List of matching #(segment_index, ta, tb, Bool) where the first element of the list is the originator of the Edge (first to lay it down) and the Bool denotes reversal or not; ta <= tb always

- construction may have many parameters I'm overlooking, but I'll refer at least to `vertex_tolerance` and `endpoint_sliver_tolerance`; the former is in user space, the latter in parameter space

- construction is single "progressive" but with the following new instructions:

    - when a Segment comes in first it is checked against all existing vertices; if a vertex is found `vertex_tolerance` close to the Segment but not `vertex_tolerance` close to either endpoint of the Segment, the segment is divided at the projection of that vertex onto the segment (regardless how close the projection to either endpoint, subject only to being `vertex_tolerance` away as mentioned), the two halves of the Segment go on the stack (but as a data structure still referring back to the original Segment), etc; if the projection falls outside the segment despite being close (i.e., negative or >1 value of `t`), this is considered an unexpected error state, the process terminates

    - if the Segment survives this, it is then noted which vertices the .end and .start of the Segment can be identified with in the graph; if either can be identified with >1, the process terminates again: it should be at most 1 each

    - only once this is done (think: one Option(Vertex) per endpoint, at this stage), do we look for Segment-Edge intersections; any intersection that occurs less than `endpoint_sliver_tolerance` on both the Segment and the Edge away from a **COMMON** endpoint (same vertex) is ignored; any other intersection causes the segment to be broken into two, and tossed back onto the stack

    - overlap, if it occurs, should be parameter-exact for now; we might relax this later to geometry-exact overlap with an input option; (we might even choose to ignore geometry-only overlaps and treat these as two separates edges joining the same endpoint, but we don't need this now)

    - a segment endpoint is NEVER snapped to a graph endpoint; we ALWAYS evaluate positions from the original Segments 

    - the process terminates exactly when a Segment is successfully processed, and the stack is found to be empty

    - nothing changes after the end of the progressive pass 

- certification should involve certification of the two-way correspondence maps, as well as the overlap correspondences, etc


# Offset new plan

We should have normalization phase of the original Path. We're doing too much catch-up at offset-time, not enough preparation before that.

Normalization phase:

1. eliminate small segments e.g. length < 1e-3; to "eliminate" a segment, adjacent segments are mapped affinely to fill the gap, or else by a slightly more clever method but for now just affinely (there is no failure possible here)

2. if we choose, run the degenerary colinearity normalizer (well, why not, we can do that)

3. make near-colinear consecutive tangents exactly colinear within a tolerance, by rotating tangent like we do in the pair-healing function; but we can only rotate tangents on on Quadratic & CubicBeziers, others we leave alone

4. after this we do the split into JoinFree sections; but with a much tighter quasi machine-tolerance requirement on tangent alignment, though still practical, e.g., 0.001°

5. after this in each JoinFree we subdivide by hinges, inflection points, classify each boundary etc

6. at offset time, hinges still do their .25° thing

7. at heal time, we only heal continuity via affine motion of segments; we completely ignore tangent directions at heal time

8. after adding joins, in the case of single offsets we also cut the resulting Path by the normalized source Path before building the arrangement graph

9. arrangement graph filtering with another hardcoded constant, the famed `side_sample_distance', currently 0.001; from there, no major changes