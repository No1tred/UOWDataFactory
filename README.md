# Abstract Unit Of Work Data Factory

This repository provides two core building blocks for generating and persisting related Salesforce data:

- `FL_UnitOfWork`: builds a dependency graph between records and executes DML in an order that respects relationships.
- `FL_DataFactory`: composes test/sample records and automatically wires lookup/master-detail fields using configurable rules.

The two classes are designed to work together, but each can be used independently.

## Table Of Contents

- [Core Concepts](#core-concepts)
- [FL_UnitOfWork](#fl_unitofwork)
- [FL_DataFactory](#fl_datafactory)
- [End-To-End Examples](#end-to-end-examples)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)

## Core Concepts

### Graph model

Each record is represented by an `FL_SObjectNode`, and each dependency is an `FL_RelationShipPointer`:

- Source node: record that contains a lookup field.
- Target node: parent record referenced by that lookup.
- Edge type:
  - Required relation: parent must exist before child insert.
  - Optional relation: engine can choose either direct insert order or insert-then-update strategy.

### Instance identity and node reuse

`FL_UnitOfWork` and `FL_DataFactory` both deduplicate by Apex object identity (`===`), not by field values.

Important consequence:

- If the same in-memory `SObject` instance is reused across calls, the same `FL_SObjectNode` is reused.
- If two different `SObject` instances have identical field values, they are treated as different nodes.

This is intentional and prevents accidental duplicate graph nodes for the same in-memory object.

### Execution modes

`FL_UnitOfWork` supports:

- `FL_UnitOfWork.Mode.MULTI_TYPE`: optimized scheduling that can mix multiple sObject types per step.
- `FL_UnitOfWork.Mode.SINGLE_TYPE`: scheduling optimized for single-type statements.

## FL_UnitOfWork

Source: `force-app/main/default/classes/FL_UnitOfWork.cls`

### Create and register nodes

```apex
FL_UnitOfWork uow = new FL_UnitOfWork();

Account acc = new Account(Name = 'Acme');
Contact con = new Contact(LastName = 'Doe');

uow.addSobject(acc);
uow.addSobject(con);
```

Both overloads are available:

- `addSobject(SObject)`
- `addSobject(FL_SObjectNode)`

### Add relationships directly

```apex
// Required: Contact.AccountId must be filled with Account Id
uow.addRequiredRelation(con, acc);

// Optional: engine may insert/update in a different strategy
uow.addOptionalRelation(con, Contact.AccountId, acc);
```

Overloads exist for:

- Auto-default lookup detection between source/target types
- Explicit `SObjectField`
- Relations without a lookup field (`addRequiredRelationWithoutDefault`) for ordering-only dependencies

### Use the fluent builder API

```apex
FL_UnitOfWork.UnitOfWorkBuilder accountB = uow.addSobject(acc);
FL_UnitOfWork.UnitOfWorkBuilder contactB = uow.addSobject(con);

contactB.parent(Contact.AccountId, accountB); // required relation via explicit field
```

Common fluent methods:

- Parent relations: `parent(...)`, `parentOpt(...)`
- Child relations: `child(...)`, `childOpt(...)`
- Ordering-only dependency: `then(...)`, `beforeDo(...)`

### Perform DML

```apex
uow.performDMLs(FL_UnitOfWork.Mode.MULTI_TYPE);
// or
uow.performDMLs(FL_UnitOfWork.Mode.SINGLE_TYPE);
```

Optional overloads support:

- `timeLimitMS` for optional-edge search budget
- `firstIterationOnly` to skip exhaustive optional-edge exploration

### How default lookup resolution works

When you call relation methods without explicit field, `getDefaultLookupField(fromType, toType)`:

- scans createable reference fields on `fromType`
- prefers single-reference fields over polymorphic reference fields
- prefers custom fields over standard when both are candidates
- caches result in `cachedDefaultLookups`

If no matching lookup/master-detail exists, an exception is thrown.

## FL_DataFactory

Source: `force-app/main/default/classes/FL_DataFactory.cls`

`FL_DataFactory` is an abstract class. You provide record defaults and optional lookup rules.

### Minimal factory

```apex
public class AccountFactory extends FL_DataFactory {
    protected override SObject getDefaultRecord(Integer index, Id recordTypeId) {
        Account a = new Account();
        a.Name = 'Account ' + index;
        return a;
    }
}
```

### Compose vs insert

- `composeRecords(...)`: build records and graph only, no DML yet.
- `insertRecords(...)` / `insertRecord(...)`: compose + perform DML immediately.
- `createRecordWithoutSave(...)`: convenience alias for one composed record.

### Lookup builders DSL

Override `getDefaultLookupBuilders()` to auto-populate missing lookup values using other factories.

```apex
protected override FL_DataFactory.LookupsBuilders getDefaultLookupBuilders() {
    return FL_DataFactory.lookupsBuilders()
        .fill(Case.AccountId)
        .when(Case.Priority).equalTo('High')
        .with(new EnterpriseAccountFactory(), ParentMode.SAME_PARENT)
        .fill(Case.AccountId)
        .elseWith(new SmbAccountFactory())
        .fill(Case.ContactId)
        .alwaysWith(new ContactFactory());
}
```

Supported condition operators:

- `equalTo`
- `biggerThan`
- `lessThan`
- `biggerOrEqualsThan`
- `lessOrEqualsThan`
- unconditional `alwaysWith`

### ParentMode behavior

- `ParentMode.SAME_PARENT`: one parent record is reused for all matching children in the same compose run.
- `ParentMode.DIFFERENT_PARENT`: one parent per child is created.

### Context and batching

`FL_DataFactory` uses a shared static context (`STATIC_CONTEXT`) by default.

Typical flow:

```apex
new TaskFactory().composeRecords(3);
new CaseFactory().composeRecords(2);
FL_DataFactory.performDML(FL_UnitOfWork.Mode.MULTI_TYPE);
```

Everything composed before `performDML(...)` is inserted as one dependency graph.

You can also provide your own context:

```apex
FL_UnitOfWork uow = new FL_UnitOfWork();
FL_DataFactory.UowContext ctx = FL_DataFactory.newUowContext(uow);

new TaskFactory().composeRecords(3, null, null, null, ctx);
new CaseFactory().composeRecords(2, null, null, null, ctx);

uow.performDMLs(FL_UnitOfWork.Mode.SINGLE_TYPE);
```

## End-To-End Examples

### Example 1: Direct UnitOfWork graph

```apex
FL_UnitOfWork uow = new FL_UnitOfWork();

Account acc = new Account(Name = 'Acme');
Contact con = new Contact(LastName = 'Doe');
Task t = new Task(Subject = 'Followup', Status = 'Not Started');

FL_UnitOfWork.UnitOfWorkBuilder accB = uow.addSobject(acc);
FL_UnitOfWork.UnitOfWorkBuilder conB = uow.addSobject(con);
FL_UnitOfWork.UnitOfWorkBuilder taskB = uow.addSobject(t);

conB.parent(Contact.AccountId, accB);
taskB.parent(Task.WhatId, acc);
taskB.parent(Task.WhoId, con);

uow.performDMLs(FL_UnitOfWork.Mode.MULTI_TYPE);
```

### Example 2: Factory-driven conditional parenting

```apex
public class OpportunityFactory extends FL_DataFactory {
    protected override SObject getDefaultRecord(Integer index, Id recordTypeId) {
        Opportunity o = new Opportunity();
        o.Name = 'Opp ' + index;
        o.StageName = 'Prospecting';
        o.CloseDate = Date.today().addDays(30);
        o.Amount = Math.mod(index, 2) == 0 ? 150000 : 15000;
        return o;
    }

    protected override FL_DataFactory.LookupsBuilders getDefaultLookupBuilders() {
        return FL_DataFactory.lookupsBuilders()
            .fill(Opportunity.AccountId)
            .when(Opportunity.Amount).biggerThan(100000)
            .with(new EnterpriseAccountFactory(), ParentMode.SAME_PARENT)
            .fill(Opportunity.AccountId)
            .elseWith(new SmbAccountFactory());
    }
}
```

Usage:

```apex
new OpportunityFactory().composeRecords(5);
FL_DataFactory.performDML(FL_UnitOfWork.Mode.MULTI_TYPE);
```

### Example 3: Reusing the exact same in-memory instance

```apex
FL_UnitOfWork uow = new FL_UnitOfWork();
Task t = new Task(Subject = 'A', Status = 'Not Started');

uow.addSobject(t);
uow.addSobject(t); // same object instance

// Only one canonical node is kept for this Task instance.
```

This works the same way inside `FL_DataFactory` composition.

## Testing

Current test data factory suite:

- `force-app/main/default/classes/FL_TestDataFactories.cls`

Run as Apex tests:

```bash
sf apex run test --tests FL_TestDataFactories --target-org MY_ORG --wait 30
```

Run deploy-style validation (dry-run) with specified tests:

```bash
sf project deploy start \
  --source-dir force-app \
  --dry-run \
  --test-level RunSpecifiedTests \
  --tests FL_TestDataFactories \
  --target-org MY_ORG \
  --wait 30
```

## Troubleshooting

### No lookup/master detail pointing to target type

You used a relation overload that depends on auto lookup discovery, but no valid field exists.

Fix:

- Use explicit field overload (`parent(field, ...)`, `addRequiredRelation(source, field, target)`), or
- Add or adjust lookup field on source object.

### Graph invalid or cyclic dependencies

A cycle exists in required dependencies and cannot be topologically scheduled.

Fix:

- Change one or more edges to optional relation.
- Or split the graph into phases.

### Unexpected duplicate nodes

Deduplication is by object identity. Ensure you pass the same in-memory `SObject` instance when you intend to reference the same node.

### Optional relation behavior differs run to run

Optional-edge optimization is heuristic and time-limited. Different runs can pick different but valid schedules.

For deterministic debugging:

- set `firstIterationOnly = true` in `performDMLs(mode, firstIterationOnly, timeLimitMS)`, or
- reduce optional edges in the graph.
