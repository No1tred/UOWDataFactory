@IsTest private class FL_UnitOfWorkMockedTest {
    private static final String PACC1_NAME = 'pacc1';
    private static final String PACC2_NAME = 'pacc2';
    private static final String CYCLE_EXCEPTION_MESSAGE = 'Cyclic graph detected: no sink nodes available at start.';

    @IsTest static void testCycleOneOptEdgeMultiType() {
        FL_DatabaseWrapperStubProvider dbWrapperStubProvider = setStubDbWrapper();
        FL_UnitOfWork uow = new FL_UnitOfWork();

        Account pacc1 = new Account(Name = PACC1_NAME);
        uow.addSobject(pacc1)
                .childOpt(uow.addSobject(new Account(Name = PACC2_NAME))
                        .child(pacc1));

        uow.performDMLs(FL_UnitOfWork.Mode.MULTI_TYPE);

        Assert.areEqual(3, dbWrapperStubProvider.getDmlStatements());
        Assert.areEqual(3, dbWrapperStubProvider.getDmlRows());
    }

    @IsTest static void testCycleOneOptEdgeSingleType() {
        FL_DatabaseWrapperStubProvider dbWrapperStubProvider = setStubDbWrapper();
        FL_UnitOfWork uow = new FL_UnitOfWork();

        Account pacc1 = new Account(Name = PACC1_NAME);
        uow.addSobject(pacc1)
                .childOpt(uow.addSobject(new Account(Name = PACC2_NAME))
                        .child(pacc1));

        uow.performDMLs(FL_UnitOfWork.Mode.SINGLE_TYPE);

        Assert.areEqual(3, dbWrapperStubProvider.getDmlStatements());
        Assert.areEqual(3, dbWrapperStubProvider.getDmlRows());
    }

    @IsTest static void testCycleEdgesAllOptMultiType() {
        FL_DatabaseWrapperStubProvider dbWrapperStubProvider = setStubDbWrapper();
        FL_UnitOfWork uow = new FL_UnitOfWork();

        Account pacc1 = new Account(Name = PACC1_NAME);
        uow.addSobject(pacc1)
                .childOpt(uow.addSobject(new Account(Name = PACC2_NAME))
                        .childOpt(pacc1));

        uow.performDMLs(FL_UnitOfWork.Mode.MULTI_TYPE);

        Assert.areEqual(2, dbWrapperStubProvider.getDmlStatements());
        Assert.areEqual(4, dbWrapperStubProvider.getDmlRows());
    }

    @IsTest static void testCycleEdgesAllOptSingleType() {
        FL_DatabaseWrapperStubProvider dbWrapperStubProvider = setStubDbWrapper();
        FL_UnitOfWork uow = new FL_UnitOfWork();

        Account pacc1 = new Account(Name = PACC1_NAME);
        uow.addSobject(pacc1)
                .childOpt(uow.addSobject(new Account(Name = PACC2_NAME))
                        .childOpt(pacc1));

        uow.performDMLs(FL_UnitOfWork.Mode.SINGLE_TYPE);

        Assert.areEqual(2, dbWrapperStubProvider.getDmlStatements());
        Assert.areEqual(4, dbWrapperStubProvider.getDmlRows());
    }

    @IsTest static void testComplexHierarchyMixedOperationsMultiType() {
        FL_DatabaseWrapperStubProvider stub = setStubDbWrapper();
        FL_UnitOfWork uow = createComplexHierarchyMixedOperationUow();

        uow.performDMLs(FL_UnitOfWork.Mode.MULTI_TYPE, true);

        assertComplexHierarchyMixedOperationResult(stub, 55);
    }

    @IsTest static void testComplexHierarchyMixedOperationsSingleType() {
        FL_DatabaseWrapperStubProvider stub = setStubDbWrapper();
        FL_UnitOfWork uow = createComplexHierarchyMixedOperationUow();

        uow.performDMLs(FL_UnitOfWork.Mode.SINGLE_TYPE, true);

        assertComplexHierarchyMixedOperationResult(stub, 55);
    }

    @IsTest static void testPerformDmlOverloads() {
        {
            FL_DatabaseWrapperStubProvider stub = setStubDbWrapper();
            FL_UnitOfWork uow = new FL_UnitOfWork();
            uow.addSobject(new Account(Name = 'accA'));
            uow.performDMLs();
            Assert.areEqual(1, stub.getDmlStatements());
        }
        {
            FL_DatabaseWrapperStubProvider stub = setStubDbWrapper();
            FL_UnitOfWork uow = new FL_UnitOfWork();
            uow.addSobject(new Account(Name = 'accB'));
            uow.performDMLs(FL_UnitOfWork.Mode.MULTI_TYPE, true);
            Assert.areEqual(1, stub.getDmlStatements());
        }
        {
            FL_DatabaseWrapperStubProvider stub = setStubDbWrapper();
            FL_UnitOfWork uow = new FL_UnitOfWork();
            uow.addSobject(new Account(Name = 'accC'));
            uow.performDMLs(FL_UnitOfWork.Mode.MULTI_TYPE);
            Assert.areEqual(1, stub.getDmlStatements());
        }
        {
            FL_DatabaseWrapperStubProvider stub = setStubDbWrapper();
            FL_UnitOfWork uow = new FL_UnitOfWork();
            uow.addSobject(new Account(Name = 'accD'));
            uow.performDMLs(FL_UnitOfWork.Mode.SINGLE_TYPE, 100);
            Assert.areEqual(1, stub.getDmlStatements());
        }
        {
            FL_DatabaseWrapperStubProvider stub = setStubDbWrapper();
            FL_UnitOfWork uow = new FL_UnitOfWork();
            uow.addSobject(new Account(Name = 'accE'));
            uow.performDMLs(FL_UnitOfWork.Mode.SINGLE_TYPE, false, 100);
            Assert.areEqual(1, stub.getDmlStatements());
        }
        {
            FL_DatabaseWrapperStubProvider stub = setStubDbWrapper();
            FL_UnitOfWork uow = new FL_UnitOfWork();
            uow.addSobject(new Account(Name = 'accF'));
            uow.performDMLs(100);
            Assert.areEqual(1, stub.getDmlStatements());
        }
        {
            FL_DatabaseWrapperStubProvider stub = setStubDbWrapper();
            FL_UnitOfWork uow = new FL_UnitOfWork();
            uow.addSobject(new Account(Name = 'accG'));
            uow.performDMLs(true, 100);
            Assert.areEqual(1, stub.getDmlStatements());
        }
    }

    @IsTest static void testCycleErrorWithStubMultiType() {
        FL_DatabaseWrapperStubProvider stub = setStubDbWrapper();
        try {
            makeCyclicUow().performDMLs(FL_UnitOfWork.Mode.MULTI_TYPE);
            Assert.fail('Exception should have been thrown');
        } catch (FL_InvalidGraphException cycleExp) {
            Assert.areEqual(CYCLE_EXCEPTION_MESSAGE, cycleExp.getMessage());
            Assert.areEqual(0, stub.getDmlRows());
            Assert.areEqual(0, stub.getDmlStatements());
        }
    }

    @IsTest static void testCycleErrorWithStubSingleType() {
        FL_DatabaseWrapperStubProvider stub = setStubDbWrapper();
        try {
            makeCyclicUow().performDMLs(FL_UnitOfWork.Mode.SINGLE_TYPE);
            Assert.fail('Exception should have been thrown');
        } catch (FL_InvalidGraphException cycleExp) {
            Assert.areEqual(CYCLE_EXCEPTION_MESSAGE, cycleExp.getMessage());
            Assert.areEqual(0, stub.getDmlRows());
            Assert.areEqual(0, stub.getDmlStatements());
        }
    }

    @IsTest static void testDatabaseWrapperPerformAllOperationsWithEmptyLists() {
        FL_DatabaseWrapper wrapper = new FL_DatabaseWrapper();
        List<SObject> empty = new List<SObject>();

        wrapper.perform(empty, FL_Operation.INSERT_OP);
        wrapper.perform(empty, FL_Operation.UPSERT_OP);
        wrapper.perform(empty, FL_Operation.UPDATE_OP);
        wrapper.perform(empty, FL_Operation.DELETE_OP);
        wrapper.perform(empty, FL_Operation.UNDELETE_OP);

        Assert.areEqual(0, empty.size());
    }

    @IsTest static void testDatabaseWrapperStubProviderCloneAndUnknownMethod() {
        FL_DatabaseWrapperStubProvider cloningProvider = new FL_DatabaseWrapperStubProvider(true);
        List<SObject> rows = new List<SObject>{ new Account(Name = 'before_mutation') };

        Object performResult = cloningProvider.handleMethodCall(
                null,
                'perform',
                null,
                null,
                null,
                new List<Object>{ rows, FL_Operation.INSERT_OP }
        );
        Assert.isNull(performResult);
        Assert.isNotNull(rows[0].Id);
        rows[0].put('Name', 'after_mutation');
        Assert.areEqual('before_mutation', (String) cloningProvider.getPerformCalls()[0].sobjects[0].get('Name'));

        cloningProvider.handleMethodCall(
                null,
                'perform',
                null,
                null,
                null,
                new List<Object>{ new List<SObject>(), FL_Operation.UPSERT_OP }
        );
        Assert.areEqual(2, cloningProvider.getDmlStatements());
        Assert.areEqual(1, cloningProvider.getDmlRows());

        Object unknownResult = cloningProvider.handleMethodCall(
                null,
                'otherMethod',
                null,
                null,
                null,
                new List<Object>()
        );
        Assert.isNull(unknownResult);
    }

    @IsTest static void testOperationDataListCountsCopyAndPerform() {
        FL_DatabaseWrapperStubProvider stub = setStubDbWrapper();
        FL_UnitOfWork uow = new FL_UnitOfWork();
        Account parentAcc = new Account(Name = 'parent');
        Account childAcc = new Account(Name = 'child');

        FL_SObjectNode parentNode = new FL_SObjectNode(FL_Operation.INSERT_OP, parentAcc);
        FL_SObjectNode childNode = new FL_SObjectNode(FL_Operation.INSERT_OP, childAcc, true);
        Map<FL_SObjectNode, Set<FL_RelationShipPointer>> relations = new Map<FL_SObjectNode, Set<FL_RelationShipPointer>>();
        relations.put(parentNode, new Set<FL_RelationShipPointer>());
        relations.put(childNode, new Set<FL_RelationShipPointer>{
                new FL_RelationShipPointer(Account.ParentId, parentNode, true)
        });

        FL_OperationData opData = new FL_OperationData(new Set<FL_SObjectNode>{ parentNode, childNode });
        FL_OperationDataList opList = new FL_OperationDataList(new List<FL_OperationData>{ opData }, relations);
        FL_OperationDataList copied = opList.copy();

        Assert.areEqual(1, opList.dmlCount());
        Assert.areEqual(2, opList.recordCount());
        Assert.areEqual(1, copied.dmlCount());
        Assert.areEqual(2, copied.recordCount());

        opList.performDMLs((FL_DatabaseWrapper) Test.createStub(FL_DatabaseWrapper.class, stub));
        Assert.areEqual(1, stub.getDmlStatements());
        Assert.isTrue(stub.getDmlRows() >= 1);
    }

    @IsTest
    static void testAddSobjectOverloadsAndBaseAccessors() {
        FL_UnitOfWork uow = new FL_UnitOfWork();

        Account baseAcc = new Account(Name = 'base');
        FL_UnitOfWork.UnitOfWorkBuilder baseBuilder = uow.addSobject(baseAcc);
        Assert.areEqual(baseAcc, baseBuilder.baseObject());
        Assert.areEqual(baseAcc, baseBuilder.baseNode().instance);

        FL_SObjectNode accNode2 = new FL_SObjectNode(new Account(Name = 'acc2'));
        FL_UnitOfWork.UnitOfWorkBuilder builder2 = uow.addSobject(accNode2);
        Assert.areEqual(accNode2, builder2.baseNode());

        Assert.isTrue(uow.mixedListOfNodes().size() > 0);
    }

    @IsTest
    static void testGetDefaultLookupField() {
        SObjectField defaultContactAccount = FL_UnitOfWork.getDefaultLookupField(Contact.SObjectType, Account.SObjectType);
        Assert.areEqual(Contact.AccountId, defaultContactAccount);
    }

    @IsTest
    static void testAddRelationOverloadsWithDefaultLookup() {
        FL_UnitOfWork uow = new FL_UnitOfWork();

        Contact con1 = new Contact(LastName = 'con1');
        Account acc1 = new Account(Name = 'acc1');
        uow.addOptionalRelation(con1, acc1);
        FL_RelationShipPointer optDefault = findPointerByInstances(uow, con1, acc1);
        Assert.isNotNull(optDefault);
        Assert.isFalse(optDefault.isRequired);
        Assert.isNotNull(optDefault.field);

        Contact con2 = new Contact(LastName = 'con2');
        Account acc2 = new Account(Name = 'acc2');
        uow.addRequiredRelation(con2, acc2);
        FL_RelationShipPointer reqDefault = findPointerByInstances(uow, con2, acc2);
        Assert.isNotNull(reqDefault);
        Assert.isTrue(reqDefault.isRequired);
        Assert.isNotNull(reqDefault.field);

        FL_SObjectNode conNode3 = new FL_SObjectNode(new Contact(LastName = 'con3'));
        FL_SObjectNode accNode3 = new FL_SObjectNode(new Account(Name = 'acc3'));
        uow.addOptionalRelation(conNode3, accNode3);
        FL_RelationShipPointer optDefaultNode = findPointerByNodes(uow, conNode3, accNode3);
        Assert.isNotNull(optDefaultNode);
        Assert.isFalse(optDefaultNode.isRequired);
        Assert.isNotNull(optDefaultNode.field);

        FL_SObjectNode conNode4 = new FL_SObjectNode(new Contact(LastName = 'con4'));
        FL_SObjectNode accNode4 = new FL_SObjectNode(new Account(Name = 'acc4'));
        uow.addRequiredRelation(conNode4, accNode4);
        FL_RelationShipPointer reqDefaultNode = findPointerByNodes(uow, conNode4, accNode4);
        Assert.isNotNull(reqDefaultNode);
        Assert.isTrue(reqDefaultNode.isRequired);
        Assert.isNotNull(reqDefaultNode.field);
    }

    @IsTest
    static void testAddRelationOverloadsWithExplicitField() {
        FL_UnitOfWork uow = new FL_UnitOfWork();

        FL_SObjectNode accFieldSource = new FL_SObjectNode(new Account(Name = 'accFieldSrc'));
        FL_SObjectNode accFieldTarget = new FL_SObjectNode(new Account(Name = 'accFieldTgt'));
        uow.addOptionalRelation(accFieldSource, Account.ParentId, accFieldTarget);
        FL_RelationShipPointer optFieldDirect = findPointerByNodes(uow, accFieldSource, accFieldTarget);
        Assert.isNotNull(optFieldDirect);
        Assert.isFalse(optFieldDirect.isRequired);
        Assert.areEqual(Account.ParentId, optFieldDirect.field);

        FL_SObjectNode accFieldSourceReq = new FL_SObjectNode(new Account(Name = 'accFieldSrcReq'));
        FL_SObjectNode accFieldTargetReq = new FL_SObjectNode(new Account(Name = 'accFieldTgtReq'));
        uow.addRequiredRelation(accFieldSourceReq, Account.ParentId, accFieldTargetReq);
        FL_RelationShipPointer reqFieldDirect = findPointerByNodes(uow, accFieldSourceReq, accFieldTargetReq);
        Assert.isNotNull(reqFieldDirect);
        Assert.isTrue(reqFieldDirect.isRequired);
        Assert.areEqual(Account.ParentId, reqFieldDirect.field);
    }

    @IsTest
    static void testAddRequiredRelationWithoutDefaultOverloads() {
        FL_UnitOfWork uow = new FL_UnitOfWork();

        Account accNoField = new Account(Name = 'accNoField');
        Contact conNoField = new Contact(LastName = 'conNoField');
        uow.addRequiredRelationWithoutDefault(new FL_SObjectNode(conNoField), new FL_SObjectNode(accNoField));
        FL_RelationShipPointer reqNoDefaultNode = findPointerByInstances(uow, conNoField, accNoField);
        Assert.isNotNull(reqNoDefaultNode);
        Assert.isTrue(reqNoDefaultNode.isRequired);
        Assert.isNull(reqNoDefaultNode.field);

        Account accNoField2 = new Account(Name = 'accNoField2');
        Contact conNoField2 = new Contact(LastName = 'conNoField2');
        uow.addRequiredRelationWithoutDefault(conNoField2, new FL_SObjectNode(accNoField2));
        FL_RelationShipPointer reqNoDefaultMixed = findPointerByInstances(uow, conNoField2, accNoField2);
        Assert.isNotNull(reqNoDefaultMixed);
        Assert.isTrue(reqNoDefaultMixed.isRequired);
        Assert.isNull(reqNoDefaultMixed.field);

        Account accNoField3 = new Account(Name = 'accNoField3');
        Contact conNoField3 = new Contact(LastName = 'conNoField3');
        uow.addRequiredRelationWithoutDefault(new FL_SObjectNode(conNoField3), accNoField3);
        FL_RelationShipPointer reqNoDefaultMixed2 = findPointerByInstances(uow, conNoField3, accNoField3);
        Assert.isNotNull(reqNoDefaultMixed2);
        Assert.isTrue(reqNoDefaultMixed2.isRequired);
        Assert.isNull(reqNoDefaultMixed2.field);
    }

    @IsTest
    static void testBuilderOverloadsSmokeCoverage() {
        FL_UnitOfWork uow = new FL_UnitOfWork();
        Account baseAcc = new Account(Name = 'base');
        FL_UnitOfWork.UnitOfWorkBuilder baseBuilder = uow.addSobject(baseAcc);
        FL_UnitOfWork.UnitOfWorkBuilder peerBuilder = uow.addSobject(new Account(Name = 'peer'));

        baseBuilder.parentOpt(peerBuilder);
        baseBuilder.parentOpt(new Account(Name = 'parentOptSobj'));
        baseBuilder.parentOpt(new FL_SObjectNode(new Account(Name = 'parentOptNode')));
        baseBuilder.parentOpt(Account.ParentId, peerBuilder);
        baseBuilder.parentOpt(Account.ParentId, new Account(Name = 'parentOptFieldSobj'));
        baseBuilder.parentOpt(Account.ParentId, new FL_SObjectNode(new Account(Name = 'parentOptFieldNode')));

        baseBuilder.childOpt(peerBuilder);
        baseBuilder.childOpt(new FL_SObjectNode(new Account(Name = 'childOptNode')));
        baseBuilder.childOpt(Account.ParentId, peerBuilder);
        baseBuilder.childOpt(Account.ParentId, new Account(Name = 'childOptFieldSobj'));
        baseBuilder.childOpt(Account.ParentId, new FL_SObjectNode(new Account(Name = 'childOptFieldNode')));
        baseBuilder.childOpt(new Contact(LastName = 'childOptSobj'));

        baseBuilder.child(new Account(Name = 'childSobj'));
        baseBuilder.child(peerBuilder);
        baseBuilder.child(new FL_SObjectNode(new Account(Name = 'childNodeReq')));
        baseBuilder.child(Account.ParentId, peerBuilder);
        baseBuilder.child(Account.ParentId, new Account(Name = 'childFieldSobj'));
        baseBuilder.child(Account.ParentId, new FL_SObjectNode(new Account(Name = 'childFieldNode')));

        baseBuilder.parent(new Account(Name = 'parentSobj'));
        baseBuilder.parent(peerBuilder);
        baseBuilder.parent(new FL_SObjectNode(new Account(Name = 'parentNodeReq')));
        baseBuilder.parent(Account.ParentId, peerBuilder);
        baseBuilder.parent(Account.ParentId, new Account(Name = 'parentFieldSobj'));
        baseBuilder.parent(Account.ParentId, new FL_SObjectNode(new Account(Name = 'parentFieldNode')));

        baseBuilder.then(peerBuilder);
        baseBuilder.then(new FL_SObjectNode(new Account(Name = 'thenNode')));
        baseBuilder.then(new Account(Name = 'thenSobj'));

        baseBuilder.beforeDo(peerBuilder);
        baseBuilder.beforeDo(new FL_SObjectNode(new Account(Name = 'beforeDoNode')));
        baseBuilder.beforeDo(new Account(Name = 'beforeDoSobj'));

        Assert.isTrue(uow.mixedListOfNodes().size() > 1);
        Assert.isTrue(uow.relationShips().size() > 0);
    }

    private static FL_RelationShipPointer findPointerByInstances(
            FL_UnitOfWork uow,
            SObject sourceInstance,
            SObject targetInstance
    ) {
        FL_SObjectNode sourceNode = findNodeByInstance(uow.relationShips().keySet(), sourceInstance);
        if (sourceNode == null) {
            return null;
        }
        for (FL_RelationShipPointer loopPointer : uow.relationShips().get(sourceNode)) {
            if (loopPointer.targetNode.instance == targetInstance) {
                return loopPointer;
            }
        }
        return null;
    }

    private static FL_RelationShipPointer findPointerByNodes(
            FL_UnitOfWork uow,
            FL_SObjectNode sourceNode,
            FL_SObjectNode targetNode
    ) {
        for (FL_RelationShipPointer loopPointer : uow.relationShips().get(sourceNode)) {
            if (loopPointer.targetNode == targetNode) {
                return loopPointer;
            }
        }
        return null;
    }

    private static FL_SObjectNode findNodeByInstance(Set<FL_SObjectNode> nodes, SObject instance) {
        for (FL_SObjectNode loopNode : nodes) {
            if (loopNode.instance == instance) {
                return loopNode;
            }
        }
        return null;
    }

    private static FL_UnitOfWork makeCyclicUow() {
        FL_UnitOfWork uow = new FL_UnitOfWork();
        Account pacc1 = new Account(Name = PACC1_NAME);
        uow.addSobject(pacc1)
                .child(uow.addSobject(new Account(Name = PACC2_NAME))
                        .child(pacc1));
        return uow;
    }

    private static FL_UnitOfWork createComplexHierarchyMixedOperationUow() {
        FL_UnitOfWork uow = new FL_UnitOfWork();

        List<FL_UnitOfWork.UnitOfWorkBuilder> rootAccBuilders = new List<FL_UnitOfWork.UnitOfWorkBuilder>();
        for (Integer rootIndex = 0; rootIndex < 10; rootIndex++) {
            rootAccBuilders.add(
                    uow.addSobject(new FL_SObjectNode(
                            FL_Operation.INSERT_OP,
                            new Account(Name = 'complex_root_' + rootIndex)
                    ))
            );
        }

        List<FL_UnitOfWork.UnitOfWorkBuilder> childAccBuilders = new List<FL_UnitOfWork.UnitOfWorkBuilder>();
        for (Integer parentIndex = 0; parentIndex < rootAccBuilders.size(); parentIndex++) {
            for (Integer childIndex = 0; childIndex < 2; childIndex++) {
                FL_UnitOfWork.UnitOfWorkBuilder childBuilder = uow.addSobject(new FL_SObjectNode(
                        FL_Operation.INSERT_OP,
                        new Account(Name = 'complex_child_' + parentIndex + '_' + childIndex)
                ));
                childBuilder.parent(Account.ParentId, rootAccBuilders[parentIndex]);
                childAccBuilders.add(childBuilder);
            }
        }

        for (Integer cycleIndex = 0; cycleIndex < 5; cycleIndex++) {
            Integer childBuilderIndex = cycleIndex * 2;
            rootAccBuilders[cycleIndex].parentOpt(Account.ParentId, childAccBuilders[childBuilderIndex]);
        }

        List<FL_UnitOfWork.UnitOfWorkBuilder> updateBuilders = new List<FL_UnitOfWork.UnitOfWorkBuilder>();
        for (Integer updateIndex = 0; updateIndex < 10; updateIndex++) {
            Contact updateCon = new Contact(
                    Id = FL_IdGenerator.generate(Contact.SObjectType),
                    LastName = 'complex_update_' + updateIndex
            );
            FL_UnitOfWork.UnitOfWorkBuilder updateBuilder = uow.addSobject(new FL_SObjectNode(FL_Operation.UPDATE_OP, updateCon));
            updateBuilder.parent(Contact.AccountId, childAccBuilders[updateIndex]);
            updateBuilders.add(updateBuilder);
        }

        List<FL_UnitOfWork.UnitOfWorkBuilder> deleteBuilders = new List<FL_UnitOfWork.UnitOfWorkBuilder>();
        for (Integer deleteIndex = 0; deleteIndex < 5; deleteIndex++) {
            Opportunity deleteOpp = new Opportunity(
                    Id = FL_IdGenerator.generate(Opportunity.SObjectType),
                    Name = 'complex_delete_' + deleteIndex,
                    StageName = 'Closed Won',
                    CloseDate = System.today()
            );
            FL_UnitOfWork.UnitOfWorkBuilder deleteBuilder =
                    uow.addSobject(new FL_SObjectNode(FL_Operation.DELETE_OP, deleteOpp));
            deleteBuilder.beforeDo(updateBuilders[deleteIndex]);
            deleteBuilders.add(deleteBuilder);
        }

        for (Integer undeleteIndex = 0; undeleteIndex < 5; undeleteIndex++) {
            Case undeleteCase = new Case(
                    Id = FL_IdGenerator.generate(Case.SObjectType),
                    Subject = 'complex_undelete_' + undeleteIndex
            );
            FL_UnitOfWork.UnitOfWorkBuilder undeleteBuilder =
                    uow.addSobject(new FL_SObjectNode(FL_Operation.UNDELETE_OP, undeleteCase));
            undeleteBuilder.beforeDo(deleteBuilders[undeleteIndex]);
        }

        Assert.areEqual(50, uow.mixedListOfNodes().size());
        return uow;
    }

    private static void assertComplexHierarchyMixedOperationResult(FL_DatabaseWrapperStubProvider stub, Integer expectedRows) {
        Integer upsertRows = 0;
        Integer deleteRows = 0;
        Integer undeleteRows = 0;
        Set<FL_Operation> encounteredOps = new Set<FL_Operation>();

        for (FL_DatabaseWrapperStubProvider.PerformCall loopCall : stub.getPerformCalls()) {
            encounteredOps.add(loopCall.selectedOperation);
            if (loopCall.selectedOperation == FL_Operation.UPSERT_OP) {
                upsertRows += loopCall.sobjects.size();
            } else if (loopCall.selectedOperation == FL_Operation.DELETE_OP) {
                deleteRows += loopCall.sobjects.size();
            } else if (loopCall.selectedOperation == FL_Operation.UNDELETE_OP) {
                undeleteRows += loopCall.sobjects.size();
            }
        }

        assertNotSmallerThan(expectedRows, stub.getDmlRows());
        assertNotSmallerThan(45, upsertRows);
        Assert.areEqual(5, deleteRows);
        Assert.areEqual(5, undeleteRows);
        Assert.isTrue(encounteredOps.contains(FL_Operation.UPSERT_OP));
        Assert.isTrue(encounteredOps.contains(FL_Operation.DELETE_OP));
        Assert.isTrue(encounteredOps.contains(FL_Operation.UNDELETE_OP));
        Assert.isTrue(stub.getDmlStatements() > 0);
    }

    private static void assertNotSmallerThan(Integer max, Integer actual) {
        Assert.isTrue(max >= actual,
                'Expected max (' + max + ') is smaller than actual (' + actual + ')');
    }

    private static FL_DatabaseWrapperStubProvider setStubDbWrapper() {
        FL_DatabaseWrapperStubProvider stub = new FL_DatabaseWrapperStubProvider();
        FL_UnitOfWorkBase.dbWrapper = (FL_DatabaseWrapper) Test.createStub(FL_DatabaseWrapper.class, stub);
        return stub;
    }
}
