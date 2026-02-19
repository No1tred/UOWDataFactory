public class FL_SingleTypeOpCalculator {

    public class EdgeInput {
        public FL_SObjectNode fromNode; // original direction: from -> to
        public FL_SObjectNode toNode;
        public EdgeInput(FL_SObjectNode fromNode, FL_SObjectNode toNode) {
            this.fromNode = fromNode;
            this.toNode = toNode;
        }
    }

    public class Result {
        public Integer bestSteps;
        public List<FL_TypeAndOperation> bestColorSequence;
        public Result(Integer bestSteps, List<FL_TypeAndOperation> bestColorSequence) {
            this.bestSteps = bestSteps;
            this.bestColorSequence = bestColorSequence;
        }
    }

    // In OperationCalculator.cls
    public static Integer lowerBoundStepsLeavesUp(
            List<FL_SObjectNode> nodes,
            List<EdgeInput> edges
    ) {
        if (nodes == null || nodes.isEmpty()) return 0;

        Integer n = nodes.size();

        // Index nodes
        Map<FL_SObjectNode, Integer> idxByKey = new Map<FL_SObjectNode, Integer>();
        for (Integer i = 0; i < n; i++) idxByKey.put(nodes[i], i);

        // Colors -> compact ids (same as solver)
        Map<FL_TypeAndOperation, Integer> colorIdByLabel = new Map<FL_TypeAndOperation, Integer>();
        List<Integer> colorId = new List<Integer>();
        for (Integer i = 0; i < n; i++) {
            FL_TypeAndOperation c = nodes[i].typeAndOperation;
            Integer cid = colorIdByLabel.get(c);
            if (cid == null) {
                cid = colorIdByLabel.size();
                colorIdByLabel.put(c, cid);
            }
            colorId.add(cid);
        }
        Integer colorCount = colorIdByLabel.size();

        // Build reverse adjacency (parents) + outDegree (original)
        GraphData g = buildParentsCSR(n, edges, idxByKey);

        // Kahn topo on REVERSED graph: indegRev[v] == outDegOriginal[v]
        List<Integer> indegRev = new List<Integer>();
        for (Integer i = 0; i < n; i++) indegRev.add(g.outDegInit[i]);

        List<Integer> q = new List<Integer>();
        for (Integer i = 0; i < n; i++) if (indegRev[i] == 0) q.add(i); // leaves

        Integer qi = 0;

        // dpHeight[v] = longest path length (in nodes) ending at v in reversed graph
        // dpSame[v]   = longest same-color chain length (in nodes) ending at v (only along edges where color matches)
        List<Integer> dpHeight = new List<Integer>();
        List<Integer> dpSame = new List<Integer>();
        for (Integer i = 0; i < n; i++) { dpHeight.add(1); dpSame.add(1); }

        // bestSamePerColor[c] = max dpSame[v] among nodes of color c
        List<Integer> bestSamePerColor = new List<Integer>();
        for (Integer c = 0; c < colorCount; c++) bestSamePerColor.add(0);

        Integer heightLB = 1;

        while (qi < q.size()) {
            Integer v = q[qi++];
            Integer cv = colorId[v];

            // Track best same-color chain per color
            if (dpSame[v] > bestSamePerColor[cv]) bestSamePerColor[cv] = dpSame[v];
            if (dpHeight[v] > heightLB) heightLB = dpHeight[v];

            // edges in reversed graph: v -> parent(v)
            for (Integer pi = g.parentsStart[v]; pi < g.parentsStart[v + 1]; pi++) {
                Integer p = g.parent[pi];

                // Height relaxation always
                Integer candH = dpHeight[v] + 1;
                if (candH > dpHeight[p]) dpHeight[p] = candH;

                // Same-color relaxation only if same color
                if (colorId[p] == cv) {
                    Integer candS = dpSame[v] + 1;
                    if (candS > dpSame[p]) dpSame[p] = candS;
                }

                // Kahn decrement
                indegRev[p] = indegRev[p] - 1;
                if (indegRev[p] == 0) q.add(p);
            }
        }

        // If graph is invalid (cycle), q won't reach all nodes
        if (q.size() != n) {
            throw new FL_InvalidGraphException('Cyclic graph detected: no sink nodes available at start.');
        }

        Integer sumSameLB = 0;
        for (Integer c = 0; c < colorCount; c++) {
            Integer v = bestSamePerColor[c];
            if (v > 0) sumSameLB += v; // each color present contributes at least 1
        }

        return Math.max(heightLB, sumSameLB);
    }

    public static Result solveMultiStartLeavesUp(
            List<FL_SObjectNode> nodes,
            List<EdgeInput> edges,
            Integer runs,
            Integer topMChoices
    ) {
        if (nodes == null || nodes.isEmpty()) return new Result(0, new List<FL_TypeAndOperation>());
        if (runs == null || runs < 1) runs = 1;
        if (topMChoices == null || topMChoices < 1) topMChoices = 1;

        Integer n = nodes.size();

        // Index nodes
        Map<FL_SObjectNode, Integer> idxByKey = new Map<FL_SObjectNode, Integer>();
        for (Integer i = 0; i < n; i++) idxByKey.put(nodes[i], i);

        // Colors -> compact ids
        Map<FL_TypeAndOperation, Integer> colorIdByLabel = new Map<FL_TypeAndOperation, Integer>();
        List<FL_TypeAndOperation> colorLabelByIndex = new List<FL_TypeAndOperation>();
        List<Integer> colorId = new List<Integer>();
        for (Integer i = 0; i < n; i++) {
            FL_TypeAndOperation color = nodes[i].typeAndOperation;
            Integer colorIndex = colorIdByLabel.get(color);
            if (colorIndex == null) {
                colorIndex = colorLabelByIndex.size();
                colorIdByLabel.put(color, colorIndex);
                colorLabelByIndex.add(color);
            }
            colorId.add(colorIndex);
        }
        Integer colorCount = colorLabelByIndex.size();

        // Build reverse adjacency (parents) + initial outDegree
        GraphData g = buildParentsCSR(n, edges, idxByKey);

        // Precompute "up-criticality": longest distance to a source when moving upward
        // (this is equivalent to longest path to sink in the REVERSED graph).
        List<Integer> upCrit = computeUpCriticality(n, g.parentsStart, g.parent, g.outDegInit);

        // weights
        List<Long> weight = new List<Long>();
        for (Integer i = 0; i < n; i++) weight.add(1L + (Long)upCrit[i]);

        Integer bestSteps = null;
        List<Integer> bestSeqIds = null;

        for (Integer r = 0; r < runs; r++) {
            Boolean randomized = (r != 0);
            RunResult rr = runGreedyLeavesUp(
                    n, colorCount, colorId,
                    g.parentsStart, g.parent, g.outDegInit,
                    weight,
                    topMChoices,
                    randomized
            );

            if (bestSteps == null || rr.steps < bestSteps) {
                bestSteps = rr.steps;
                bestSeqIds = rr.colorSequenceIds;
            }
        }

        List<FL_TypeAndOperation> bestSeq = new List<FL_TypeAndOperation>();
        if (bestSeqIds != null) {
            for (Integer cid : bestSeqIds) bestSeq.add(colorLabelByIndex[cid]);
        }
        return new Result(bestSteps == null ? 0 : bestSteps, bestSeq);
    }

    // ---- Graph container for leaves-up ----
    private class GraphData {
        public List<Integer> parentsStart; // size n+1
        public List<Integer> parent;       // concatenated parents
        public List<Integer> outDegInit;   // size n (original out-degree)
        public GraphData(List<Integer> parentsStart, List<Integer> parent, List<Integer> outDegInit) {
            this.parentsStart = parentsStart;
            this.parent = parent;
            this.outDegInit = outDegInit;
        }
    }

    /**
     * Build CSR of parents:
     * parent edges are (to <- from) i.e. for node v, store its parents u where u->v in original graph.
     * Also compute initial out-degree of each node in original graph.
     */
    private static GraphData buildParentsCSR(
            Integer n,
            List<EdgeInput> edges,
            Map<FL_SObjectNode, Integer> idxByKey
    ) {
        Integer m = (edges == null) ? 0 : edges.size();

        List<Integer> parentCount = new List<Integer>();
        List<Integer> outDegInit = new List<Integer>();
        for (Integer i = 0; i < n; i++) { parentCount.add(0); outDegInit.add(0); }

        // Count parents per node, and out-degree per node
        for (Integer i = 0; i < m; i++) {
            EdgeInput loopEdge = edges[i];
            Integer u = idxByKey.get(loopEdge.fromNode);
            Integer v = idxByKey.get(loopEdge.toNode);
            if (u == null || v == null) continue;

            // v has parent u
            parentCount[v] = parentCount[v] + 1;
            // u has an outgoing edge
            outDegInit[u] = outDegInit[u] + 1;
        }

        // Prefix sums for parentsStart
        List<Integer> parentsStart = new List<Integer>();
        parentsStart.add(0);
        for (Integer i = 0; i < n; i++) parentsStart.add(parentsStart[i] + parentCount[i]);

        Integer pCounted = parentsStart[n];
        List<Integer> parent = new List<Integer>();
        for (Integer i = 0; i < pCounted; i++) parent.add(0);

        List<Integer> nextPos = new List<Integer>();
        for (Integer i = 0; i < n; i++) nextPos.add(parentsStart[i]);

        // Fill parents CSR
        for (Integer i = 0; i < m; i++) {
            EdgeInput e = edges[i];
            Integer u = idxByKey.get(e.fromNode);
            Integer v = idxByKey.get(e.toNode);
            if (u == null || v == null) continue;

            Integer pos = nextPos[v];
            parent[pos] = u;
            nextPos[v] = pos + 1;
        }

        return new GraphData(parentsStart, parent, outDegInit);
    }

    /**
     * Compute upCrit[v] = longest path length (in edges) from v to any SOURCE when moving upward via parents.
     *
     * This equals longest path to sink in the reversed graph, and we can compute it with:
     * - Topo order of reversed graph (which uses indegree in reversed == outDegree in original).
     * - Reverse DP over that topo order using reversed adjacency (i.e., parents lists).
     */
    private static List<Integer> computeUpCriticality(
            Integer n,
            List<Integer> parentsStart,
            List<Integer> parent,
            List<Integer> outDegInit
    ) {
        // Kahn topo on REVERSED graph: indeg_rev[v] == outDeg_original[v]
        List<Integer> indegRev = new List<Integer>();
        for (Integer i = 0; i < n; i++) indegRev.add(outDegInit[i]);

        List<Integer> q = new List<Integer>();
        for (Integer i = 0; i < n; i++) if (indegRev[i] == 0) q.add(i); // leaves in original

        Integer qi = 0;
        List<Integer> topo = new List<Integer>();

        // In reversed graph, edges are v -> parent(v) (because original parent -> v)
        while (qi < q.size()) {
            Integer v = q[qi++];
            topo.add(v);

            for (Integer pi = parentsStart[v]; pi < parentsStart[v + 1]; pi++) {
                Integer p = parent[pi];
                indegRev[p] = indegRev[p] - 1;
                if (indegRev[p] == 0) q.add(p);
            }
        }

        List<Integer> upCrit = new List<Integer>();
        for (Integer i = 0; i < n; i++) upCrit.add(0);

        // Reverse DP: upCrit[v] = max( upCrit[p] + 1 ) over parents p
        // We need to process topo from end -> start so that parents are processed after children? Actually:
        // In reversed graph, v -> p, so p comes after v in topo. For DP to propagate from v to p,
        // we can process topo forward updating parents, OR process reverse computing from parents.
        // We'll do forward relaxation for simplicity.
        for (Integer ti = 0; ti < topo.size(); ti++) {
            Integer v = topo[ti];
            Integer base = upCrit[v];
            for (Integer pi = parentsStart[v]; pi < parentsStart[v + 1]; pi++) {
                Integer p = parent[pi];
                Integer cand = base + 1;
                if (cand > upCrit[p]) upCrit[p] = cand;
            }
        }

        return upCrit;
    }

    // ---- One greedy run (leaves-up) ----
    private class RunResult {
        public Integer steps;
        public List<Integer> colorSequenceIds;
        public RunResult(Integer steps, List<Integer> colorSequenceIds) {
            this.steps = steps;
            this.colorSequenceIds = colorSequenceIds;
        }
    }

    private static RunResult runGreedyLeavesUp(
            Integer n,
            Integer colorCount,
            List<Integer> colorId,
            List<Integer> parentsStart,
            List<Integer> parent,
            List<Integer> outDegInit,
            List<Long> weight,
            Integer topMChoices,
            Boolean randomized
    ) {
        // Working out-degrees + alive
        List<Integer> outDeg = new List<Integer>();
        List<Boolean> alive = new List<Boolean>();
        for (Integer i = 0; i < n; i++) { outDeg.add(outDegInit[i]); alive.add(true); }

        // Current leaves by color: FIFO bucket with front pointer
        List<List<Integer>> bucket = new List<List<Integer>>();
        List<Integer> front = new List<Integer>();
        List<Long> score = new List<Long>();
        for (Integer c = 0; c < colorCount; c++) {
            bucket.add(new List<Integer>());
            front.add(0);
            score.add(0L);
        }

        Integer remaining = n;

        // Init leaves (outDeg == 0)
        for (Integer v = 0; v < n; v++) {
            if (outDeg[v] == 0) {
                Integer c = colorId[v];
                bucket[c].add(v);
                score[c] = score[c] + weight[v];
            }
        }

        Integer steps = 0;
        List<Integer> seq = new List<Integer>();

        while (remaining > 0) {
            // pick among top-M colors by score
            Integer M = Math.min(topMChoices, colorCount);
            List<Integer> bestC = new List<Integer>();
            List<Long> bestS = new List<Long>();
            for (Integer i = 0; i < M; i++) { bestC.add(-1); bestS.add(-1L); }

            for (Integer c = 0; c < colorCount; c++) {
                Long sc = score[c];
                if (sc <= 0) continue;
                for (Integer k = 0; k < M; k++) {
                    if (sc > bestS[k]) {
                        for (Integer shift = M - 1; shift > k; shift--) {
                            bestS[shift] = bestS[shift - 1];
                            bestC[shift] = bestC[shift - 1];
                        }
                        bestS[k] = sc;
                        bestC[k] = c;
                        break;
                    }
                }
            }

            if (bestC[0] == -1) {
                // No available leaves -> not a DAG or invalid input
                throw new FL_InvalidGraphException('Cyclic graph detected: no sink nodes available at start.');
            }

            Integer chosenColor;
            if (!randomized || M == 1 || bestC[1] == -1) {
                chosenColor = bestC[0];
            } else {
                Long total = 0L;
                Integer actualM = 0;
                for (Integer k = 0; k < M; k++) {
                    if (bestC[k] == -1) break;
                    total += bestS[k];
                    actualM++;
                }
                Long r = (Long)Math.floor(Math.random() * (Double)total);

                Long acc = 0L;
                chosenColor = bestC[0];
                for (Integer k = 0; k < actualM; k++) {
                    acc += bestS[k];
                    if (r < acc) { chosenColor = bestC[k]; break; }
                }
            }

            seq.add(chosenColor);

            // Delete ALL current leaves of chosenColor (snapshot at step start)
            List<Integer> b = bucket[chosenColor];
            Integer start = front[chosenColor];
            Integer endNumber = b.size();
            for (Integer i = start; i < endNumber; i++) {
                Integer v = b[i];
                if (!alive[v]) continue;

                alive[v] = false;
                remaining--;

                // v was a current leaf of this color
                score[chosenColor] = score[chosenColor] - weight[v];

                // Removing v deletes edges (p -> v) for all parents p, so outDeg[p] decreases
                for (Integer pi = parentsStart[v]; pi < parentsStart[v + 1]; pi++) {
                    Integer p = parent[pi];
                    if (!alive[p]) continue;

                    outDeg[p] = outDeg[p] - 1;
                    if (outDeg[p] == 0) {
                        Integer cp = colorId[p];
                        bucket[cp].add(p);
                        score[cp] = score[cp] + weight[p];
                    }
                }
            }
            front[chosenColor] = endNumber;
            steps++;
        }

        return new RunResult(steps, seq);
    }
}
