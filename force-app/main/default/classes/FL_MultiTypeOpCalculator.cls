public with sharing class FL_MultiTypeOpCalculator {
    private static final Integer MAX_TYPES_PER_DML_STATEMENT = 10;
    private static final Integer MAX_NUM_OF_DIFF_TPYES = Limits.getLimitDmlStatements() * MAX_TYPES_PER_DML_STATEMENT;
    private static final List<FL_Operation> OPERATIONS = FL_OperationUtil.ACTUAL_POSSIBLE_OPERATIONS;
    private static final Integer OPERATION_TYPE_SIZES = OPERATIONS.size();
    public class Edge {
        public FL_SObjectNode fromNode;
        public FL_SObjectNode toNode;
        public Edge(FL_SObjectNode fromNode, FL_SObjectNode toNode) {
            this.fromNode = fromNode;
            this.toNode = toNode;
        }
    }

    // Output: list of steps, each step = family + chosen shades + removed node ids
    public class StepResult {
        public Integer stepIndex;
        public FL_Operation operation;
        public List<SObjectType> sObjTypes;
        public List<FL_SObjectNode> sobjectNodes;

        public StepResult(Integer stepIndex, FL_Operation operation, List<SObjectType> sObjTypes, List<FL_SObjectNode> sobjectNodes) {
            this.stepIndex = stepIndex;
            this.operation = operation;
            this.sObjTypes = sObjTypes;
            this.sobjectNodes = sobjectNodes;
        }
        public FL_OperationData getOperationData() {
            return new FL_OperationData(this.sobjectNodes);
        }
    }

    // --- Main entry point ---
    public static List<StepResult> schedule(
            List<FL_SObjectNode> nodes,
            List<Edge> edges
    ) {
        if (nodes == null || nodes.isEmpty()) return new List<StepResult>();

        Set<FL_SObjectNode> nodeSet = new Set<FL_SObjectNode>(nodes);


        List<Map<SObjectType, Integer>> sObjTypeToIdx = new List<Map<SObjectType, Integer>>();
        List<List<SObjectType>> idxToSObjType = new List<List<SObjectType>>();
        for (Integer f = 0; f < OPERATION_TYPE_SIZES; f++) {
            sObjTypeToIdx.add(new Map<SObjectType, Integer>());
            idxToSObjType.add(new List<SObjectType>());
        }
        Map<FL_SObjectNode, Integer> sobjTypeIdxByNode = new Map<FL_SObjectNode, Integer>();
        for (FL_SObjectNode loopNode : nodes) {
            Integer operationIndex = operationToIndex(loopNode.getPerformedOperation());
            if (operationIndex < 0) continue;
            if (loopNode.getSObjectType() == null) throw new IllegalArgumentException('Node ' + loopNode + ' has null shade.');
            Map<SObjectType, Integer> sobjTypeMapForOperation = sObjTypeToIdx[operationIndex];
            if (!sobjTypeMapForOperation.containsKey(loopNode.getSObjectType())) {
                Integer nextIdx = idxToSObjType[operationIndex].size();
                if (nextIdx >= MAX_NUM_OF_DIFF_TPYES) {
                    throw new IllegalArgumentException('Operation ' + loopNode.getPerformedOperation() + ' has more than ' + MAX_NUM_OF_DIFF_TPYES + ' distinct SObject Tpyes.');
                }
                sobjTypeMapForOperation.put(loopNode.getSObjectType(), nextIdx);
                idxToSObjType[operationIndex].add(loopNode.getSObjectType());
            }
            sobjTypeIdxByNode.put(loopNode, sobjTypeMapForOperation.get(loopNode.getSObjectType()));
        }

// Reverse adjacency: predecessorsByNode[v] = list of predecessors u where u -> v
        Map<FL_SObjectNode, List<FL_SObjectNode>> predecessorsByNode = new Map<FL_SObjectNode, List<FL_SObjectNode>>();
        // Outdegree: number of outgoing edges from node in remaining graph
        Map<FL_SObjectNode, Integer> outDegreByNode = new Map<FL_SObjectNode, Integer>();

        for (FL_SObjectNode loopNode : nodes) {
            predecessorsByNode.put(loopNode, new List<FL_SObjectNode>());
            outDegreByNode.put(loopNode, 0);
        }

        // Build graph
        for (Edge e : edges) {
            if (!nodeSet.contains(e.fromNode) || !nodeSet.contains(e.toNode)) continue;

            predecessorsByNode.get(e.toNode).add(e.fromNode);
            outDegreByNode.put(e.fromNode, outDegreByNode.get(e.fromNode) + 1);
        }

        // State flags
        Set<FL_SObjectNode> removed = new Set<FL_SObjectNode>();

        // Buckets: familyIndex(0..2) -> shade(0..99) -> stack of nodeIds
        // We'll use List<String> as a stack (push=add, pop=remove(size-1)).
        List<List<List<FL_SObjectNode>>> bucket = initBuckets(idxToSObjType);
        List<List<Integer>> cnt = initCounts(idxToSObjType); // cnt[familyIdx][shade] = available sink count

        // Initialize sinks
        Integer remaining = nodes.size();
        Integer initialSinkCount = 0;
        for (FL_SObjectNode loopNode : nodes) {
            if (outDegreByNode.get(loopNode) == 0) {
                Integer fIdx = operationToIndex(loopNode.getPerformedOperation());
                if (fIdx < 0) continue;
                Integer typeIdx = sobjTypeIdxByNode.get(loopNode);
                bucket[fIdx][typeIdx].add(loopNode);
                cnt[fIdx][typeIdx]++;
                initialSinkCount++;
            }
        }

        // In a DAG, if there are remaining nodes, there must be at least one sink at the start.
        if (remaining > 0 && initialSinkCount == 0) {
            throw new FL_InvalidGraphException('Cyclic graph detected: no sink nodes available at start.');
        }
        List<StepResult> results = new List<StepResult>();
        Integer step = 0;
        FL_Operation lastFamily = null;

        while (remaining > 0) {
            // Pick best family by current top-10 shade counts
            FamilyChoice choice = chooseFamilyAndShades(cnt);

            Integer fIdx = choice.familyIdx;
            FL_Operation fam = indexToFamily(fIdx);
            List<Integer> chosenShades = choice.shades;

            List<FL_SObjectNode> removedThisStep = new List<FL_SObjectNode>();
            PendingAdd pending = new PendingAdd();

// Remove ONLY nodes that were sinks at the start of the step, i.e. from bucketCur.
// Any newly created sinks go into pending (bucketNext) and are merged after the step.
            for (Integer shade : chosenShades) {
                // Snapshot how many eligible sinks of this shade exist at step start.
                Integer toRemove = cnt[fIdx][shade];
                if (toRemove == null || toRemove <= 0) continue;

                List<FL_SObjectNode> stack = bucket[fIdx][shade];

                // We will attempt to remove exactly 'toRemove' valid sinks from the current bucket snapshot.
                // Because of lazy/stale entries, we may need to pop more than toRemove times.
                Integer removedCountForShade = 0;

                while (removedCountForShade < toRemove && !stack.isEmpty()) {
                    FL_SObjectNode removedNode = stack.remove(stack.size() - 1);

                    // Lazy skip stale entries (already removed, or not actually sink anymore)
                    if (removed.contains(removedNode)) continue;
                    Integer od = outDegreByNode.get(removedNode);
                    if (od == null || od != 0) continue;

                    // Remove removedNode (it is a sink from the step-start population)
                    removed.add(removedNode);
                    remaining--;
                    removedThisStep.add(removedNode);

                    // Decrement current sink count for this shade
                    cnt[fIdx][shade] = cnt[fIdx][shade] - 1;
                    removedCountForShade++;

                    // Update predecessors; newly created sinks go to pending (NEXT step)
                    List<FL_SObjectNode> pList = predecessorsByNode.get(removedNode);
                    if (pList != null) {
                        for (FL_SObjectNode predecessor : pList) {
                            if (removed.contains(predecessor)) continue;

                            Integer newOutDegree = outDegreByNode.get(predecessor) - 1;
                            outDegreByNode.put(predecessor, newOutDegree);

                            if (newOutDegree == 0) {
                                Integer operationIndex = operationToIndex(predecessor.getPerformedOperation());
                                Integer sObjTypeIndex = sobjTypeIdxByNode.get(predecessor);

                                pending.add(operationIndex, sObjTypeIndex, predecessor);
                            }
                        }
                    }
                }

                // Note: If stack ran out early due to stale entries, we simply remove fewer nodes of that shade.
                // That should be rare if buckets only contain sinks from previous step merges.
            }

// Merge newly unlocked sinks into current buckets/counts for the next step
            pending.mergeInto(bucket, cnt);

            if (removedThisStep.isEmpty()) {
                // No sinks removed while nodes remain => cycle or inconsistent graph state.
                throw new FL_InvalidGraphException('Cyclic graph detected: no sink nodes available during scheduling step ' + step + '.');
            }

            results.add(new StepResult(step, fam, sobjTypIdxListToNames(idxToSObjType[fIdx], chosenShades), removedThisStep));
            lastFamily = fam;
            step++;
        }

        return results;
    }

    // --- Internal helpers ---

    private class FamilyChoice {
        public Integer familyIdx;
        public List<Integer> shades;
        public Integer totalScore;
        public FamilyChoice(Integer idx, List<Integer> sh, Integer score) {
            familyIdx = idx; shades = sh; totalScore = score;
        }
    }

    private static FamilyChoice chooseFamilyAndShades(List<List<Integer>> cnt) {
        Integer bestIdx = 0;
        Integer bestScore = -1;
        List<Integer> bestShades = new List<Integer>();

        for (Integer f = 0; f < OPERATION_TYPE_SIZES; f++) {
            List<Integer> topTypes = topKShades(cnt[f], MAX_TYPES_PER_DML_STATEMENT);
            Integer score = 0;
            for (Integer s : topTypes) score += cnt[f][s];

            if (score > bestScore) {
                bestScore = score;
                bestIdx = f;
                bestShades = topTypes;
            }
        }

        return new FamilyChoice(bestIdx, bestShades, bestScore);
    }


    private static List<Integer> topKShades(List<Integer> counts, Integer k) {
        Integer n = (counts == null) ? 0 : counts.size();
        if (n == 0 || k == null || k <= 0) return new List<Integer>();

        // We only ever have 1500 shades, but handle any n safely
        Set<Integer> picked = new Set<Integer>();
        List<Integer> result = new List<Integer>();

        Integer minLimit = Math.min(k, n);

        for (Integer i = 0; i < minLimit; i++) {
            Integer bestShade = -1;
            Integer bestCount = 0;

            for (Integer s = 0; s < n; s++) {
                if (picked.contains(s)) continue;
                Integer c = counts[s];
                if (c == null) c = 0;

                if (c > bestCount) {
                    bestCount = c;
                    bestShade = s;
                }
            }

            // No more positive-count shades
            if (bestShade == -1 || bestCount <= 0) break;

            picked.add(bestShade);
            result.add(bestShade);
        }

        return result;
    }


    private static List<SObjectType> sobjTypIdxListToNames(List<SObjectType> idxToShade, List<Integer> typeIndexes) {
        List<SObjectType> names = new List<SObjectType>();
        if (typeIndexes == null) return names;
        for (Integer loopIndex : typeIndexes) {
            if (loopIndex == null) continue;
            if (loopIndex >= 0 && loopIndex < idxToShade.size()) names.add(idxToShade[loopIndex]);
        }
        return names;
    }

    private static Integer operationToIndex(FL_Operation operation) {
        return OPERATIONS.indexOf(operation);
    }

    private static FL_Operation indexToFamily(Integer idx) {
        return OPERATIONS[idx];
    }

    private static List<List<List<FL_SObjectNode>>> initBuckets(List<List<SObjectType>> idxToSObjType) {
        // bucket[family][shadeIdx] = stack of nodeIds (only allocate for actually-used shades)
        List<List<List<FL_SObjectNode>>> bucket = new List<List<List<FL_SObjectNode>>>();
        for (Integer operationIndex = 0; operationIndex < OPERATION_TYPE_SIZES; operationIndex++) {
            Integer sObjTypeCount = (idxToSObjType != null && idxToSObjType.size() > operationIndex) ? idxToSObjType[operationIndex].size() : 0;
            List<List<FL_SObjectNode>> list2DForOperation = new List<List<FL_SObjectNode>>();
            for (Integer s = 0; s < sObjTypeCount; s++) {
                list2DForOperation.add(new List<FL_SObjectNode>());
            }
            bucket.add(list2DForOperation);
        }
        return bucket;
    }

    private static List<List<Integer>> initCounts(List<List<SObjectType>> idxToSObjType) {
        // cnt[family][shadeIdx] = number of available sink nodes for that shade (only allocate for actually-used shades)
        List<List<Integer>> cnt = new List<List<Integer>>();
        for (Integer f = 0; f < OPERATION_TYPE_SIZES; f++) {
            Integer sObjTypeCount = (idxToSObjType != null && idxToSObjType.size() > f) ? idxToSObjType[f].size() : 0;
            List<Integer> innerList = new List<Integer>();
            for (Integer s = 0; s < sObjTypeCount; s++) innerList.add(0);
            cnt.add(innerList);
        }
        return cnt;
    }

    private class PendingAdd {
        // key = fIdx * SHADE_LIMIT + shade
        public Map<Integer, List<FL_SObjectNode>> bucketNext = new Map<Integer, List<FL_SObjectNode>>();
        public Map<Integer, Integer> cntNext = new Map<Integer, Integer>();

        public void add(Integer operationIndex, Integer sobjTypeIndex, FL_SObjectNode nodeId) {
            Integer key = operationIndex * MAX_NUM_OF_DIFF_TPYES + sobjTypeIndex;
            if (!bucketNext.containsKey(key)) bucketNext.put(key, new List<FL_SObjectNode>());
            bucketNext.get(key).add(nodeId);

            Integer cur = cntNext.containsKey(key) ? cntNext.get(key) : 0;
            cntNext.put(key, cur + 1);
        }

        public void mergeInto(List<List<List<FL_SObjectNode>>> bucketCur, List<List<Integer>> cntCur) {
            for (Integer key : bucketNext.keySet()) {
                Integer fIdx = key / MAX_NUM_OF_DIFF_TPYES;
                Integer shade = Math.mod(key, MAX_NUM_OF_DIFF_TPYES);

                bucketCur[fIdx][shade].addAll(bucketNext.get(key));
                cntCur[fIdx][shade] = cntCur[fIdx][shade] + cntNext.get(key);
            }
        }
    }
}
