public with sharing class FL_TypeAndOperation {
    public SObjectType obType;
    public FL_Operation dmlOperation;

    public FL_TypeAndOperation(SObjectType obType, FL_Operation dmlOperation) {
        this.obType = obType;
        this.dmlOperation = FL_OperationUtil.getPerformedOp(dmlOperation);
    }

    public Boolean equals(Object o) {
        if (this === o) return true;
        if (!(o instanceof FL_TypeAndOperation)) return false;

        FL_TypeAndOperation that = (FL_TypeAndOperation) o;

        return System.equals(obType, that.obType) &&
                System.equals(dmlOperation, that.dmlOperation);
    }

    public override Integer hashCode() {
        Integer result = System.hashCode(obType);
        result = (31 * result) + System.hashCode(dmlOperation);
        return result;
    }
}