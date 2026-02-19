public with sharing class FL_RelationShipPointer {
    public final SObjectField field;
    public final FL_SObjectNode targetNode;
    public Boolean isRequired;

    public FL_RelationShipPointer(SObjectField field, FL_SObjectNode targetNode, Boolean isRequired) {
        this.field = field;
        this.targetNode = targetNode;
        this.isRequired = isRequired;
    }



    public Boolean equals(Object o) {
        if (this === o) return true;
        if (!(o instanceof FL_RelationShipPointer)) return false;

        FL_RelationShipPointer that = (FL_RelationShipPointer) o;

        return (((field != null) && System.equals(field, that.field)) || ((that.field != null) && System.equals(that.field, field)) || (field == that.field)) &&
                System.equals(targetNode, that.targetNode) &&
                System.equals(isRequired, that.isRequired);
    }

    public override Integer hashCode() {
        Integer result = field != null ? System.hashCode(field) : 0;
        result = (31 * result) + System.hashCode(targetNode);
        result = (31 * result) + System.hashCode(isRequired);
        return result;
    }
}