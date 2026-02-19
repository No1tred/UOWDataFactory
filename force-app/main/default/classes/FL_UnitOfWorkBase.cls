public inherited sharing abstract class FL_UnitOfWorkBase {
    public static final Integer DEFAULT_TIME_LIMIT_MS = 500;

    private Map<FL_SObjectNode, Set<FL_RelationShipPointer>> relationShips;
    @TestVisible
    private Set<FL_SObjectNode> mixedListOfNodes;

    @TestVisible
    private static FL_DatabaseWrapper dbWrapper = new FL_DatabaseWrapper();

    protected FL_UnitOfWorkBase() {
        this.relationShips = new Map<FL_SObjectNode, Set<FL_RelationShipPointer>>();
        this.mixedListOfNodes = new Set<FL_SObjectNode>();
    }

    protected FL_UnitOfWorkBase(Map<FL_SObjectNode, Set<FL_RelationShipPointer>> relationShips, Set<FL_SObjectNode> mixedListOfNodes) {
        this.relationShips = relationShips;
        this.mixedListOfNodes = mixedListOfNodes;
    }

    // Result abstraction so performDMLs can be shared.
    public interface IResultStore {
        void performDMLs(FL_DatabaseWrapper dbWrapper);
        Integer getScore();
    }

    // Implemented differently for Multi vs SingleType
    protected abstract IResultStore calculateOptimalDMLOrderToPerform();
    protected abstract Integer calcBestScoreForGraph();

    @TestVisible
    public Set<FL_SObjectNode> getMixedListOfNodes() {
        return mixedListOfNodes;
    }

    @TestVisible
    public Map<FL_SObjectNode, Set<FL_RelationShipPointer>> getRelationShips() {
        return relationShips;
    }

    public void performDMLs(Integer timeLimitMS) {
        performDMLs(timeLimitMS, false);
    }

    public void performDMLs(Integer timeLimitMS, Boolean runFirstIterationOnly) {
        Datetime beforeCalc = System.now();
        IResultStore operationResultStore = calcOptimalOperationList(timeLimitMS ?? DEFAULT_TIME_LIMIT_MS, runFirstIterationOnly == true);
        Datetime beforeDML = System.now();
        System.debug('Calc time : ' + (beforeDML.getTime() - beforeCalc.getTime()) / 1000.0);
        operationResultStore.performDMLs(dbWrapper);
        Datetime afterDML = System.now();
        System.debug('DML time : ' + (afterDML.getTime() - beforeDML.getTime()) / 1000.0);
    }

    public void performDMLs() {
        performDMLs(null);
    }

    protected IResultStore calcOptimalOperationList(Integer timeLimitMS, Boolean runFirstIterationOnly) {
        CalcBaseData calcBaseData = getCalcBaseData(collectOptionalEdges());

        if (calcBaseData.optionalEdges.isEmpty()) {
            return calculateOptimalDMLOrderToPerform();
        } else {
            IResultStore currentBestResult;
            FL_InvalidGraphException occurredException;

            Integer possibleEdgeCombinations = (1 << calcBaseData.optionalEdges.size());
            Datetime calcStartTime = System.now();

            Integer maxIterations = runFirstIterationOnly == true ? 1 : possibleEdgeCombinations;
            for (Integer index = 0; index < maxIterations; index++) {
                if (runFirstIterationOnly != true
                        && !willBeWithinTimeLimit(calcStartTime, index, timeLimitMS)) {
                    break;
                }
                try {
                    Integer zigZagEdgeCombinationBits = (Math.mod(index, 2) == 0)
                            ? index / 2
                            : possibleEdgeCombinations - ((index - 1) / 2);

                    FL_UnitOfWorkBase loopUOW = newInstanceWithGraphData(
                            cloneRelationships(calcBaseData.relationships),
                            this.mixedListOfNodes.clone()
                    );

                    // apply optional edge combination to loopUOW
                    for (Integer edgeIndex = 0; edgeIndex < calcBaseData.optionalEdges.size(); edgeIndex++) {
                        GraphEdge optionalEdge = calcBaseData.optionalEdges[edgeIndex];
                        if (isSelectedBitOne(zigZagEdgeCombinationBits, edgeIndex)) {
                            makeEdgeRequired(loopUOW, optionalEdge);
                        } else {
                            insertWithoutLookupAndUpdateLater(loopUOW, optionalEdge);
                        }
                    }

                    if (currentBestResult != null && loopUOW.calcBestScoreForGraph() >= currentBestResult.getScore()) {
                        continue;
                    }

                    IResultStore loopResultStore = loopUOW.calculateOptimalDMLOrderToPerform();

                    if (currentBestResult == null || currentBestResult.getScore() > loopResultStore.getScore()) {
                        currentBestResult = loopResultStore;
                    }
                } catch (FL_InvalidGraphException graphException) {
                    occurredException = graphException;
                }
                System.debug('Edge combination index:' + index);
            }
            if (currentBestResult == null && occurredException != null) {
                throw occurredException;
            }
            return currentBestResult;
        }
    }

    private CalcBaseData getCalcBaseData(Set<GraphEdge> optionalEdges) {
        Set<GraphEdge> edgesToMakeRequired = collectOptionalEdgesFromRootNodes(optionalEdges);
        Map<FL_SObjectNode, Set<FL_RelationShipPointer>> relationshipsToMakeRequired = new Map<FL_SObjectNode, Set<FL_RelationShipPointer>>();
        for (GraphEdge loopEdge : edgesToMakeRequired) {
            if (!relationshipsToMakeRequired.containsKey(loopEdge.source)) {
                relationshipsToMakeRequired.put(loopEdge.source, new Set<FL_RelationShipPointer>());
            }
            relationshipsToMakeRequired.get(loopEdge.source).add(loopEdge.pointer);
        }

        Map<FL_SObjectNode, Set<FL_RelationShipPointer>> recalculatedRelationships = new Map<FL_SObjectNode, Set<FL_RelationShipPointer>>();
        for (FL_SObjectNode sourceNode : relationShips.keySet()) {
            recalculatedRelationships.put(sourceNode, new Set<FL_RelationShipPointer>());
            Set<FL_RelationShipPointer> pointers = relationShips.get(sourceNode);

            for (FL_RelationShipPointer loopPointer : pointers) {
                if (relationshipsToMakeRequired.get(sourceNode)?.contains(loopPointer) ?? false) {
                    recalculatedRelationships.get(sourceNode).add(new FL_RelationShipPointer(loopPointer.field, loopPointer.targetNode, true));
                } else {
                    recalculatedRelationships.get(sourceNode).add(loopPointer);
                }
            }
        }
        optionalEdges.removeAll(edgesToMakeRequired);

        return new CalcBaseData(recalculatedRelationships, optionalEdges);
    }

    private Set<GraphEdge> collectOptionalEdgesFromRootNodes(Set<GraphEdge> optionalEdges) {
        Set<FL_SObjectNode> allTargetNodes = new Set<FL_SObjectNode>();
        for (Set<FL_RelationShipPointer> loopPointers : this.relationShips.values()) {
            for (FL_RelationShipPointer loopPointer : loopPointers) {
                allTargetNodes.add(loopPointer.targetNode);
            }
        }

        Set<GraphEdge> edgesToRemove = new Set<GraphEdge>();
        for (GraphEdge loopEdge : optionalEdges) {
            if (!allTargetNodes.contains(loopEdge.source)) {
                edgesToRemove.add(loopEdge);
            }
        }
        return edgesToRemove;
    }

    private Boolean willBeWithinTimeLimit(Datetime calcStartTime, Integer edgeCombinationIndex, Integer timeLimitMS) {
        if (edgeCombinationIndex == 0) {
            return true;
        } else {
            Long elapsedRunTime = (System.now().getTime() - calcStartTime.getTime());
            Long averageRunTime = elapsedRunTime / edgeCombinationIndex;
            Long estimatedElapsedTimeForNextRun = averageRunTime * (1 + edgeCombinationIndex);
            return estimatedElapsedTimeForNextRun <= timeLimitMS;
        }
    }

    private void insertWithoutLookupAndUpdateLater(FL_UnitOfWorkBase loopUOW, GraphEdge optionalEdge) {
        FL_SObjectNode updateNode = new FL_SObjectNode(FL_Operation.UPDATE_OP, optionalEdge.source.instance, true);
        loopUOW.addRelationInternal(updateNode, null, optionalEdge.source, true);
        loopUOW.addRelationInternal(updateNode, optionalEdge.pointer.field, optionalEdge.pointer.targetNode, true);
        loopUOW.relationShips.get(optionalEdge.source).remove(optionalEdge.pointer);
    }

    private void makeEdgeRequired(FL_UnitOfWorkBase loopUOW, GraphEdge optionalEdge) {
        loopUOW.relationShips.get(optionalEdge.source).add(new FL_RelationShipPointer(optionalEdge.pointer.field, optionalEdge.pointer.targetNode, true));
        loopUOW.relationShips.get(optionalEdge.source).remove(optionalEdge.pointer);
    }

    private Boolean isSelectedBitOne(Integer checkedNumber, Integer loopBit) {
        return (checkedNumber & (1 << loopBit)) != 0;
    }

    private Map<FL_SObjectNode, Set<FL_RelationShipPointer>> cloneRelationships(Map<FL_SObjectNode, Set<FL_RelationShipPointer>> relationshipsToClone) {
        Map<FL_SObjectNode, Set<FL_RelationShipPointer>> clonedRelationships = new Map<FL_SObjectNode, Set<FL_RelationShipPointer>>();
        for (FL_SObjectNode loopNode : relationshipsToClone.keySet()) {
            clonedRelationships.put(loopNode, relationshipsToClone.get(loopNode).clone());
        }
        return clonedRelationships;
    }

    private Set<GraphEdge> collectOptionalEdges() {
        Set<GraphEdge> optionalEdges = new Set<FL_UnitOfWorkBase.GraphEdge>();
        for (FL_SObjectNode source : relationShips.keySet()) {
            for (FL_RelationShipPointer pointer : relationShips.get(source)) {
                if (!pointer.isRequired) {
                    optionalEdges.add(new GraphEdge(source, pointer));
                }
            }
        }
        return optionalEdges;
    }

    private void ensureNodeInternal(FL_SObjectNode node) {
        if (node != null) {
            mixedListOfNodes.add(node);
        }
    }

    private void addRelationInternal(FL_SObjectNode source, SObjectField sObjectField, FL_SObjectNode target, Boolean isRequired) {
        ensureNodeInternal(source);
        ensureNodeInternal(target);

        if (!relationShips.containsKey(source)) {
            relationShips.put(source, new Set<FL_RelationShipPointer>());
        }
        relationShips.get(source).add(new FL_RelationShipPointer(sObjectField, target, isRequired));
    }

    private FL_UnitOfWorkBase newInstanceWithGraphData(
            Map<FL_SObjectNode, Set<FL_RelationShipPointer>> relationships,
            Set<FL_SObjectNode> nodes
    ) {
        if (this instanceof FL_UnitOfWorkSingleType) {
            return new FL_UnitOfWorkSingleType(relationships, nodes);
        }
        return new FL_UnitOfWorkMultiType(relationships, nodes);
    }

    private class GraphEdge {
        private FL_SObjectNode source;
        private FL_RelationShipPointer pointer;

        private GraphEdge(FL_SObjectNode source, FL_RelationShipPointer pointer) {
            this.source = source;
            this.pointer = pointer;
        }
    }

    private class CalcBaseData {
        private Map<FL_SObjectNode, Set<FL_RelationShipPointer>> relationships;
        private List<GraphEdge> optionalEdges;

        private CalcBaseData(Map<FL_SObjectNode, Set<FL_RelationShipPointer>> relationships, Set<GraphEdge> optionalEdges) {
            this.relationships = relationships;
            this.optionalEdges = new List<GraphEdge>(optionalEdges);
        }
    }
}
