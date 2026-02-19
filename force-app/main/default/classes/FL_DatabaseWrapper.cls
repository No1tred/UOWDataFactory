public with sharing class FL_DatabaseWrapper {
    public void perform(List<SObject> sobjects, FL_Operation selectedOperation) {
        System.debug('perform: ' + selectedOperation+JSON.serialize(sobjects));
        switch on selectedOperation {
            when INSERT_OP {
                upsert sobjects;
            }
            when UPSERT_OP {
                upsert sobjects;
            }
            when UPDATE_OP {
                update sobjects;
            }
            when DELETE_OP {
                delete sobjects;
            }
            when UNDELETE_OP {
                delete sobjects;
            }
        }
    }

}