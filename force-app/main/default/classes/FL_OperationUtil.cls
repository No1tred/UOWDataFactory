public with sharing class FL_OperationUtil {
    public static final List<FL_Operation> ACTUAL_POSSIBLE_OPERATIONS = new List<FL_Operation>{
            FL_Operation.UPSERT_OP,
            FL_Operation.UNDELETE_OP,
            FL_Operation.DELETE_OP
    };
    public static FL_Operation getPerformedOp(FL_Operation inOperation){
        if(inOperation != FL_Operation.UPDATE_OP && inOperation != FL_Operation.INSERT_OP){
            return inOperation;
        } else {
            return FL_Operation.UPSERT_OP;
        }
    }
}