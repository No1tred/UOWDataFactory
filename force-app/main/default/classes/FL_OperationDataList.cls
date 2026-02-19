public inherited sharing class FL_OperationDataList {
    public final List<FL_OperationData> operations;
    private final Map<FL_SObjectNode, Set<FL_RelationShipPointer>> relationShips;


    public FL_OperationDataList(Map<FL_SObjectNode, Set<FL_RelationShipPointer>> relationShips) {
        this(new List<FL_OperationData>(), relationShips);
    }

    public FL_OperationDataList(List<FL_OperationData> operations,
            Map<FL_SObjectNode, Set<FL_RelationShipPointer>> relationShips) {
        this.operations = operations;
        this.relationShips = relationShips;
    }

    public FL_OperationDataList copy() {
        List<FL_OperationData> copiedOperations = new List<FL_OperationData>();
        for (FL_OperationData loopOperationData : this.operations) {
            copiedOperations.add(loopOperationData.copy());
        }
        return new FL_OperationDataList(copiedOperations, this.relationShips.clone());
    }

    public Integer dmlCount() {
        return operations.size();
    }

    public Integer recordCount() {
        Integer allCount = 0;
        for (FL_OperationData operation : operations) {
            allCount += operation.sobjectNodes.size();
        }
        return allCount;
    }

    public void performDMLs(FL_DatabaseWrapper dbWrapperInst) {
        for (FL_OperationData loopOperation : operations) {
            //TODO check if optional relationships are now ready to be filled
            loopOperation.performDML(relationShips, dbWrapperInst);
        }
    }

    private static SObjectType getsObjectType(FL_OperationData loopOperation) {
        return loopOperation.sobjectNodes.iterator().next().getSObjectType();
    }
}