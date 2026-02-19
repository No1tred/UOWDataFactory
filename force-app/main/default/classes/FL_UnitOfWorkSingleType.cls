public inherited sharing class FL_UnitOfWorkSingleType extends FL_UnitOfWorkBase {
    public FL_UnitOfWorkSingleType() {
        super();
    }

    public FL_UnitOfWorkSingleType(Map<FL_SObjectNode, Set<FL_RelationShipPointer>> relationShips, Set<FL_SObjectNode> mixedListOfNodes) {
        super(relationShips, mixedListOfNodes);
    }

    protected override FL_UnitOfWorkBase.IResultStore calculateOptimalDMLOrderToPerform() {
        return new ResultStore(calculateOptimalDMLOrderToPerformInternal(), this);
    }

    protected override Integer calcBestScoreForGraph() {
        return estimateLowerBoundScoreFast();
    }

    private Integer estimateLowerBoundScoreFast() {
        List<FL_SingleTypeOpCalculator.EdgeInput> edgeInputs = new List<FL_SingleTypeOpCalculator.EdgeInput>();
        for (FL_SObjectNode fromNode : getRelationShips().keySet()) {
            for (FL_RelationShipPointer pointer : getRelationShips().get(fromNode)) {
                edgeInputs.add(new FL_SingleTypeOpCalculator.EdgeInput(fromNode, pointer.targetNode));
            }
        }

        Integer lbSteps = FL_SingleTypeOpCalculator.lowerBoundStepsLeavesUp(
                new List<FL_SObjectNode>(getMixedListOfNodes()),
                edgeInputs
        );

        return getMixedListOfNodes().size() * Limits.getLimitDmlStatements()
                + lbSteps * Limits.getLimitDmlRows();
    }

    private FL_SingleTypeOpCalculator.Result calculateOptimalDMLOrderToPerformInternal() {
        List<FL_SingleTypeOpCalculator.EdgeInput> edgeInputs = new List<FL_SingleTypeOpCalculator.EdgeInput>();
        for (FL_SObjectNode fromNode : getRelationShips().keySet()) {
            for (FL_RelationShipPointer pointer : getRelationShips().get(fromNode)) {
                edgeInputs.add(new FL_SingleTypeOpCalculator.EdgeInput(fromNode, pointer.targetNode));
            }
        }

        return FL_SingleTypeOpCalculator.solveMultiStartLeavesUp(new List<FL_SObjectNode>(getMixedListOfNodes()), edgeInputs, 30, 3);
    }

    class ResultStore implements FL_UnitOfWorkBase.IResultStore {
        FL_SingleTypeOpCalculator.Result calcResult;
        FL_UnitOfWorkSingleType uow;
        Integer score;

        public Integer getScore() { return score; }

        private ResultStore(FL_SingleTypeOpCalculator.Result calcResult, FL_UnitOfWorkSingleType uow) {
            this.calcResult = calcResult;
            this.uow = uow;
            score = calculateScore();
        }

        Integer calculateScore() {
            return uow.getMixedListOfNodes().size() * Limits.getLimitDmlStatements() + calcResult.bestSteps * Limits.getLimitDmlRows();
        }

        public void performDMLs(FL_DatabaseWrapper dbWrapper) {
            List<FL_OperationData> dmlOperations = new List<FL_OperationData>();
            Map<FL_SObjectNode, Set<FL_SObjectNode>> remainingRelationships = calcSimplifiedRelationships();
            Set<FL_SObjectNode> remainingNodes = uow.getMixedListOfNodes().clone();
            for (FL_TypeAndOperation loopTypeAndOperation : calcResult.bestColorSequence) {
                Set<FL_SObjectNode> currentSObjectNodes = new Set<FL_SObjectNode>();
                for (FL_SObjectNode loopNode : remainingNodes) {
                    Set<FL_SObjectNode> dependentRecords = remainingRelationships.get(loopNode);
                    Boolean isLeafNode = ((dependentRecords)?.isEmpty()) ?? true;
                    if (loopNode.typeAndOperation == loopTypeAndOperation && isLeafNode) {
                        currentSObjectNodes.add(loopNode);
                    }
                }
                dmlOperations.add(new FL_OperationData(currentSObjectNodes));
                remainingNodes.removeAll(currentSObjectNodes);
                for (FL_SObjectNode nodeToRemove : currentSObjectNodes) {
                    remainingRelationships.remove(nodeToRemove);
                }
                for (FL_SObjectNode loopKey : remainingRelationships.keySet()) {
                    remainingRelationships.get(loopKey).removeAll(currentSObjectNodes);
                }
            }
            new FL_OperationDataList(dmlOperations, uow.getRelationShips()).performDMLs(dbWrapper);
        }

        private Map<FL_SObjectNode, Set<FL_SObjectNode>> calcSimplifiedRelationships() {
            Map<FL_SObjectNode, Set<FL_SObjectNode>> reversedRelationships = new Map<FL_SObjectNode, Set<FL_SObjectNode>>();
            for (FL_SObjectNode fromNode : uow.getRelationShips().keySet()) {
                reversedRelationships.put(fromNode, new Set<FL_SObjectNode>());
                for (FL_RelationShipPointer loopPointer : (uow.getRelationShips().get(fromNode))??new Set<FL_RelationShipPointer>()) {
                    reversedRelationships.get(fromNode).add(loopPointer.targetNode);
                }
            }
            return reversedRelationships;
        }
    }
}
