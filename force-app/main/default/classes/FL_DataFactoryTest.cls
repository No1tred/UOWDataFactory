@IsTest
public with sharing class FL_DataFactoryTest {
    @IsTest static void testComplexGraphInsertMultiMode() {
        new TaskDataFactory().composeRecords(3);
        Assert.areEqual(3, getCountOfAType(Task.SObjectType));
        new CaseDataFactory().composeRecords(2);
        new OpportunityDataFactory().composeRecords(2);
        new LeadDataFactory().composeRecords(2);
        FL_DataFactory.performDML(FL_UnitOfWork.Mode.MULTI_TYPE);
        assertComplexGraphCreated();
    }

    @IsTest static void testComplexGraphInsertSingleMode() {
        new TaskDataFactory().composeRecords(3);
        Assert.areEqual(3, getCountOfAType(Task.SObjectType));
        new CaseDataFactory().composeRecords(2);
        new OpportunityDataFactory().composeRecords(2);
        new LeadDataFactory().composeRecords(2);
        FL_DataFactory.performDML(FL_UnitOfWork.Mode.SINGLE_TYPE);
        assertComplexGraphCreated();
    }

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

    @IsTest static void testComposeRecordsValidationErrors() {
        InstrumentedContactFactory factory = new InstrumentedContactFactory();

        try {
            factory.composeRecords(0);
            Assert.fail('Expected IllegalArgumentException for invalid record count.');
        } catch (IllegalArgumentException expected) {
            Assert.isTrue(expected.getMessage().contains('Record number and override object list size are not equal'));
        }

        try {
            factory.composeRecords(2, null, new List<SObject>{new Contact(LastName = 'OnlyOne')});
            Assert.fail('Expected IllegalArgumentException for size mismatch.');
        } catch (IllegalArgumentException expected) {
            Assert.isTrue(expected.getMessage().contains('Record number and override object list size are not equal'));
        }

        try {
            factory.composeRecords(1, new Account(Name = 'WrongType'), null);
            Assert.fail('Expected IllegalArgumentException for wrong override type.');
        } catch (IllegalArgumentException expected) {
            Assert.isTrue(expected.getMessage().contains('Record number and override object list size are not equal'));
        }
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

    @IsTest static void testAssignConditionallySupportsTypeAndRecordTypeBranching() {
        RecordTypeAwareAccountFactory factory = new RecordTypeAwareAccountFactory();

        Account defaultRecord = (Account) factory.composeRecords(1)[0];
        Assert.areEqual('TYPE_ACCOUNT_DEFAULT_BRANCH', defaultRecord.Industry);
        Assert.areEqual('DEFAULT', defaultRecord.Type);

        // In orgs where Account.RecordTypeId is unavailable, Name acts as a test marker
        // to emulate a record-type-specific branch.
        Account overrideValues = new Account(Name = 'RT_BRANCH_MARKER');
        Account recordTypeSpecificRecord = (Account) factory.composeRecords(1, overrideValues, null)[0];
        Assert.areEqual('TYPE_ACCOUNT_RECORDTYPE_BRANCH', recordTypeSpecificRecord.Industry);
        Assert.areEqual('RECORD_TYPE_SPECIFIC', recordTypeSpecificRecord.Type);
    }


    private static Integer getCountOfAType(SObjectType sObjectType) {
        List<FL_SObjectNode> taskNodes = new List<FL_SObjectNode>();
        for (FL_SObjectNode loopNode : FL_DataFactory.STATIC_CONTEXT.uow.mixedListOfNodes) {
            if (loopNode.getSObjectType() == sObjectType) {
                taskNodes.add(loopNode);
            }
        }
        Integer countOfAType = taskNodes.size();
        return countOfAType;
    }

    private static void assertComplexGraphCreated() {
        Assert.areEqual(3, [SELECT COUNT() FROM Task], 'Unexpected task count.');
        Assert.areEqual(4, [SELECT COUNT() FROM Case], 'Unexpected case count.');
        Assert.areEqual(3, [SELECT COUNT() FROM Opportunity], 'Unexpected opportunity count.');
        Assert.areEqual(2, [SELECT COUNT() FROM Lead], 'Unexpected lead count.');
        Assert.areEqual(7, [SELECT COUNT() FROM Contact], 'Unexpected contact count.');
        Assert.areEqual(14, [SELECT COUNT() FROM Account], 'Unexpected account count.');

        List<Task> tasks = [
                SELECT Subject, WhatId, WhoId
                FROM Task
        ];
        Set<Id> taskWhatIds = new Set<Id>();
        Set<Id> taskWhoIds = new Set<Id>();
        Integer caseFollowupCount = 0;
        Integer oppFollowupCount = 0;
        for (Task taskRecord : tasks) {
            Assert.isNotNull(taskRecord.WhatId, 'Task should have WhatId.');
            Assert.isNotNull(taskRecord.WhoId, 'Task should have WhoId.');
            taskWhatIds.add(taskRecord.WhatId);
            taskWhoIds.add(taskRecord.WhoId);
            if (taskRecord.Subject == 'Case Followup') {
                caseFollowupCount++;
            } else if (taskRecord.Subject == 'Opportunity Followup') {
                oppFollowupCount++;
            }
        }

        Integer caseWhatCount = [SELECT COUNT() FROM Case WHERE Id IN :taskWhatIds];
        Integer oppWhatCount = [SELECT COUNT() FROM Opportunity WHERE Id IN :taskWhatIds];
        Assert.areEqual(caseFollowupCount, caseWhatCount, 'Case Followup tasks should point to Case.');
        Assert.areEqual(oppFollowupCount, oppWhatCount, 'Opportunity Followup tasks should point to Opportunity.');
        Assert.areEqual(3, [SELECT COUNT() FROM Contact WHERE Id IN :taskWhoIds], 'All task WhoId should be Contact.');

        List<Case> cases = [
                SELECT Priority, AccountId, ContactId
                FROM Case
        ];
        Set<Id> caseAccountIds = new Set<Id>();
        Set<Id> caseContactIds = new Set<Id>();
        for (Case caseRecord : cases) {
            Assert.isNotNull(caseRecord.AccountId, 'Case should have AccountId.');
            Assert.isNotNull(caseRecord.ContactId, 'Case should have ContactId.');
            caseAccountIds.add(caseRecord.AccountId);
            caseContactIds.add(caseRecord.ContactId);
        }
        List<Account> caseAccounts = [
                SELECT Id, Name
                FROM Account
                WHERE Id IN :caseAccountIds
        ];
        Map<Id, Account> caseAccountById = new Map<Id, Account>(caseAccounts);
        for (Case caseRecord : cases) {
            Account acc = caseAccountById.get(caseRecord.AccountId);
            Assert.isNotNull(acc, 'Case account should exist.');
            if (caseRecord.Priority == 'High') {
                Assert.isTrue(acc.Name.startsWith('Enterprise '), 'High priority case should use Enterprise account.');
            } else if (caseRecord.Priority == 'Low') {
                Assert.isTrue(acc.Name.startsWith('SMB '), 'Low priority case should use SMB account.');
            }
        }
        Assert.areEqual(4, [SELECT COUNT() FROM Contact WHERE Id IN :caseContactIds], 'Cases should have 4 distinct contacts.');

        List<Opportunity> opps = [
                SELECT Amount, AccountId
                FROM Opportunity
        ];
        Set<Id> oppAccountIds = new Set<Id>();
        for (Opportunity oppRecord : opps) {
            Assert.isNotNull(oppRecord.AccountId, 'Opportunity should have AccountId.');
            oppAccountIds.add(oppRecord.AccountId);
        }
        List<Account> oppAccounts = [
                SELECT Id, Name
                FROM Account
                WHERE Id IN :oppAccountIds
        ];
        Map<Id, Account> oppAccountById = new Map<Id, Account>(oppAccounts);
        for (Opportunity oppRecord : opps) {
            Account acc = oppAccountById.get(oppRecord.AccountId);
            Assert.isNotNull(acc, 'Opportunity account should exist.');
            if (oppRecord.Amount > 100000) {
                Assert.isTrue(acc.Name.startsWith('Enterprise '), 'High amount opportunity should use Enterprise account.');
            } else {
                Assert.isTrue(acc.Name.startsWith('SMB '), 'Low amount opportunity should use SMB account.');
            }
        }
    }

    private class EnterpriseAccountDataFactory extends FL_DataFactory {
        protected override SObject getDefaultRecord(Integer index) {
            Account accountRecord = new Account();
            accountRecord.Name = 'Enterprise ' + index + ' Account';
            accountRecord.BillingCity = 'City ' + index;
            accountRecord.BillingStreet = '100 Enterprise Way ' + index;
            accountRecord.BillingState = 'CA';
            accountRecord.BillingPostalCode = '9000' + index;
            accountRecord.BillingCountry = 'US';
            accountRecord.AnnualRevenue = 500000 + (index * 10000);
            return accountRecord;
        }
    }

    private class SmbAccountDataFactory extends FL_DataFactory {
        protected override SObject getDefaultRecord(Integer index) {
            Account accountRecord = new Account();
            accountRecord.Name = 'SMB ' + index + ' Account';
            accountRecord.BillingCity = 'Town ' + index;
            accountRecord.BillingStreet = '10 Main St ' + index;
            accountRecord.BillingState = 'TX';
            accountRecord.BillingPostalCode = '7500' + index;
            accountRecord.BillingCountry = 'US';
            accountRecord.AnnualRevenue = 25000 + (index * 1000);
            return accountRecord;
        }
    }

    private class OpportunityDataFactory extends FL_DataFactory {
        private final EnterpriseAccountDataFactory enterpriseAccountFactory = new EnterpriseAccountDataFactory();
        private final SmbAccountDataFactory smbAccountFactory = new SmbAccountDataFactory();

        protected override SObject getDefaultRecord(Integer index) {
            Opportunity oppRecord = new Opportunity();
            oppRecord.Name = 'Opp ' + index;
            oppRecord.StageName = 'Prospecting';
            oppRecord.CloseDate = Date.today().addDays(30 + index);
            oppRecord.Amount = (Math.mod(index, 2) == 0) ? 150000 : 15000;
            return oppRecord;
        }

        protected override void addLookups(FL_DataFactory.LookupContext lookupContext) {
            Opportunity oppRecord = (Opportunity) lookupContext.record();
            if (oppRecord.Amount > 100000) {
                lookupContext.addMissingLookup(Opportunity.AccountId, enterpriseAccountFactory, ParentMode.SAME_PARENT);
            } else {
                lookupContext.addMissingLookup(Opportunity.AccountId, smbAccountFactory);
            }
        }
    }

    private class CaseDataFactory extends FL_DataFactory {
        private final EnterpriseAccountDataFactory enterpriseAccountFactory = new EnterpriseAccountDataFactory();
        private final SmbAccountDataFactory smbAccountFactory = new SmbAccountDataFactory();
        private final ContactDataFactory2 contactDataFactory = new ContactDataFactory2();

        protected override SObject getDefaultRecord(Integer index) {
            Case caseRecord = new Case();
            caseRecord.Subject = 'Case ' + index;
            caseRecord.Status = 'New';
            caseRecord.Origin = 'Phone';
            caseRecord.Priority = (Math.mod(index, 2) == 0) ? 'High' : 'Low';
            return caseRecord;
        }

        protected override void addLookups(FL_DataFactory.LookupContext lookupContext) {
            Case caseRecord = (Case) lookupContext.record();


            if (caseRecord.Priority == 'High') {
                lookupContext.addMissingLookup(Case.AccountId, enterpriseAccountFactory, ParentMode.SAME_PARENT);
            } else {
                lookupContext.addMissingLookup(Case.AccountId, smbAccountFactory);
            }


            lookupContext.addMissingLookup(Case.ContactId, contactDataFactory);

        }
    }

    private class LeadDataFactory extends FL_DataFactory {
        protected override SObject getDefaultRecord(Integer index) {
            Lead leadRecord = new Lead();
            leadRecord.LastName = 'Lead ' + index;
            leadRecord.Company = 'Company ' + index;
            leadRecord.Status = 'Open - Not Contacted';
            return leadRecord;
        }
    }

    private class TaskDataFactory extends FL_DataFactory {
        private final CaseDataFactory caseDataFactory = new CaseDataFactory();
        private final OpportunityDataFactory opportunityDataFactory = new OpportunityDataFactory();
        private final ContactDataFactory2 contactDataFactory = new ContactDataFactory2();

        protected override SObject getDefaultRecord(Integer index) {
            Task taskRecord = new Task();
            taskRecord.Subject = (Math.mod(index, 2) == 0) ? 'Case Followup' : 'Opportunity Followup';
            taskRecord.Status = 'Not Started';
            return taskRecord;
        }

        protected override void addLookups(FL_DataFactory.LookupContext lookupContext) {
            Task taskRecord = (Task) lookupContext.record();


            if (taskRecord.Subject == 'Case Followup') {
                lookupContext.addMissingLookup(Task.WhatId, caseDataFactory);
            } else {
                lookupContext.addMissingLookup(Task.WhatId, opportunityDataFactory);
            }


            lookupContext.addMissingLookup(Task.WhoId, contactDataFactory);

        }
    }

    private class ContactDataFactory2 extends FL_DataFactory {
        private final ParentMode accountParentMode;
        private final AccountDataFactory2 accountDataFactory = new AccountDataFactory2();
        public ContactDataFactory2() {
            this.accountParentMode = ParentMode.DIFFERENT_PARENT;
        }
        public ContactDataFactory2(ParentMode accountParentMode) {
            this.accountParentMode = accountParentMode;
        }
        protected override SObject getDefaultRecord(Integer index) {
            Contact contactRecord = new Contact();
            contactRecord.LastName = 'Test' + index;
            contactRecord.FirstName = 'Contact';
            contactRecord.Email = contactRecord.LastName + contactRecord.FirstName + Math.floor(Math.random() * 1000) + '@test.com';
            return contactRecord;
        }

        protected override void addLookups(FL_DataFactory.LookupContext lookupContext) {
            lookupContext.addMissingLookup(Contact.AccountId, accountDataFactory, accountParentMode);
        }
    }

    private class AccountDataFactory2 extends FL_DataFactory {
        protected override SObject getDefaultRecord(Integer index) {
            Account accountRecord = new Account();
            accountRecord.Name = 'Test' + index + ' Account';
            accountRecord.BillingCity = 'Into' + index;
            accountRecord.BillingStreet = '3022  Strother Street' + index;
            accountRecord.BillingState = 'Alabama' + index;
            accountRecord.BillingPostalCode = '3522' + index;
            accountRecord.BillingCountry = 'US';
            return accountRecord;
        }
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

    private class RecordTypeAwareAccountFactory extends FL_DataFactory {
        protected override SObject getDefaultRecord(Integer index) {
            return new Account(Name = 'RecordTypeAware ' + index);
        }

        protected override void assignConditionally(SObject sObjectRecord) {
            if (sObjectRecord.getSObjectType() == Account.SObjectType) {
                Account accountRecord = (Account) sObjectRecord;
                Map<String, Schema.SObjectField> fieldsByName = Account.SObjectType.getDescribe().fields.getMap();
                Id recordTypeId = fieldsByName.containsKey('RecordTypeId') ? (Id) accountRecord.get('RecordTypeId') : null;
                Boolean isRecordTypeSpecific = recordTypeId != null || accountRecord.Name == 'RT_BRANCH_MARKER';
                if (isRecordTypeSpecific) {
                    accountRecord.Industry = 'TYPE_ACCOUNT_RECORDTYPE_BRANCH';
                    accountRecord.Type = 'RECORD_TYPE_SPECIFIC';
                } else {
                    accountRecord.Industry = 'TYPE_ACCOUNT_DEFAULT_BRANCH';
                    accountRecord.Type = 'DEFAULT';
                }
            }
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
