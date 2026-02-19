public with sharing class FL_OperationData {
    public final Set<FL_SObjectNode> sobjectNodes;

    public FL_OperationData(List<FL_SObjectNode> sobjectNodes) {
        this(new Set<FL_SObjectNode> (sobjectNodes));
    }

    public FL_OperationData(Set<FL_SObjectNode> sobjectNodes) {
        this.sobjectNodes = sobjectNodes;
    }

    public void performDML(Map<FL_SObjectNode, Set<FL_RelationShipPointer>> relationShips, FL_DatabaseWrapper dbWrapperInst) {
        for (FL_SObjectNode loopNode : this.sobjectNodes) {
            if (loopNode.isOptionalLateUpdate) {
                SObject clearedInstance = loopNode.instance.getSObjectType().newSObject();
                clearedInstance.Id = loopNode.instance.Id;
                loopNode.instance = clearedInstance;
            }
        }
        fillIds(relationShips);

        List<SObject> sobjects = buildMergedSObjects(this.sobjectNodes);
        System.debug('performDML before sort: ' + JSON.serialize(sobjects) );
        sobjects.sort();
        dbWrapperInst.perform(sobjects, getDMLOperation());
    }

    public FL_Operation getDMLOperation() {
        if (sobjectNodes.isEmpty()) {
            return null;
        } else {
            FL_Operation operationOfFirstNode = sobjectNodes.iterator().next().plannedOperation;
            if (operationOfFirstNode == FL_Operation.UPDATE_OP || operationOfFirstNode == FL_Operation.INSERT_OP) {
                return FL_Operation.UPSERT_OP;
            } else {
                return operationOfFirstNode;
            }
        }
    }

    private void fillIds(Map<FL_SObjectNode, Set<FL_RelationShipPointer>> relationShips) {
        for (FL_SObjectNode loopNode : this.sobjectNodes) {
            Set<FL_RelationShipPointer> relationsForNode = relationShips.get(loopNode) ?? new Set<FL_RelationShipPointer>();
            for (FL_RelationShipPointer loopPointer : relationsForNode) {
                if (loopPointer.field != null) {
                    Id targetId = loopPointer.targetNode.instance?.Id;
                    if (targetId != null) {
                        loopNode.instance.put(loopPointer.field, targetId);
                    }
                }

            }
        }
    }

    private static List<SObject> buildMergedSObjects(Set<FL_SObjectNode> sobjectNodes) {
        Map<Id, List<SObject>> sobjectsById = collectSobjectListById(sobjectNodes);

        System.debug('before merge: '+ JSON.serialize(sobjectsById.get(null)));
        List<SObject> merged = new List<SObject>();
        for (Id loopId : sobjectsById.keySet()) {
            if (loopId == null || sobjectsById.get(loopId).size() == 1) {
                merged.addAll(sobjectsById.get(loopId));
            } else {
                Map<String, Object> mergedRecord = new Map<String, Object>();
                for (SObject recordToMerge : sobjectsById.get(loopId)) {
                    Map<String, Object> recordAsMap = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(recordToMerge));
                    for (String fieldName : recordAsMap.keySet()) {
                        if (!mergedRecord.containsKey(fieldName)) {
                            mergedRecord.put(fieldName, recordAsMap.get(fieldName));
                        }
                    }
                }
                merged.add((SObject) JSON.deserialize(JSON.serialize(mergedRecord), SObject.class));

            }
        }
        return merged;
    }

    private static Map<Id, List<SObject>> collectSobjectListById(Set<FL_SObjectNode> sobjectNodes) {
        Map<Id, List<SObject>> sobjectsById = new Map<Id, List<SObject>>();

        for (SObject record : collectSobjectAsList(sobjectNodes)) {
            if (!sobjectsById.containsKey(record.Id)) {
                sobjectsById.put(record.Id, new List<SObject>());
            }
            sobjectsById.get(record.Id).add(record);
        }
        return sobjectsById;
    }

    private static List<SObject> collectSobjectAsList(Set<FL_SObjectNode> sobjectNodes) {
        List<SObject> sobjectList = new List<SObject>();
        for (FL_SObjectNode node : sobjectNodes) {
            if(node.getSObjectType() == Task.getSObjectType()){
                System.debug('Task: ' + node.instance);
            }
            sobjectList.add(node.instance);
        }
        return sobjectList;
    }

    public FL_OperationData copy() {
        return new FL_OperationData(sobjectNodes.clone());
    }
}
