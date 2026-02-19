public inherited sharing class FL_UnitOfWorkMultiType extends FL_UnitOfWorkBase {
    public FL_UnitOfWorkMultiType() {
        super();
    }

    public FL_UnitOfWorkMultiType(Map<FL_SObjectNode, Set<FL_RelationShipPointer>> relationShips, Set<FL_SObjectNode> mixedListOfNodes) {
        super(relationShips, mixedListOfNodes);
    }

    protected override FL_UnitOfWorkBase.IResultStore calculateOptimalDMLOrderToPerform() {
        return new ResultStore(calculateOptimalDMLOrderToPerformInternal(), this);
    }

    protected override Integer calcBestScoreForGraph() {
        Integer longestPath = longestPathLowerBound();
        return getMixedListOfNodes().size() * Limits.getLimitDmlStatements() + longestPath * Limits.getLimitDmlRows();
    }

    private Integer longestPathLowerBound() {
        // Build adjacency and indegree for the variant graph
        Map<FL_SObjectNode, List<FL_SObjectNode>> adj = new Map<FL_SObjectNode, List<FL_SObjectNode>>();
        Map<FL_SObjectNode, Integer> indeg = new Map<FL_SObjectNode, Integer>();
        Map<FL_SObjectNode, Integer> dp = new Map<FL_SObjectNode, Integer>();

        // Nodes in this variant:
        List<FL_SObjectNode> nodes = new List<FL_SObjectNode>(getMixedListOfNodes());

        for (FL_SObjectNode n : nodes) {
            adj.put(n, new List<FL_SObjectNode>());
            indeg.put(n, 0);
            dp.put(n, 1); // path length in nodes
        }

        // Edges: source -> target (same direction you use in MultiTypeOpCalculator.Edge)
        for (FL_SObjectNode fromNode : getRelationShips().keySet()) {
            for (FL_RelationShipPointer p : getRelationShips().get(fromNode)) {
                FL_SObjectNode toNode = p.targetNode;
                if (!adj.containsKey(fromNode) || !adj.containsKey(toNode)) continue;
                adj.get(fromNode).add(toNode);
                indeg.put(toNode, indeg.get(toNode) + 1);
            }
        }

        // Kahn topo + DP propagation
        List<FL_SObjectNode> q = new List<FL_SObjectNode>();
        for (FL_SObjectNode n : nodes) {
            if (indeg.get(n) == 0) q.add(n);
        }

        Integer head = 0;
        Integer processed = 0;
        Integer best = 1;

        while (head < q.size()) {
            FL_SObjectNode u = q[head++];
            processed++;

            Integer du = dp.get(u);
            if (du > best) best = du;

            for (FL_SObjectNode v : adj.get(u)) {
                Integer cand = du + 1;
                if (cand > dp.get(v)) dp.put(v, cand);

                Integer newIn = indeg.get(v) - 1;
                indeg.put(v, newIn);
                if (newIn == 0) q.add(v);
            }
        }

        // If not all nodes processed, there is a cycle in this variant
        if (processed != nodes.size()) {
            throw new FL_InvalidGraphException('Cyclic graph detected: no sink nodes available at start.');
        }

        return best;
    }

    private List<FL_MultiTypeOpCalculator.StepResult> calculateOptimalDMLOrderToPerformInternal() {
        List<FL_MultiTypeOpCalculator.Edge> edgeInputs = new List<FL_MultiTypeOpCalculator.Edge>();
        for (FL_SObjectNode fromNode : getRelationShips().keySet()) {
            for (FL_RelationShipPointer pointer : getRelationShips().get(fromNode)) {
                edgeInputs.add(new FL_MultiTypeOpCalculator.Edge(fromNode, pointer.targetNode));
            }
        }
        return FL_MultiTypeOpCalculator.schedule(new List<FL_SObjectNode>(getMixedListOfNodes()), edgeInputs);
    }

    class ResultStore implements FL_UnitOfWorkBase.IResultStore {
        List<FL_MultiTypeOpCalculator.StepResult> stepResults;
        FL_UnitOfWorkMultiType uow;
        Integer score;

        public Integer getScore() { return score; }

        private ResultStore(List<FL_MultiTypeOpCalculator.StepResult> stepResults, FL_UnitOfWorkMultiType uow) {
            this.stepResults = stepResults;
            this.uow = uow;
            score = calculateScore();
        }

        Integer calculateScore() {
            return uow.getMixedListOfNodes().size() * Limits.getLimitDmlStatements() + stepResults.size() * Limits.getLimitDmlRows();
        }

        public void performDMLs(FL_DatabaseWrapper dbWrapper) {
            List<FL_OperationData> dmlOperations = new List<FL_OperationData>();
            for (FL_MultiTypeOpCalculator.StepResult loopStepResult : stepResults) {
                dmlOperations.add(loopStepResult.getOperationData());
            }

            new FL_OperationDataList(dmlOperations, uow.getRelationShips()).performDMLs(dbWrapper);
        }

        private Map<FL_SObjectNode, Set<FL_SObjectNode>> calcSimplifiedRelationships() {
            Map<FL_SObjectNode, Set<FL_SObjectNode>> reversedRelationships = new Map<FL_SObjectNode, Set<FL_SObjectNode>>();
            for (FL_SObjectNode fromNode : uow.getRelationShips().keySet()) {
                reversedRelationships.put(fromNode, new Set<FL_SObjectNode>());
                for (FL_RelationShipPointer loopPointer : (uow.getRelationShips().get(fromNode)) ?? new Set<FL_RelationShipPointer>()) {
                    reversedRelationships.get(fromNode).add(loopPointer.targetNode);
                }
            }
            return reversedRelationships;
        }
    }
}
