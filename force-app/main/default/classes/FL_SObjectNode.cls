public with sharing class FL_SObjectNode {
    private Integer hashCode;
    public final FL_Operation plannedOperation;
    public SObject instance;
    final Map<SObjectField, Object> additionalFieldsToUpdate = new Map<SObjectField, Object>();

    private static Map<SObjectType, Integer> countBySobject = new Map<SObjectType, Integer>();
    private final Integer instanceId;
    public final FL_TypeAndOperation typeAndOperation;
    public final Boolean isOptionalLateUpdate;


    public SObjectType getSObjectType() {
        return instance.getSObjectType();
    }

    public FL_SObjectNode(SObject instance) {
        this(FL_Operation.UPSERT_OP, instance);
    }
    public FL_SObjectNode(FL_Operation plannedOperation, SObject instance) {
        this(plannedOperation, instance, false);
    }

    public FL_SObjectNode(FL_Operation plannedOperation, SObject instance, Boolean isOptionalLateUpdate) {
        this.plannedOperation = plannedOperation;
        this.instance = instance;
        this.isOptionalLateUpdate = isOptionalLateUpdate;

        if (!countBySobject.containsKey(instance.getSObjectType())) {
            this.instanceId = 0;
            countBySobject.put(instance.getSObjectType(), 0);
        } else {
            Integer lastCount = countBySobject.get(instance.getSObjectType());
            countBySobject.put(instance.getSObjectType(), lastCount + 1);
            this.instanceId = lastCount + 1;
        }

        this.typeAndOperation = new FL_TypeAndOperation(instance.getSObjectType(), plannedOperation);
    }

    public FL_Operation getPerformedOperation() {
        return FL_OperationUtil.getPerformedOp(plannedOperation);
    }

    public Boolean equals(Object o) {
        if (this === o) return true;
        if (!(o instanceof FL_SObjectNode)) return false;

        FL_SObjectNode that = (FL_SObjectNode) o;

        return System.equals(plannedOperation, that.plannedOperation) &&
                (instance === that.instance) &&
                (((instanceId != null) && System.equals(instanceId, that.instanceId)) || ((that.instanceId != null) && System.equals(that.instanceId, instanceId)) || (instanceId == that.instanceId));
    }

    public override Integer hashCode() {
        if (this.hashCode == null) {
            this.hashCode = System.hashCode(plannedOperation);
            hashCode = (31 * hashCode) + System.hashCode(instance);
            hashCode = (31 * hashCode) + (instanceId != null ? System.hashCode(instanceId) : 0);
        }

        return this.hashCode;
    }

    public override String toString() {
        return 'SObjectNode:{' +
                'plannedOperation=' + plannedOperation +
                ', instance=' + instance +
                ', additionalFieldsToUpdate=' + additionalFieldsToUpdate +
                ', updateId=' + instanceId +
                '}';
    }
}
