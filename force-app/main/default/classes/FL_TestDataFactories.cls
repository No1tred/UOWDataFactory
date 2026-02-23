@IsTest
public with sharing class FL_TestDataFactories {
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
        protected override SObject getDefaultRecord(Integer index, Id recordTypeId) {
            Account accountRecord = new Account();
            accountRecord.Name = 'Enterprise ' + index + ' Account';
            accountRecord.BillingCity = 'City ' + index;
            accountRecord.BillingStreet = '100 Enterprise Way ' + index;
            accountRecord.BillingState = 'CA';
            accountRecord.BillingPostalCode = '9000' + index;
            accountRecord.BillingCountry = 'US';
            accountRecord.AnnualRevenue = 500000 + (index * 10000);
            if (recordTypeId != null) {
                accountRecord.Name += ' with record type: ' + recordTypeId;
            }
            return accountRecord;
        }
    }

    private class SmbAccountDataFactory extends FL_DataFactory {
        protected override SObject getDefaultRecord(Integer index, Id recordTypeId) {
            Account accountRecord = new Account();
            accountRecord.Name = 'SMB ' + index + ' Account';
            accountRecord.BillingCity = 'Town ' + index;
            accountRecord.BillingStreet = '10 Main St ' + index;
            accountRecord.BillingState = 'TX';
            accountRecord.BillingPostalCode = '7500' + index;
            accountRecord.BillingCountry = 'US';
            accountRecord.AnnualRevenue = 25000 + (index * 1000);
            if (recordTypeId != null) {
                accountRecord.Name += ' with record type: ' + recordTypeId;
            }
            return accountRecord;
        }
    }

    private class OpportunityDataFactory extends FL_DataFactory {
        private final EnterpriseAccountDataFactory enterpriseAccountFactory = new EnterpriseAccountDataFactory();
        private final SmbAccountDataFactory smbAccountFactory = new SmbAccountDataFactory();

        protected override SObject getDefaultRecord(Integer index, Id recordTypeId) {
            Opportunity oppRecord = new Opportunity();
            oppRecord.Name = 'Opp ' + index;
            oppRecord.StageName = 'Prospecting';
            oppRecord.CloseDate = Date.today().addDays(30 + index);
            oppRecord.Amount = (Math.mod(index, 2) == 0) ? 150000 : 15000;
            if (recordTypeId != null) {
                oppRecord.Name += ' with record type: ' + recordTypeId;
            }
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

        protected override SObject getDefaultRecord(Integer index, Id recordTypeId) {
            Case caseRecord = new Case();
            caseRecord.Subject = 'Case ' + index;
            caseRecord.Status = 'New';
            caseRecord.Origin = 'Phone';
            caseRecord.Priority = (Math.mod(index, 2) == 0) ? 'High' : 'Low';
            if (recordTypeId != null) {
                caseRecord.Subject += ' with record type: ' + recordTypeId;
            }
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
        protected override SObject getDefaultRecord(Integer index, Id recordTypeId) {
            Lead leadRecord = new Lead();
            leadRecord.LastName = 'Lead ' + index;
            leadRecord.Company = 'Company ' + index;
            leadRecord.Status = 'Open - Not Contacted';
            if (recordTypeId != null) {
                leadRecord.Company += ' with record type: ' + recordTypeId;
            }
            return leadRecord;
        }
    }

    private class TaskDataFactory extends FL_DataFactory {
        private final CaseDataFactory caseDataFactory = new CaseDataFactory();
        private final OpportunityDataFactory opportunityDataFactory = new OpportunityDataFactory();
        private final ContactDataFactory2 contactDataFactory = new ContactDataFactory2();

        protected override SObject getDefaultRecord(Integer index, Id recordTypeId) {
            Task taskRecord = new Task();
            taskRecord.Subject = (Math.mod(index, 2) == 0) ? 'Case Followup' : 'Opportunity Followup';
            taskRecord.Status = 'Not Started';
            if (recordTypeId != null) {
                taskRecord.Subject += ' with record type: ' + recordTypeId;
            }
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
        protected override SObject getDefaultRecord(Integer index, Id recordTypeId) {
            Contact contactRecord = new Contact();
            contactRecord.LastName = 'Test' + index;
            contactRecord.FirstName = 'Contact';
            contactRecord.Email = contactRecord.LastName + contactRecord.FirstName + Math.floor(Math.random() * 1000) + '@test.com';
            if (recordTypeId != null) {
                contactRecord.FirstName += ' with recordtype: ' + recordTypeId;
            }
            return contactRecord;
        }

        protected override void addLookups(FL_DataFactory.LookupContext lookupContext) {
            lookupContext.addMissingLookup(Contact.AccountId, accountDataFactory, accountParentMode);
        }
    }

    private class AccountDataFactory2 extends FL_DataFactory {
        protected override SObject getDefaultRecord(Integer index, Id recordTypeId) {
            Account accountRecord = new Account();
            accountRecord.Name = 'Test' + index + ' Account';
            accountRecord.BillingCity = 'Into' + index;
            accountRecord.BillingStreet = '3022  Strother Street' + index;
            accountRecord.BillingState = 'Alabama' + index;
            accountRecord.BillingPostalCode = '3522' + index;
            accountRecord.BillingCountry = 'US';
            if (recordTypeId != null) {
                accountRecord.Name += ' with record type: ' + recordTypeId;
            }
            return accountRecord;
        }
    }

}

