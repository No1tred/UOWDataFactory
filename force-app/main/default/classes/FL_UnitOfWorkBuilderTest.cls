@IsTest
private class FL_UnitOfWorkBuilderTest {
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
    static void testBuilderParentOptOverloads() {
        FL_UnitOfWork uow = new FL_UnitOfWork();
        Account baseAcc = new Account(Name = 'base');
        FL_UnitOfWork.UnitOfWorkBuilder baseBuilder = uow.addSobject(baseAcc);

        FL_UnitOfWork.UnitOfWorkBuilder parentBuilderOpt = uow.addSobject(new Account(Name = 'parentOptBuilder'));
        FL_UnitOfWork.UnitOfWorkBuilder parentBuilderOptField = uow.addSobject(new Account(Name = 'parentOptFieldBuilder'));

        baseBuilder.parentOpt(parentBuilderOpt);
        FL_RelationShipPointer parentOptPointer = findPointerByNodes(uow, baseBuilder.baseNode(), parentBuilderOpt.baseNode());
        Assert.isNotNull(parentOptPointer);
        Assert.isFalse(parentOptPointer.isRequired);
        Assert.isNotNull(parentOptPointer.field);

        Account parentOptSobjAcc = new Account(Name = 'parentOptSobj');
        baseBuilder.parentOpt(parentOptSobjAcc);
        FL_RelationShipPointer parentOptSobj = findPointerByInstances(uow, baseAcc, parentOptSobjAcc);
        Assert.isNotNull(parentOptSobj);
        Assert.isFalse(parentOptSobj.isRequired);

        FL_SObjectNode parentNode = new FL_SObjectNode(new Account(Name = 'parentNode'));
        baseBuilder.parentOpt(parentNode);
        FL_RelationShipPointer parentOptNode = findPointerByNodes(uow, baseBuilder.baseNode(), parentNode);
        Assert.isNotNull(parentOptNode);
        Assert.isFalse(parentOptNode.isRequired);
        Assert.isNotNull(parentOptNode.field);

        baseBuilder.parentOpt(Account.ParentId, parentBuilderOptField);
        FL_RelationShipPointer parentOptField = findPointerByNodes(uow, baseBuilder.baseNode(), parentBuilderOptField.baseNode());
        Assert.isNotNull(parentOptField);
        Assert.isFalse(parentOptField.isRequired);
        Assert.areEqual(Account.ParentId, parentOptField.field);

        Account parentOptFieldSobjAcc = new Account(Name = 'parentOptFieldSobj');
        baseBuilder.parentOpt(Account.ParentId, parentOptFieldSobjAcc);
        FL_RelationShipPointer parentOptFieldSobj = findPointerByInstances(uow, baseAcc, parentOptFieldSobjAcc);
        Assert.isNotNull(parentOptFieldSobj);
        Assert.areEqual(Account.ParentId, parentOptFieldSobj.field);

        FL_SObjectNode parentNodeField = new FL_SObjectNode(new Account(Name = 'parentNodeField'));
        baseBuilder.parentOpt(Account.ParentId, parentNodeField);
        FL_RelationShipPointer parentOptFieldNode = findPointerByNodes(uow, baseBuilder.baseNode(), parentNodeField);
        Assert.isNotNull(parentOptFieldNode);
        Assert.areEqual(Account.ParentId, parentOptFieldNode.field);
    }

    @IsTest
    static void testBuilderChildOptOverloads() {
        FL_UnitOfWork uow = new FL_UnitOfWork();
        Account baseAcc = new Account(Name = 'base');
        FL_UnitOfWork.UnitOfWorkBuilder baseBuilder = uow.addSobject(baseAcc);

        FL_UnitOfWork.UnitOfWorkBuilder childBuilderOpt = uow.addSobject(new Account(Name = 'childOptBuilder'));
        FL_UnitOfWork.UnitOfWorkBuilder childBuilderOptField = uow.addSobject(new Account(Name = 'childOptFieldBuilder'));

        baseBuilder.childOpt(childBuilderOpt);
        FL_RelationShipPointer childOptPointer = findPointerByNodes(uow, childBuilderOpt.baseNode(), baseBuilder.baseNode());
        Assert.isNotNull(childOptPointer);
        Assert.isFalse(childOptPointer.isRequired);
        Assert.isNotNull(childOptPointer.field);

        FL_SObjectNode childNode = new FL_SObjectNode(new Account(Name = 'childNode'));
        baseBuilder.childOpt(childNode);
        FL_RelationShipPointer childOptNodePointer = findPointerByNodes(uow, childNode, baseBuilder.baseNode());
        Assert.isNotNull(childOptNodePointer);
        Assert.isFalse(childOptNodePointer.isRequired);

        baseBuilder.childOpt(Account.ParentId, childBuilderOptField);
        FL_RelationShipPointer childOptField = findPointerByNodes(uow, childBuilderOptField.baseNode(), baseBuilder.baseNode());
        Assert.isNotNull(childOptField);
        Assert.areEqual(Account.ParentId, childOptField.field);

        Account childOptFieldSobjAcc = new Account(Name = 'childOptFieldSobj');
        baseBuilder.childOpt(Account.ParentId, childOptFieldSobjAcc);
        FL_RelationShipPointer childOptFieldSobj = findPointerByInstances(uow, childOptFieldSobjAcc, baseAcc);
        Assert.isNotNull(childOptFieldSobj);
        Assert.areEqual(Account.ParentId, childOptFieldSobj.field);

        FL_SObjectNode childNodeField = new FL_SObjectNode(new Account(Name = 'childNodeField'));
        baseBuilder.childOpt(Account.ParentId, childNodeField);
        FL_RelationShipPointer childOptFieldNode = findPointerByNodes(uow, childNodeField, baseBuilder.baseNode());
        Assert.isNotNull(childOptFieldNode);
        Assert.areEqual(Account.ParentId, childOptFieldNode.field);

        Contact childOptSobjCon = new Contact(LastName = 'childOptSobj');
        baseBuilder.childOpt(childOptSobjCon);
        FL_RelationShipPointer childOptSobjPointer = findPointerByInstances(uow, childOptSobjCon, baseAcc);
        Assert.isNotNull(childOptSobjPointer);
        Assert.isFalse(childOptSobjPointer.isRequired);
    }

    @IsTest
    static void testBuilderChildRequiredOverloads() {
        FL_UnitOfWork uow = new FL_UnitOfWork();
        Account baseAcc = new Account(Name = 'base');
        FL_UnitOfWork.UnitOfWorkBuilder baseBuilder = uow.addSobject(baseAcc);

        FL_UnitOfWork.UnitOfWorkBuilder childBuilderReq = uow.addSobject(new Account(Name = 'childReqBuilder'));
        FL_UnitOfWork.UnitOfWorkBuilder childBuilderReqField = uow.addSobject(new Account(Name = 'childReqFieldBuilder'));

        Account childSobjAcc = new Account(Name = 'childSobj');
        baseBuilder.child(childSobjAcc);
        FL_RelationShipPointer childSobjPointer = findPointerByInstances(uow, childSobjAcc, baseAcc);
        Assert.isNotNull(childSobjPointer);
        Assert.isTrue(childSobjPointer.isRequired);

        baseBuilder.child(childBuilderReq);
        FL_RelationShipPointer childPointer = findPointerByNodes(uow, childBuilderReq.baseNode(), baseBuilder.baseNode());
        Assert.isNotNull(childPointer);
        Assert.isTrue(childPointer.isRequired);

        FL_SObjectNode childNodeReq = new FL_SObjectNode(new Account(Name = 'childNodeReq'));
        baseBuilder.child(childNodeReq);
        FL_RelationShipPointer childNodeReqPointer = findPointerByNodes(uow, childNodeReq, baseBuilder.baseNode());
        Assert.isNotNull(childNodeReqPointer);
        Assert.isTrue(childNodeReqPointer.isRequired);

        baseBuilder.child(Account.ParentId, childBuilderReqField);
        FL_RelationShipPointer childFieldPointer = findPointerByNodes(uow, childBuilderReqField.baseNode(), baseBuilder.baseNode());
        Assert.isNotNull(childFieldPointer);
        Assert.areEqual(Account.ParentId, childFieldPointer.field);

        Account childFieldSobjAcc = new Account(Name = 'childFieldSobj');
        baseBuilder.child(Account.ParentId, childFieldSobjAcc);
        FL_RelationShipPointer childFieldSobj = findPointerByInstances(uow, childFieldSobjAcc, baseAcc);
        Assert.isNotNull(childFieldSobj);
        Assert.areEqual(Account.ParentId, childFieldSobj.field);

        FL_SObjectNode childFieldNode = new FL_SObjectNode(new Account(Name = 'childFieldNode'));
        baseBuilder.child(Account.ParentId, childFieldNode);
        FL_RelationShipPointer childFieldNodePointer = findPointerByNodes(uow, childFieldNode, baseBuilder.baseNode());
        Assert.isNotNull(childFieldNodePointer);
        Assert.areEqual(Account.ParentId, childFieldNodePointer.field);
    }

    @IsTest
    static void testBuilderParentRequiredOverloads() {
        FL_UnitOfWork uow = new FL_UnitOfWork();
        Account baseAcc = new Account(Name = 'base');
        FL_UnitOfWork.UnitOfWorkBuilder baseBuilder = uow.addSobject(baseAcc);

        FL_UnitOfWork.UnitOfWorkBuilder parentBuilderReq = uow.addSobject(new Account(Name = 'parentReqBuilder'));
        FL_UnitOfWork.UnitOfWorkBuilder parentBuilderReqField = uow.addSobject(new Account(Name = 'parentReqFieldBuilder'));

        Account parentSobjAcc = new Account(Name = 'parentSobj');
        baseBuilder.parent(parentSobjAcc);
        FL_RelationShipPointer parentSobjPointer = findPointerByInstances(uow, baseAcc, parentSobjAcc);
        Assert.isNotNull(parentSobjPointer);
        Assert.isTrue(parentSobjPointer.isRequired);

        baseBuilder.parent(parentBuilderReq);
        FL_RelationShipPointer parentPointer = findPointerByNodes(uow, baseBuilder.baseNode(), parentBuilderReq.baseNode());
        Assert.isNotNull(parentPointer);
        Assert.isTrue(parentPointer.isRequired);

        FL_SObjectNode parentNodeReq = new FL_SObjectNode(new Account(Name = 'parentNodeReq'));
        baseBuilder.parent(parentNodeReq);
        FL_RelationShipPointer parentNodeReqPointer = findPointerByNodes(uow, baseBuilder.baseNode(), parentNodeReq);
        Assert.isNotNull(parentNodeReqPointer);
        Assert.isTrue(parentNodeReqPointer.isRequired);

        baseBuilder.parent(Account.ParentId, parentBuilderReqField);
        FL_RelationShipPointer parentFieldPointer = findPointerByNodes(uow, baseBuilder.baseNode(), parentBuilderReqField.baseNode());
        Assert.isNotNull(parentFieldPointer);
        Assert.areEqual(Account.ParentId, parentFieldPointer.field);

        Account parentFieldSobjAcc = new Account(Name = 'parentFieldSobj');
        baseBuilder.parent(Account.ParentId, parentFieldSobjAcc);
        FL_RelationShipPointer parentFieldSobj = findPointerByInstances(uow, baseAcc, parentFieldSobjAcc);
        Assert.isNotNull(parentFieldSobj);
        Assert.areEqual(Account.ParentId, parentFieldSobj.field);

        FL_SObjectNode parentFieldNode = new FL_SObjectNode(new Account(Name = 'parentFieldNode'));
        baseBuilder.parent(Account.ParentId, parentFieldNode);
        FL_RelationShipPointer parentFieldNodePointer = findPointerByNodes(uow, baseBuilder.baseNode(), parentFieldNode);
        Assert.isNotNull(parentFieldNodePointer);
        Assert.areEqual(Account.ParentId, parentFieldNodePointer.field);
    }

    @IsTest
    static void testBuilderThenOverloads() {
        FL_UnitOfWork uow = new FL_UnitOfWork();
        Account baseAcc = new Account(Name = 'base');
        FL_UnitOfWork.UnitOfWorkBuilder baseBuilder = uow.addSobject(baseAcc);
        FL_UnitOfWork.UnitOfWorkBuilder thenBuilder = uow.addSobject(new Account(Name = 'thenBuilder'));

        baseBuilder.then(thenBuilder);
        FL_RelationShipPointer thenPointer = findPointerByNodes(uow, thenBuilder.baseNode(), baseBuilder.baseNode());
        Assert.isNotNull(thenPointer);
        Assert.isTrue(thenPointer.isRequired);
        Assert.isNull(thenPointer.field);

        FL_SObjectNode thenNode = new FL_SObjectNode(new Account(Name = 'thenNode'));
        baseBuilder.then(thenNode);
        FL_RelationShipPointer thenNodePointer = findPointerByNodes(uow, thenNode, baseBuilder.baseNode());
        Assert.isNotNull(thenNodePointer);
        Assert.isTrue(thenNodePointer.isRequired);
        Assert.isNull(thenNodePointer.field);

        Account thenSobjAcc = new Account(Name = 'thenSobj');
        baseBuilder.then(thenSobjAcc);
        FL_RelationShipPointer thenSobjPointer = findPointerByInstances(uow, thenSobjAcc, baseAcc);
        Assert.isNotNull(thenSobjPointer);
        Assert.isTrue(thenSobjPointer.isRequired);
        Assert.isNull(thenSobjPointer.field);
    }

    @IsTest
    static void testBuilderBeforeDoOverloads() {
        FL_UnitOfWork uow = new FL_UnitOfWork();
        Account baseAcc = new Account(Name = 'base');
        FL_UnitOfWork.UnitOfWorkBuilder baseBuilder = uow.addSobject(baseAcc);
        FL_UnitOfWork.UnitOfWorkBuilder beforeDoBuilder = uow.addSobject(new Account(Name = 'beforeDoBuilder'));

        baseBuilder.beforeDo(beforeDoBuilder);
        FL_RelationShipPointer beforeDoPointer = findPointerByNodes(uow, baseBuilder.baseNode(), beforeDoBuilder.baseNode());
        Assert.isNotNull(beforeDoPointer);
        Assert.isTrue(beforeDoPointer.isRequired);
        Assert.isNull(beforeDoPointer.field);

        FL_SObjectNode beforeDoNode = new FL_SObjectNode(new Account(Name = 'beforeDoNode'));
        baseBuilder.beforeDo(beforeDoNode);
        FL_RelationShipPointer beforeDoNodePointer = findPointerByNodes(uow, baseBuilder.baseNode(), beforeDoNode);
        Assert.isNotNull(beforeDoNodePointer);
        Assert.isTrue(beforeDoNodePointer.isRequired);
        Assert.isNull(beforeDoNodePointer.field);

        Account beforeDoSobjAcc = new Account(Name = 'beforeDoSobj');
        baseBuilder.beforeDo(beforeDoSobjAcc);
        FL_RelationShipPointer beforeDoSobjPointer = findPointerByInstances(uow, baseAcc, beforeDoSobjAcc);
        Assert.isNotNull(beforeDoSobjPointer);
        Assert.isTrue(beforeDoSobjPointer.isRequired);
        Assert.isNull(beforeDoSobjPointer.field);
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
}
