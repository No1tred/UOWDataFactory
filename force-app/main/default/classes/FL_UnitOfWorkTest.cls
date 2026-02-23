@IsTest private class FL_UnitOfWorkTest {
    private static final String CON1V2_LAST_NAME = 'con1_2';
    private static final String ACC1V1_NAME = 'acc1_1';
    private static final String ACC1V3_NAME = 'acc1_3';
    private static final String ACC1V2_NAME = 'acc1_2';
    private static final String CON1V1_LAST_NAME = 'con1_1';
    private static final String MC1_1_LAST_NAME = 'mc1_1';
    private static final String PACC1_NAME = 'pacc1';
    private static final String PACC2_NAME = 'pacc2';
    private static final String CON2V1_LAST_NAME = 'con2_1';
    private static final String ACC2V1_NAME = 'acc2_1';
    private static final String MC2V1_LAST_NAME = 'mc2_1';
    private static final String CON2V2_LAST_NAME = 'con2_2';
    private static final String ACC2V2_NAME = 'acc2_2';
    private static final String OPP2V1_NAME = 'opp2_1';
    private static final String OPP1V1_NAME = 'opp1_1';

    private static final FL_UnitOfWork SAMPLE_UOW = createTestUow();

    private static final String CYCLE_EXCEPTION_MESSAGE = 'Cyclic graph detected: no sink nodes available at start.';

    @IsTest static void testDAGFirstIterationMultiType() {
        //WHEN
        SAMPLE_UOW.performDMLs(FL_UnitOfWork.Mode.MULTI_TYPE, true);

        //THEN
        assertRecordsAndRelations();
        Assert.areEqual(3, Limits.getDmlStatements());
        Assert.areEqual(6, Limits.getDmlRows() - SAMPLE_UOW.mixedListOfNodes().size());
    }

    @IsTest static void testDAGFirstIterationSingleType() {
        //WHEN
        SAMPLE_UOW.performDMLs(FL_UnitOfWork.Mode.SINGLE_TYPE, true);

        //THEN
        assertRecordsAndRelations();
        Assert.areEqual(5, Limits.getDmlStatements());
        Assert.areEqual(6, Limits.getDmlRows() - SAMPLE_UOW.mixedListOfNodes().size());
    }

    @IsTest static void testDAGSmallTimeMultiType() {
        //WHEN
        SAMPLE_UOW.performDMLs(FL_UnitOfWork.Mode.MULTI_TYPE, 200);

        //THEN
        assertRecordsAndRelations();
        Assert.areEqual(3, Limits.getDmlStatements());
        assertNotSmallerThan(6, Limits.getDmlRows() - SAMPLE_UOW.mixedListOfNodes().size());
    }

    @IsTest static void testDAGSmallTimeSingleType() {
        SAMPLE_UOW.performDMLs(FL_UnitOfWork.Mode.SINGLE_TYPE, 200);

        assertRecordsAndRelations();
        Assert.areEqual(5, Limits.getDmlStatements());
        assertNotSmallerThan(6, Limits.getDmlRows() - SAMPLE_UOW.mixedListOfNodes().size());
    }

    @IsTest static void testDAGLotOfTimeMultiType() {
        //WHEN
        SAMPLE_UOW.performDMLs(FL_UnitOfWork.Mode.MULTI_TYPE, 8000);

        //THEN
        assertRecordsAndRelations();
        Assert.areEqual(3, Limits.getDmlStatements());
        Assert.areEqual(2, Limits.getDmlRows() - SAMPLE_UOW.mixedListOfNodes().size());
    }


    @IsTest static void testDAGLotOfTimeSingleType() {
        SAMPLE_UOW.performDMLs(FL_UnitOfWork.Mode.SINGLE_TYPE, 8000);

        assertRecordsAndRelations();
        Assert.areEqual(5, Limits.getDmlStatements());
        Assert.areEqual(1, Limits.getDmlRows() - SAMPLE_UOW.mixedListOfNodes().size());
    }

    @IsTest static void testDAGAllRequiredMultiType() {
        //WHEN
        makeAllEdgesRequired(SAMPLE_UOW).performDMLs(FL_UnitOfWork.Mode.MULTI_TYPE);

        //THEN
        assertRecordsAndRelations();
        Assert.areEqual(5, Limits.getDmlStatements());
        Assert.areEqual(SAMPLE_UOW.mixedListOfNodes().size(), Limits.getDmlRows());
    }

    @IsTest static void testDAGAllRequiredSingleType() {
        //WHEN
        makeAllEdgesRequired(SAMPLE_UOW).performDMLs(FL_UnitOfWork.Mode.SINGLE_TYPE);

        //THEN
        assertRecordsAndRelations();

        Assert.areEqual(6, Limits.getDmlStatements());
        Assert.areEqual(SAMPLE_UOW.mixedListOfNodes().size(), Limits.getDmlRows());
    }

    @IsTest static void testCycleErrorMultiType() {
        try {
            makeCyclicUOW().performDMLs(FL_UnitOfWork.Mode.MULTI_TYPE);
            Assert.fail('Exception should have been thrown');
        } catch (FL_InvalidGraphException cycleExp) {
            Assert.areEqual(CYCLE_EXCEPTION_MESSAGE, cycleExp.getMessage());
            Assert.areEqual(0, Limits.getDmlRows());
            Assert.areEqual(0, Limits.getDmlStatements());
        }
    }

    @IsTest static void testCycleErrorSingleType() {
        try {
            makeCyclicUOW().performDMLs(FL_UnitOfWork.Mode.SINGLE_TYPE);
            Assert.fail('Exception should have been thrown');
        } catch (FL_InvalidGraphException cycleExp) {
            Assert.areEqual(CYCLE_EXCEPTION_MESSAGE, cycleExp.getMessage());
            Assert.areEqual(0, Limits.getDmlRows());
            Assert.areEqual(0, Limits.getDmlStatements());
        }
    }

    @IsTest static void testCycleOneOptEdgeMultiType() {
        FL_DatabaseWrapperStubProvider dbWrapperStubProvider = new FL_DatabaseWrapperStubProvider();
        FL_UnitOfWorkBase.dbWrapper =
                (FL_DatabaseWrapper) Test.createStub(FL_DatabaseWrapper.class, dbWrapperStubProvider);
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
        FL_DatabaseWrapperStubProvider dbWrapperStubProvider = new FL_DatabaseWrapperStubProvider();
        FL_UnitOfWorkBase.dbWrapper =
                (FL_DatabaseWrapper) Test.createStub(FL_DatabaseWrapper.class, dbWrapperStubProvider);
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
        FL_DatabaseWrapperStubProvider dbWrapperStubProvider = new FL_DatabaseWrapperStubProvider();
        FL_UnitOfWorkBase.dbWrapper =
                (FL_DatabaseWrapper) Test.createStub(FL_DatabaseWrapper.class, dbWrapperStubProvider);
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
        FL_DatabaseWrapperStubProvider dbWrapperStubProvider = new FL_DatabaseWrapperStubProvider();
        FL_UnitOfWorkBase.dbWrapper =
                (FL_DatabaseWrapper) Test.createStub(FL_DatabaseWrapper.class, dbWrapperStubProvider);
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



    private static void assertNotSmallerThan(Integer max, Integer actual) {
        Assert.isTrue(max >= actual,
                'Expected max (' + max + ') is smaller than actual (' + actual + ')');
    }

    private static FL_UnitOfWork makeCyclicUOW() {
        FL_UnitOfWork uow = new FL_UnitOfWork();
        Account pacc1 = new Account(Name = PACC1_NAME);
        uow.addSobject(pacc1)
                .child(uow.addSobject(new Account(Name = PACC2_NAME))
                        .child(pacc1));
        return uow;
    }

    private static void assertRecordsAndRelations() {
        Map<String, Account> accByName = new Map<String, Account>();
        for (Account loopAccount : [SELECT Name, Parent.Name FROM Account]) {
            accByName.put(loopAccount.Name, loopAccount);
        }

        Map<Id, Contact> contactsById = new Map<Id, Contact>([SELECT LastName, Account.Name, ReportsTo.LastName FROM Contact]);
        Map<String, Contact> contactByLastName = new Map<String, Contact>();
        for (Contact loopContact : contactsById.values()) {
            contactByLastName.put(loopContact.LastName, loopContact);
        }

        Map<String, Opportunity> oppByName = new Map<String, Opportunity>();
        for (Opportunity loopOppty : [SELECT Name, Account.Name, ContactId FROM Opportunity]) {
            oppByName.put(loopOppty.Name, loopOppty);
        }

        Assert.areEqual(ACC1V1_NAME, accByName.get(ACC1V3_NAME).Parent.Name);
        Assert.areEqual(PACC1_NAME, accByName.get(ACC1V1_NAME).Parent.Name);
        Assert.areEqual(PACC1_NAME, accByName.get(ACC1V2_NAME).Parent.Name);
        Assert.areEqual(PACC2_NAME, accByName.get(ACC2V1_NAME).Parent.Name);
        Assert.areEqual(PACC2_NAME, accByName.get(ACC2V2_NAME).Parent.Name);

        Assert.areEqual(ACC1V2_NAME, contactByLastName.get(CON1V1_LAST_NAME).Account.Name);
        Assert.areEqual(ACC1V2_NAME, contactByLastName.get(CON1V2_LAST_NAME).Account.Name);
        Assert.areEqual(MC1_1_LAST_NAME, contactByLastName.get(CON1V2_LAST_NAME).ReportsTo.LastName);
        Assert.areEqual(PACC2_NAME, contactByLastName.get(CON2V1_LAST_NAME).Account.Name);
        Assert.areEqual(ACC2V1_NAME, contactByLastName.get(MC2V1_LAST_NAME).Account.Name);
        Assert.areEqual(MC2V1_LAST_NAME, contactByLastName.get(CON2V2_LAST_NAME).ReportsTo.LastName);

        Assert.areEqual(CON1V1_LAST_NAME, contactsById.get(oppByName.get(OPP1V1_NAME).ContactId).LastName);
        Assert.areEqual(ACC1V1_NAME, oppByName.get(OPP1V1_NAME).Account.Name);

        Assert.areEqual(CON2V2_LAST_NAME, contactsById.get(oppByName.get(OPP2V1_NAME).ContactId).LastName);
        Assert.areEqual(ACC2V2_NAME, oppByName.get(OPP2V1_NAME).Account.Name);
    }

    private static FL_UnitOfWork createTestUow() {
        FL_UnitOfWork uow = new FL_UnitOfWork();

        Opportunity opp1v1 = (Opportunity) uow.addSobject(new Opportunity(Name = OPP1V1_NAME, StageName = 'New', CloseDate = System.today())).baseObject();
        Opportunity opp2v1 = (Opportunity) uow.addSobject(new Opportunity(Name = OPP2V1_NAME, StageName = 'New', CloseDate = System.today())).baseObject();
        Contact con1v2 = (Contact) uow.addSobject(new Contact(LastName = CON1V2_LAST_NAME)).baseObject();


        uow.addSobject(new Account(Name = PACC1_NAME))
                .childOpt(uow.addSobject(new Account(Name = ACC1V1_NAME))
                        .child(new Account(Name = ACC1V3_NAME))
                        .child(opp1v1))
                .childOpt(uow.addSobject(new Account(Name = ACC1V2_NAME))
                        .child(con1v2)
                        .childOpt(uow.addSobject(new Contact(LastName = CON1V1_LAST_NAME))
                                .childOpt(opp1v1)))
                .child(uow.addSobject(new Contact(LastName = MC1_1_LAST_NAME))
                        .child(Contact.ReportsToId, con1v2));

        uow.addSobject(new Account(Name = PACC2_NAME))
                .child(new Contact(LastName = CON2V1_LAST_NAME))
                .childOpt(uow.addSobject(new Account(Name = ACC2V1_NAME))
                        .childOpt(uow.addSobject(new Contact(LastName = MC2V1_LAST_NAME))
                                .child(uow.addSobject(new Contact(LastName = CON2V2_LAST_NAME))
                                        .child(opp2v1))))
                .childOpt(uow.addSobject(new Account(Name = ACC2V2_NAME))
                        .child(opp2v1));
        return uow;
    }

    private static FL_UnitOfWork makeAllEdgesRequired(FL_UnitOfWork uow) {
        for (Set<FL_RelationShipPointer> nodeRelationships : uow.relationShips().values()) {
            for (FL_RelationShipPointer relationShipPointer : nodeRelationships) {
                relationShipPointer.isRequired = true;
            }
        }
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

        // Create resolvable cycles: child -> root is required, root -> child is optional.
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

        assertNotSmallerThan(expectedRows , stub.getDmlRows());
        assertNotSmallerThan(45, upsertRows);
        Assert.areEqual(5, deleteRows);
        Assert.areEqual(5, undeleteRows);
        Assert.isTrue(encounteredOps.contains(FL_Operation.UPSERT_OP));
        Assert.isTrue(encounteredOps.contains(FL_Operation.DELETE_OP));
        Assert.isTrue(encounteredOps.contains(FL_Operation.UNDELETE_OP));
        Assert.isTrue(stub.getDmlStatements() > 0);
    }

    private static FL_DatabaseWrapperStubProvider setStubDbWrapper() {
        FL_DatabaseWrapperStubProvider stub = new FL_DatabaseWrapperStubProvider();
        FL_UnitOfWorkBase.dbWrapper =
                (FL_DatabaseWrapper)Test.createStub(FL_DatabaseWrapper.class, stub);
        return stub;
    }

}
