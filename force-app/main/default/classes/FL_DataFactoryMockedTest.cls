@IsTest
public with sharing class FL_DataFactoryMockedTest {
    @IsTest static void testFactoryOverloadsAndHooksWithMockedDbWrapper() {
        FL_DatabaseWrapperStubProvider stub = setStubDbWrapper();
        FL_DataFactory.performDML();

        InstrumentedContactFactory factory = new InstrumentedContactFactory();
        List<SObject> records = factory.insertRecords(
                2,
                new Contact(Department = 'ALL_DEPT'),
                new List<SObject>{
                        new Contact(Title = 'TITLE_0'),
                        new Contact(FirstName = 'Specific', Title = 'TITLE_1')
                }
        );

        Assert.areEqual(2, records.size());
        Contact firstRecord = (Contact) records[0];
        Contact secondRecord = (Contact) records[1];
        Assert.areEqual('ALL_DEPT', firstRecord.Department);
        Assert.areEqual('ALL_DEPT', secondRecord.Department);
        Assert.areEqual('Assigned', firstRecord.FirstName);
        Assert.areEqual('Specific', secondRecord.FirstName);
        Assert.areEqual(2, factory.assignCallCount);
        Assert.areEqual(2, factory.lookupCallCount);
        Assert.isTrue(stub.getDmlStatements() > 0);
        Assert.isTrue(stub.getDmlRows() >= 2);
    }

    @IsTest static void testContextAndComposeNodeApis() {
        FL_DatabaseWrapperStubProvider stub = setStubDbWrapper();
        FL_DataFactory.performDML();

        InstrumentedContactFactory factory = new InstrumentedContactFactory();
        FL_DataFactory.UowContext externalContext = FL_DataFactory.newUowContext(new FL_UnitOfWork());
        FL_SObjectNode externalNode = factory.composeNode(new Contact(LastName = 'ExternalNode'), externalContext);
        Assert.isNotNull(externalNode);
        Assert.areEqual(Contact.SObjectType, externalNode.getSObjectType());

        FL_SObjectNode staticNode = factory.composeNode(new Contact(LastName = 'StaticNode'));
        Assert.isNotNull(staticNode);
        Assert.isNotNull(FL_DataFactory.getOrCreateStaticContext());

        FL_DataFactory.performDML(FL_UnitOfWork.Mode.SINGLE_TYPE);
        Assert.isTrue(stub.getDmlStatements() > 0);
    }

    @IsTest static void testWrapperOverloadsCoverage() {
        FL_DatabaseWrapperStubProvider stub = setStubDbWrapper();
        FL_DataFactory.performDML();

        MinimalContactFactory factory = new MinimalContactFactory();
        SObject insertedDefault = factory.insertRecord();
        SObject insertedWithOverride = factory.insertRecord(new Contact(FirstName = 'OverrideFirst'));
        List<SObject> insertedList = factory.insertRecords(2);
        SObject composedDefault = factory.composeRecords();
        SObject composedWithOverride = factory.composeRecords(new Contact(Department = 'FromOverride'));

        Assert.isNotNull(insertedDefault);
        Assert.areEqual('OverrideFirst', ((Contact) insertedWithOverride).FirstName);
        Assert.areEqual(2, insertedList.size());
        Assert.isNotNull(composedDefault);
        Assert.areEqual('FromOverride', ((Contact) composedWithOverride).Department);
        Assert.isTrue(stub.getDmlStatements() >= 3);

        try {
            factory.composeRecords(
                    2,
                    null,
                    new List<SObject>{
                            new Contact(LastName = 'Valid'),
                            new Account(Name = 'InvalidTypeInList')
                    }
            );
            Assert.fail('Expected IllegalArgumentException for mixed override types.');
        } catch (IllegalArgumentException expected) {
            Assert.isTrue(expected.getMessage().contains('Record number and override object list size are not equal'));
        }
    }

    @IsTest static void testPerformDmlMultiTypeAndNoopWhenContextIsNull() {
        FL_DatabaseWrapperStubProvider stub = setStubDbWrapper();
        MinimalContactFactory factory = new MinimalContactFactory();

        factory.composeRecords(2);
        FL_DataFactory.performDML(FL_UnitOfWork.Mode.MULTI_TYPE);
        Integer statementsAfterRun = stub.getDmlStatements();

        FL_DataFactory.performDML(FL_UnitOfWork.Mode.MULTI_TYPE);

        Assert.isTrue(statementsAfterRun > 0);
        Assert.areEqual(statementsAfterRun, stub.getDmlStatements());
    }

    private class InstrumentedContactFactory extends FL_DataFactory {
        public Integer assignCallCount = 0;
        public Integer lookupCallCount = 0;
        private final SharedParentAccountFactory sharedParentFactory = new SharedParentAccountFactory();
        private final IncompatibleLeadFactory incompatibleLeadFactory = new IncompatibleLeadFactory();

        protected override SObject getDefaultRecord(Integer index) {
            return new Contact(
                    LastName = 'Instrumented ' + index,
                    Email = 'instrumented' + index + '@test.com'
            );
        }

        protected override void assignConditionally(SObject sObjectRecord) {
            assignCallCount++;
            Contact contactRecord = (Contact) sObjectRecord;
            if (contactRecord.FirstName == null) {
                contactRecord.FirstName = 'Assigned';
            }
        }

        protected override void addLookups(FL_DataFactory.LookupContext lookupContext) {
            lookupCallCount++;
            Contact contactRecord = (Contact) lookupContext.record();

            contactRecord.AccountId = FL_IdGenerator.generate(Account.SObjectType);
            lookupContext.addMissingRequiredLookup(Contact.AccountId, new Account(Name = 'SkipBecauseAlreadySet'));
            contactRecord.AccountId = null;

            lookupContext.addMissingRequiredLookup(
                    Contact.AccountId,
                    new FL_SObjectNode(new Account(Name = 'ReqNodeParent' + lookupCallCount))
            );
            lookupContext.addMissingRequiredLookup(Contact.ReportsToId, new Contact(LastName = 'ReqRecordParent' + lookupCallCount));

            lookupContext.addMissingOptionalLookup(
                    Contact.ReportsToId,
                    new FL_SObjectNode(new Contact(LastName = 'OptNodeParent' + lookupCallCount))
            );
            lookupContext.addMissingOptionalLookup(Contact.ReportsToId, new Contact(LastName = 'OptRecordParent' + lookupCallCount));

            lookupContext.addMissingLookup(
                    Contact.AccountId,
                    new FL_SObjectNode(new Account(Name = 'DefaultReqNodeParent' + lookupCallCount))
            );
            lookupContext.addMissingLookup(Contact.AccountId, new Account(Name = 'DefaultReqRecordParent' + lookupCallCount));
            lookupContext.addMissingLookup(Contact.AccountId, sharedParentFactory);
            lookupContext.addMissingLookup(Contact.AccountId, sharedParentFactory, ParentMode.SAME_PARENT);

            lookupContext.addMissingLookup(Contact.AccountId, incompatibleLeadFactory, ParentMode.DIFFERENT_PARENT);
        }
    }

    private class SharedParentAccountFactory extends FL_DataFactory {
        protected override SObject getDefaultRecord(Integer index) {
            return new Account(Name = 'Shared Parent ' + index);
        }
    }

    private class MinimalContactFactory extends FL_DataFactory {
        protected override SObject getDefaultRecord(Integer index) {
            return new Contact(LastName = 'Minimal ' + index);
        }
    }

    private class IncompatibleLeadFactory extends FL_DataFactory {
        protected override SObject getDefaultRecord(Integer index) {
            return new Lead(LastName = 'Lead ' + index, Company = 'Comp ' + index);
        }
    }

    private static FL_DatabaseWrapperStubProvider setStubDbWrapper() {
        FL_DatabaseWrapperStubProvider stub = new FL_DatabaseWrapperStubProvider();
        FL_UnitOfWorkBase.dbWrapper = (FL_DatabaseWrapper) Test.createStub(FL_DatabaseWrapper.class, stub);
        return stub;
    }
}
