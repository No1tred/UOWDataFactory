public class FL_DatabaseWrapperStubProvider implements System.StubProvider {
    private final Boolean shouldClonePassedSobjects;


    public class PerformCall {
        public List<SObject> sobjects;
        public FL_Operation selectedOperation;

        public PerformCall(List<SObject> sobjects, FL_Operation selectedOperation) {
            this.sobjects = sobjects;
            this.selectedOperation = selectedOperation;
        }
    }


    private List<PerformCall> performCalls = new List<PerformCall>();

    public FL_DatabaseWrapperStubProvider() {
        this(false);
    }

    public FL_DatabaseWrapperStubProvider(Boolean shouldClonePassedSobjects) {
        this.shouldClonePassedSobjects = shouldClonePassedSobjects;
    }

    public Integer getDmlStatements() {
        return performCalls.size();
    }

    public Integer getDmlRows() {
        Integer dmlRows = 0;
        for (PerformCall loopPerformCall : performCalls) {
            dmlRows += loopPerformCall.sobjects.size();
        }
        return dmlRows;
    }

    public List<PerformCall> getPerformCalls() {
        return performCalls;
    }

    public Object handleMethodCall(
            Object stubbedObject,
            String methodName,
            Type returnType,
            List<Type> paramTypes,
            List<String> paramNames,
            List<Object> paramValues
    ) {
        if (methodName == 'perform') {

            List<SObject> sobjects = (List<SObject>) paramValues[0];
            FL_Operation selectedOperation = (FL_Operation) paramValues[1];

            if (selectedOperation == FL_Operation.INSERT_OP || selectedOperation == FL_Operation.UPSERT_OP) {
                for (SObject sobjectRecord : sobjects) {
                    if (sobjectRecord != null && sobjectRecord.Id == null) {
                        sobjectRecord.Id = FL_IdGenerator.generate(sobjectRecord.getSObjectType());
                    }
                }
            }

            if (shouldClonePassedSobjects) {
                performCalls.add(new PerformCall(cloneSObjects(sobjects), selectedOperation));
            } else {

                performCalls.add(new PerformCall(sobjects, selectedOperation));

            }
            return null;
        }

        return null;
    }

    private static List<SObject> cloneSObjects(List<SObject> source) {
        List<SObject> cloned = new List<SObject>();
        if (source == null) return cloned;
        for (SObject sobjectRecord : source) {
            if (sobjectRecord == null) {
                cloned.add(null);
            } else {
                cloned.add(sobjectRecord.clone(true, true, true, true));
            }
        }
        return cloned;
    }
}
