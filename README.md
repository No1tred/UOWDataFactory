# Abstract Unit Of Work Data Factory

This repository provides two core building blocks for generating and persisting related Salesforce data:

- `FL_UnitOfWork`: builds a dependency graph between records and executes DML in an order that respects relationships.
- `FL_DataFactory`: composes test/sample records and automatically wires lookup/master-detail fields using configurable rules.

The two classes are designed to work together, but each can be used independently.

## Table Of Contents

- [Core Concepts](#core-concepts)
- [FL_UnitOfWork](#fl_unitofwork)
- [FL_DataFactory](#fl_datafactory)
- [Benchmark: FL vs fflib](#benchmark-fl-vs-fflib)
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

## Benchmark: FL vs fflib

### Scope

This benchmark compares:

- `FL_UnitOfWork` (multi/single mode, first iteration and time-limit variant)
- `fflib_SObjectUnitOfWork` (single-commit and two-phase workaround)

The compared graph is the same business graph used in `FL_UnitOfWorkTest` shape:

- 7 Accounts
- 6 Contacts
- 2 Opportunities
- 15 expected lookups

### Imported and benchmark classes

- `force-app/main/default/classes/fflib_ISObjectUnitOfWork.cls`
- `force-app/main/default/classes/fflib_SObjectUnitOfWork.cls`
- `force-app/main/default/classes/FL_UowFrameworkBenchmark.cls`
- `force-app/main/default/classes/FL_UowFrameworkBenchmarkTest.cls`
- `force-app/main/default/classes/fflib_SObjectUnitOfWorkCoverageTest.cls`
- `force-app/main/default/classes/FL_DatabaseWrapperCoverageTest.cls`

### Key functional findings

1. `fflib` single-commit inserts the same object counts but does not fully resolve same-type edges on this graph.
2. Missing relationships in `fflib` single-commit are same-type lookups (`Account.ParentId`, `Contact.ReportsToId`).
3. To match FL relationship correctness, `fflib` must run in two phases:
   - Phase 1: insert records and resolve cross-type lookups.
   - Phase 2: `registerDirty(...)` updates to set same-type lookups.
4. `FL_UnitOfWork` can resolve the graph in one flow.

### General comparison: `FL_UnitOfWork` vs `fflib_SObjectUnitOfWork`

| Aspect | `FL_UnitOfWork` | `fflib_SObjectUnitOfWork` |
|---|---|---|
| Core model | Explicit graph (`nodes + edges`) | Per-type UoW registries (`new/dirty/delete`) |
| Relationship definition | Fluent graph builder + direct relation APIs | `registerRelationship(...)` APIs |
| Same-type lookup handling in one pass | Supported via graph ordering/strategy | Limited on this tested graph; required two-phase workaround |
| Optional edge semantics | First-class (`required` vs `optional`) | No direct optional-edge graph search concept |
| Search controls | `firstIterationOnly`, `timeLimitMS` | Not applicable in same way |
| Execution modes | `MULTI_TYPE`, `SINGLE_TYPE` | Type-order driven commit sequence |
| Auto default lookup inference | Built-in (`getDefaultLookupField`) | Must provide relationship fields explicitly |
| Non-DML work integration | Focused on DML graph execution | Includes event publish hooks, email work, custom `IDoWork` |
| DML extensibility | Via wrapper (`FL_DatabaseWrapper`) | Via `IDML` strategy (`SimpleDML`, `UserModeDML`, custom IDML) |
| Typical strength | Complex dependency graph solving with minimal extra update phases | Enterprise UoW orchestration with extension points and broad ecosystem adoption |

Practical guidance:

- Prefer `FL_UnitOfWork` when your primary problem is dependency-graph optimization and same-type graph resolution in a single orchestration flow.
- Prefer `fflib_SObjectUnitOfWork` when you need standardized enterprise-layer integration (events, email/work hooks, pluggable DML modes), and your graph can tolerate or explicitly model multi-phase processing.

### Required-edges comparison

When all FL edges are required, optional-edge exploration is skipped by design (`optionalEdges.isEmpty()` fast-path).  
So `firstIteration` and `timeLimit` do not change the planned DML sequence; differences are timing noise.

Validated DML metrics:

- `fflib` two-phase: 7 statements, 22 rows
- `FL` all-required multi: 5 statements, 15 rows
- `FL` all-required single: 6 statements, 15 rows

### Clean timing metric set

Because CPU counters in this validation harness were not monotonic in all cases, final clean timing used monotonic wall-clock (`DateTime.now().getTime()`), measured from the same scenario start:

- `total`: scenario start to scenario end
- `first`: scenario start to first DML
- `after`: `total - first`

Captured comparison:

| Scenario | Total ms | First DML ms | After First DML ms | DML Statements | DML Rows |
|---|---:|---:|---:|---:|---:|
| fflib two-phase | 1004 | 4 | 1000 | 7 | 22 |
| FL all-required multi + firstIteration | 905 | 322 | 583 | 5 | 15 |
| FL all-required multi + timeLimit=200 | 596 | 26 | 570 | 5 | 15 |
| FL all-required single + firstIteration | 613 | 94 | 519 | 6 | 15 |
| FL all-required single + timeLimit=200 | 558 | 55 | 503 | 6 | 15 |

### Hurdles encountered

1. `fflib` needed import into this repo (`fflib_SObjectUnitOfWork` + interface) before testing.
2. Validation coverage requirements blocked deploy validation until additional coverage tests were added.
3. Proving parity required explicit snapshot tests:
   - object counts matched
   - lookup completeness differed on single-commit `fflib`
4. `fflib` same-type relationship support required a two-phase strategy to reach FL-equivalent lookup completeness.
5. Measuring first-DML timing in validate-only mode required custom probe wrappers and explicit capture runs.

### Validation artifacts

Important result files under `artifacts/validation-runs/`:

- `uow_parity_validate.json`
- `uow_fflib_twophase_compare_validate.json`
- `uow_clean_wall_capture_fail.json` (capture payload)
- `uow_clean_wall_validate_final.json` (final green validation)

### Reproducibility and branch

The full benchmark additions are intended to be committed on branch:

- `fflibUWComparision`

To reproduce with the same approach:

```bash
sf project deploy validate \
  --metadata ApexClass:FL_DatabaseWrapper \
  --metadata ApexClass:fflib_ISObjectUnitOfWork \
  --metadata ApexClass:fflib_SObjectUnitOfWork \
  --metadata ApexClass:FL_UowFrameworkBenchmark \
  --metadata ApexClass:FL_UowFrameworkBenchmarkTest \
  --metadata ApexClass:fflib_SObjectUnitOfWorkCoverageTest \
  --metadata ApexClass:FL_DatabaseWrapperCoverageTest \
  --target-org MY_ORG \
  --test-level RunSpecifiedTests \
  --tests FL_UowFrameworkBenchmarkTest \
  --tests fflib_SObjectUnitOfWorkCoverageTest \
  --tests FL_DatabaseWrapperCoverageTest \
  --wait 240 \
  --verbose \
  --json
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
