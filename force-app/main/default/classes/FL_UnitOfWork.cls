public inherited sharing class FL_UnitOfWork {
    public enum Mode {
        MULTI_TYPE, SINGLE_TYPE
    }

    public static final Map<SObjectType, Map<SObjectType, SObjectField>> cachedDefaultLookups =
            new Map<SObjectType, Map<SObjectType, SObjectField>>();

    private final Map<FL_SObjectNode, Set<FL_RelationShipPointer>> relationShips;
    @TestVisible
    private final Set<FL_SObjectNode> mixedListOfNodes;
    private final List<NodeEntry> nodesByInstance;

    public FL_UnitOfWork() {
        this.relationShips = new Map<FL_SObjectNode, Set<FL_RelationShipPointer>>();
        this.mixedListOfNodes = new Set<FL_SObjectNode>();
        this.nodesByInstance = new List<NodeEntry>();
    }

    private FL_SObjectNode ensureNode(FL_SObjectNode node) {
        if (node == null) {
            return null;
        }

        FL_SObjectNode existingNode = getNodeByInstance(node.instance);
        if (existingNode != null) {
            return existingNode;
        }

        mixedListOfNodes.add(node);
        nodesByInstance.add(new NodeEntry(node.instance, node));
        return node;
    }

    private FL_SObjectNode ensureNode(SObject instance) {
        if (instance == null) {
            return null;
        }

        FL_SObjectNode existingNode = getNodeByInstance(instance);
        if (existingNode != null) {
            return existingNode;
        }

        FL_SObjectNode newNode = new FL_SObjectNode(instance);
        mixedListOfNodes.add(newNode);
        nodesByInstance.add(new NodeEntry(instance, newNode));
        return newNode;
    }

    private FL_SObjectNode getNodeByInstance(SObject instance) {
        if (instance == null) {
            return null;
        }
        for (NodeEntry entry : nodesByInstance) {
            if (entry.instance === instance) {
                return entry.node;
            }
        }
        return null;
    }

    public void registerNode(FL_SObjectNode node) {
        ensureNode(node);
    }

    // Delegate commonly used operations
    public UnitOfWorkBuilder addSobject(SObject sobjectToAdd) {
        FL_SObjectNode nodeToAdd = ensureNode(sobjectToAdd);
        return new UnitOfWorkBuilder(this, nodeToAdd);
    }

    public UnitOfWorkBuilder addSobject(FL_SObjectNode sobjectToAdd) {
        FL_SObjectNode nodeToAdd = ensureNode(sobjectToAdd);
        return new UnitOfWorkBuilder(this, nodeToAdd);
    }

    public void addRequiredRelation(FL_SObjectNode source, SObjectField sObjectField, FL_SObjectNode target) {
        addRelation(source, sObjectField, target, true);
    }

    public void addOptionalRelation(FL_SObjectNode source, SObjectField sObjectField, FL_SObjectNode target) {
        addRelation(source, sObjectField, target, false);
    }

    public void addRequiredRelationWithoutDefault(FL_SObjectNode source, FL_SObjectNode target) {
        addRelation(source, null, target, true);
    }

    public void addRequiredRelationWithoutDefault(SObject source, FL_SObjectNode target) {
        addRelation(ensureNode(source), null, target, true);
    }

    public void addRequiredRelationWithoutDefault(FL_SObjectNode source, SObject target) {
        addRelation(source, null, ensureNode(target), true);
    }

    private void addRelation(FL_SObjectNode source, SObjectField sObjectField, FL_SObjectNode target, Boolean isRequired) {
        FL_SObjectNode sourceNode = ensureNode(source);
        FL_SObjectNode targetNode = ensureNode(target);

        if (sObjectField != null && sourceNode != null && sObjectField.getDescribe().getSObjectType() != sourceNode.getSObjectType()) {
            throw new IllegalArgumentException(sObjectField + ' is not a field of ' + source.getSObjectType());
        }

        if (!relationShips.containsKey(sourceNode)) {
            relationShips.put(sourceNode, new Set<FL_RelationShipPointer>());
        }
        relationShips.get(sourceNode).add(new FL_RelationShipPointer(sObjectField, targetNode, isRequired));
    }

    public void addOptionalRelation(SObject source, SObject target) {
        addOptionalRelation(ensureNode(source), getDefaultLookupField(source.getSObjectType(), target.getSObjectType()), ensureNode(target));
    }

    public void addOptionalRelation(FL_SObjectNode source, FL_SObjectNode target) {
        addOptionalRelation(source, getDefaultLookupField(source.getSObjectType(), target.getSObjectType()), target);
    }

    public void addRequiredRelation(SObject source, SObject target) {
        addRequiredRelation(ensureNode(source), getDefaultLookupField(source.getSObjectType(), target.getSObjectType()), ensureNode(target));
    }

    public void addRequiredRelation(FL_SObjectNode source, FL_SObjectNode target) {
        addRequiredRelation(source, getDefaultLookupField(source.getSObjectType(), target.getSObjectType()), target);
    }

    public static SObjectField getDefaultLookupField(SObjectType fromType, SObjectType toType) {
        SObjectField defaultField = cachedDefaultLookups?.get(fromType)?.get(toType);
        if (defaultField == null) {
            for (SObjectField loopField : fromType.getDescribe().fields.getMap().values()) {
                DescribeFieldResult fieldDescribe = loopField.getDescribe();
                if (isUsable(fieldDescribe, toType) && shouldOverwriteExisting(defaultField, fieldDescribe)) {
                    defaultField = loopField;
                }
            }
            if (defaultField != null) {
                if (!cachedDefaultLookups.containsKey(fromType)) {
                    cachedDefaultLookups.put(fromType, new Map<SObjectType, SObjectField>());
                }
                cachedDefaultLookups.get(fromType).put(toType, defaultField);
            }
        }

        if (defaultField == null) {
            throw new IllegalArgumentException('No lookup/master detail on ' + fromType.getDescribe().getName() + ' pointing to ' + toType.getDescribe().getName());
        }

        return defaultField;
    }

    private static Boolean shouldOverwriteExisting(SObjectField defaultField, DescribeFieldResult fieldDescribe) {
        return defaultField == null ||
                (fieldDescribe.referenceTo.size() == 1 && defaultField.getDescribe().referenceTo.size() >= 2)
                || (fieldDescribe.isCustom() && !defaultField.getDescribe().isCustom());
    }

    private static Boolean isUsable(DescribeFieldResult fieldDescribe, SObjectType toType) {
        return (fieldDescribe.getReferenceTo()?.contains(toType) ?? false) && fieldDescribe.isCreateable();
    }

    public void performDMLs(Integer timeLimitMS) {
        performDMLs(FL_UnitOfWork.Mode.MULTI_TYPE, timeLimitMS);
    }

    public void performDMLs() {
        performDMLs(FL_UnitOfWork.Mode.MULTI_TYPE, false);
    }

    public void performDMLs(FL_UnitOfWork.Mode inMode, Boolean firstIterationOnly) {
        performDMLs(inMode, firstIterationOnly, null);
    }

    public void performDMLs(Mode inMode) {
        performDMLs(inMode, false, null);
    }

    public void performDMLs(Mode inMode, Integer timeLimitMS) {
        performDMLs(inMode, false, timeLimitMS);
    }

    public void performDMLs(Mode inMode, Boolean firstIterationOnly, Integer timeLimitMS) {
        FL_UnitOfWorkBase impl;
        if (inMode == FL_UnitOfWork.Mode.SINGLE_TYPE) {
            impl = new FL_UnitOfWorkSingleType(relationShips, mixedListOfNodes);
        } else {
            impl = new FL_UnitOfWorkMultiType(relationShips, mixedListOfNodes);
        }
        impl.performDMLs(timeLimitMS, firstIterationOnly);
    }

    public void performDMLs(Boolean singleTypePerDmlStatement, Integer timeLimitMS) {
        performDMLs(singleTypePerDmlStatement == true ? FL_UnitOfWork.Mode.SINGLE_TYPE : FL_UnitOfWork.Mode.MULTI_TYPE, timeLimitMS);
    }

    @TestVisible
    public Map<FL_SObjectNode, Set<FL_RelationShipPointer>> relationShips() {
        return relationShips;
    }

    @TestVisible
    public Set<FL_SObjectNode> mixedListOfNodes() {
        return mixedListOfNodes;
    }

    public class UnitOfWorkBuilder {
        private final FL_UnitOfWork unitOfWorkInst;
        private final FL_SObjectNode baseNode;

        public UnitOfWorkBuilder(FL_UnitOfWork unitOfWorkInst, FL_SObjectNode baseNode) {
            this.unitOfWorkInst = unitOfWorkInst;
            this.baseNode = unitOfWorkInst.ensureNode(baseNode);
        }

        public FL_SObjectNode baseNode() {
            return baseNode;
        }

        public SObject baseObject() {
            return baseNode.instance;
        }

        public UnitOfWorkBuilder parentOpt(UnitOfWorkBuilder outBuilder) {
            unitOfWorkInst.addOptionalRelation(this.baseNode, outBuilder.baseNode());
            return this;
        }

        public UnitOfWorkBuilder parentOpt(SObject toSObject) {
            unitOfWorkInst.addOptionalRelation(this.baseNode, unitOfWorkInst.ensureNode(toSObject));
            return this;
        }

        public UnitOfWorkBuilder parentOpt(FL_SObjectNode toNode) {
            unitOfWorkInst.addOptionalRelation(this.baseNode, getDefaultLookupField(this.baseNode.getSObjectType(), toNode.getSObjectType()), toNode);
            return this;
        }

        public UnitOfWorkBuilder parentOpt(SObjectField sObjField, UnitOfWorkBuilder outBuilder) {
            unitOfWorkInst.addOptionalRelation(this.baseNode, sObjField, outBuilder.baseNode());
            return this;
        }

        public UnitOfWorkBuilder parentOpt(SObjectField sObjField, SObject toSObject) {
            unitOfWorkInst.addOptionalRelation(this.baseNode, sObjField, unitOfWorkInst.ensureNode(toSObject));
            return this;
        }

        public UnitOfWorkBuilder parentOpt(SObjectField sObjField, FL_SObjectNode toNode) {
            unitOfWorkInst.addOptionalRelation(this.baseNode, sObjField, toNode);
            return this;
        }

        public UnitOfWorkBuilder childOpt(UnitOfWorkBuilder inBuilder) {
            unitOfWorkInst.addOptionalRelation(inBuilder.baseNode(), this.baseNode);
            return this;
        }

        public UnitOfWorkBuilder childOpt(FL_SObjectNode fromNode) {
            unitOfWorkInst.addOptionalRelation(fromNode, this.baseNode);
            return this;
        }

        public UnitOfWorkBuilder childOpt(SObjectField sObjField, UnitOfWorkBuilder inBuilder) {
            unitOfWorkInst.addOptionalRelation(inBuilder.baseNode(), sObjField, this.baseNode);
            return this;
        }

        public UnitOfWorkBuilder childOpt(SObjectField sObjField, SObject fromSObject) {
            unitOfWorkInst.addOptionalRelation(unitOfWorkInst.ensureNode(fromSObject), sObjField, this.baseNode);
            return this;
        }

        public UnitOfWorkBuilder childOpt(SObjectField sObjField, FL_SObjectNode fromNode) {
            unitOfWorkInst.addOptionalRelation(fromNode, sObjField, this.baseNode);
            return this;
        }

        public UnitOfWorkBuilder child(SObject fromSObject) {
            unitOfWorkInst.addRequiredRelation(unitOfWorkInst.ensureNode(fromSObject), this.baseNode);
            return this;
        }


        public UnitOfWorkBuilder childOpt(SObject fromSObject) {
            unitOfWorkInst.addOptionalRelation(unitOfWorkInst.ensureNode(fromSObject), this.baseNode);
            return this;
        }

        public UnitOfWorkBuilder child(UnitOfWorkBuilder inBuilder) {
            unitOfWorkInst.addRequiredRelation(inBuilder.baseNode(), this.baseNode);
            return this;
        }

        public UnitOfWorkBuilder child(FL_SObjectNode fromNode) {
            unitOfWorkInst.addRequiredRelation(fromNode, this.baseNode);
            return this;
        }


        public UnitOfWorkBuilder then(UnitOfWorkBuilder inBuilder) {
            unitOfWorkInst.addRequiredRelationWithoutDefault(inBuilder.baseNode(), this.baseNode);
            return this;
        }

        public UnitOfWorkBuilder then(FL_SObjectNode fromNode) {
            unitOfWorkInst.addRequiredRelationWithoutDefault(fromNode, this.baseNode);
            return this;
        }

        public UnitOfWorkBuilder then(SObject fromSObject) {
            unitOfWorkInst.addRequiredRelationWithoutDefault(fromSObject, this.baseNode);
            return this;
        }

        public UnitOfWorkBuilder beforeDo(UnitOfWorkBuilder outBuilder) {
            unitOfWorkInst.addRequiredRelationWithoutDefault(this.baseNode, outBuilder.baseNode());
            return this;
        }

        public UnitOfWorkBuilder beforeDo(FL_SObjectNode toNode) {
            unitOfWorkInst.addRequiredRelationWithoutDefault(this.baseNode, toNode);
            return this;
        }

        public UnitOfWorkBuilder beforeDo(SObject toSObject) {
            unitOfWorkInst.addRequiredRelationWithoutDefault(this.baseNode, toSObject);
            return this;
        }

        public UnitOfWorkBuilder child(SObjectField field, UnitOfWorkBuilder inBuilder) {
            unitOfWorkInst.addRequiredRelation(inBuilder.baseNode(), field, this.baseNode);
            return this;
        }

        public UnitOfWorkBuilder child(SObjectField sObjectField, SObject fromSObject) {
            unitOfWorkInst.addRequiredRelation(unitOfWorkInst.ensureNode(fromSObject), sObjectField, this.baseNode);
            return this;
        }

        public UnitOfWorkBuilder child(SObjectField sObjectField, FL_SObjectNode fromNode) {
            unitOfWorkInst.addRequiredRelation(fromNode, sObjectField, this.baseNode);
            return this;
        }

        public UnitOfWorkBuilder parent(SObject toSObject) {
            unitOfWorkInst.addRequiredRelation(this.baseNode, unitOfWorkInst.ensureNode(toSObject));
            return this;
        }

        public UnitOfWorkBuilder parent(UnitOfWorkBuilder outBuilder) {
            unitOfWorkInst.addRequiredRelation(this.baseNode, getDefaultLookupField(this.baseNode.getSObjectType(), outBuilder.baseNode.getSObjectType()), outBuilder.baseNode());
            return this;
        }

        public UnitOfWorkBuilder parent(FL_SObjectNode toNode) {
            unitOfWorkInst.addRequiredRelation(this.baseNode, getDefaultLookupField(this.baseNode.getSObjectType(), toNode.getSObjectType()), toNode);
            return this;
        }

        public UnitOfWorkBuilder parent(SObjectField field, UnitOfWorkBuilder outBuilder) {
            unitOfWorkInst.addRequiredRelation(this.baseNode, field, outBuilder.baseNode());
            return this;
        }

        public UnitOfWorkBuilder parent(SObjectField field, SObject toSObject) {
            unitOfWorkInst.addRequiredRelation(this.baseNode, field, unitOfWorkInst.ensureNode(toSObject));
            return this;
        }

        public UnitOfWorkBuilder parent(SObjectField field, FL_SObjectNode toNode) {
            unitOfWorkInst.addRequiredRelation(this.baseNode, field, toNode);
            return this;
        }
    }

    private class NodeEntry {
        public final SObject instance;
        public final FL_SObjectNode node;

        public NodeEntry(SObject instance, FL_SObjectNode node) {
            this.instance = instance;
            this.node = node;
        }
    }
}
