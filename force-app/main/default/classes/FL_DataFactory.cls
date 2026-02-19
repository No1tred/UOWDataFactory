@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity')
public inherited sharing abstract class FL_DataFactory {
	private static final Map<SObjectType, Integer> COUNT_MAP = new Map<SObjectType, Integer>();
    @TestVisible
	private static UowContext STATIC_CONTEXT;
	private SObjectType factorySObjectType;

	private SObjectType getSobjectType() {
		if (factorySObjectType == null) {
			factorySObjectType = getSobjectType(getDefaultRecord(0, null));
		}
		return factorySObjectType;
	}

	private sObjectType getSobjectType(SObject objectRecord) {
		return objectRecord?.getSObjectType();
	}

	protected abstract SObject getDefaultRecord(Integer index, Id recordTypeId);

	public SObject insertRecord() {
		return insertRecords(1)[0];
	}

	public SObject insertRecord(SObject overrideValuesForAll, Id recordTypeId) {
		return insertRecords(1, overrideValuesForAll, null, recordTypeId)[0];
	}

	public List<SObject> insertRecords(Integer recordsNumber) {
		return insertRecords(recordsNumber, null, null, null);
	}

	public List<SObject> insertRecords(Integer recordsNumber, SObject overrideValuesForAll, List<SObject> overrideValuesForEach, Id recordTypeId) {
		List<SObject> sObjectRecords = composeRecords(recordsNumber, overrideValuesForAll, overrideValuesForEach, recordTypeId);
		performDML();
		return sObjectRecords;
	}

	public SObject createRecordWithoutSave() {
		return composeRecords(1)[0];
	}

	public SObject createRecordWithoutSave(SObject overrideValuesForAll, Id recordTypeId) {
		return composeRecords(1, overrideValuesForAll, null, recordTypeId)[0];
	}

	public List<SObject> composeRecords(Integer recordsNumber) {
		return composeRecords(recordsNumber, null, null, null);
	}

	public List<SObject> composeRecords(Integer recordsNumber, SObject overrideValuesForAll, List<SObject> overrideValuesForEach, Id recordTypeId) {
		UowContext context = getOrCreateStaticContext();
		return composeRecords(recordsNumber, overrideValuesForAll, overrideValuesForEach, recordTypeId, context);
	}

	public List<SObject> composeRecords(Integer recordsNumber, SObject overrideValuesForAll, List<SObject> overrideValuesForEach, Id recordTypeId, UowContext context) {
		List<SObject> sObjectRecords = new List<SObject>();
		Map<String, Object> mapOfValuesForAll = convertValuesIntoMap(overrideValuesForAll);
		List<Map<String, Object>> listMapOfValuesForEach = convertValuesIntoListOfMap(overrideValuesForEach);

		if (recordsNumber > 0 && listSizeEqualToRecordNumber(recordsNumber, overrideValuesForEach) && objectTypesAreEqual(overrideValuesForAll, overrideValuesForEach)) {
			Integer initialCounter = initiateCounter();

			for (Integer index = 0; index < recordsNumber; index++) {
				SObject sObjectRecord = getDefaultRecord(index + initialCounter, recordTypeId);
				if (overrideValuesForAll != null) {
					assignValuesToObject(sObjectRecord, mapOfValuesForAll);
				}
				if (overrideValuesForEach != null) {
					assignValuesToObject(sObjectRecord, listMapOfValuesForEach[index]);
				}
				sObjectRecords.add(sObjectRecord);
				ensureNode(context, sObjectRecord);
			}
			COUNT_MAP.put(getSobjectType(), initialCounter + recordsNumber);
			adjustMissingLookups(sObjectRecords, context);
		} else {
			throw new IllegalArgumentException('Record number and override object list size are not equal, or wrong object type!');
		}
        System.debug('composeRecords:' + sObjectRecords[0].getSObjectType().getDescribe().getName() + ': ' + sObjectRecords.size());
		return sObjectRecords;
	}

	private Integer initiateCounter() {
		Schema.sObjectType sObjectType = getSobjectType();
		if (!COUNT_MAP.containsKey(sObjectType)) {
			COUNT_MAP.put(sObjectType, 0);
		}
		return COUNT_MAP.get(sObjectType);
	}

	private Map<String, Object> convertValuesIntoMap(SObject overrideValues) {
		if (overrideValues != null) {
			return formatObjectValues(overrideValues);
		}
		return null;
	}

	private List<Map<String, Object>> convertValuesIntoListOfMap(List<SObject> overrideValuesList) {
		List<Map<String, Object>> listOfMapValues = new List<Map<String, Object>>();
		if (overrideValuesList != null) {
			for (SObject sObjectItem : overrideValuesList) {
				listOfMapValues.add(formatObjectValues(sObjectItem));
			}
		}
		return listOfMapValues;
	}

	private Boolean listSizeEqualToRecordNumber(Integer recordsNumber, List<SObject> overrideValuesForEach) {
		return overrideValuesForEach == null || recordsNumber == overrideValuesForEach.size();
	}

	private Boolean objectTypesAreEqual(SObject objectA, List<SObject> listOfObjects) {
		Schema.sObjectType currentFactoryType = getSobjectType();
		Schema.sObjectType objectAType = getSobjectType(objectA);
		if (objectAType != null && objectAType != currentFactoryType) {
			return false;
		}
		if (listOfObjects != null) {
			for (SObject sObjectItem : listOfObjects) {
				Schema.sObjectType objectBType = getSobjectType(sObjectItem);
				if (objectBType != null && objectBType != currentFactoryType) {
					return false;
				}
			}
		}
		return true;
	}

	private void  assignValuesToObject(SObject objectRecord, Map<String, Object> mapOfValues) {
		if (mapOfValues != null) {
			for (String field : mapOfValues.keySet()) {
				objectRecord.put(field, mapOfValues.get(field));
			}
		}
	}

	private Map<String, Object> formatObjectValues(SObject objectValues) {
		Map<String, Object> tempMap = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(objectValues));
		tempMap.remove('attributes');
		return tempMap;
	}

	private void adjustMissingLookups(List<SObject> sObjectRecords, UowContext context) {
		LookupsBuilders lookupBuildersContainer = getDefaultLookupBuilders();
		Map<Schema.SObjectField, LookupBuilder> lookupBuilders = lookupBuildersContainer == null ? new Map<Schema.SObjectField, LookupBuilder>() : lookupBuildersContainer.build();
		if (lookupBuilders.isEmpty()) {
			return;
		}

		Map<LookupAssignment, List<SObject>> missingRecordsMap = new Map<LookupAssignment, List<SObject>>();
		for (SObject sObjectItem : sObjectRecords) {
			for (Schema.SObjectField lookupField : lookupBuilders.keySet()) {
				if (sObjectItem.get(lookupField.getDescribe().getName()) != null) {
					continue;
				}
				LookupWrapper wrapper = resolveLookupWrapper(lookupField, sObjectItem, lookupBuilders);
				if (wrapper == null || wrapper.dataFactory == null) {
					continue;
				}
				LookupAssignment assignment = new LookupAssignment(lookupField, wrapper);
				if (!missingRecordsMap.containsKey(assignment)) {
					missingRecordsMap.put(assignment, new List<SObject>());
				}
				missingRecordsMap.get(assignment).add(sObjectItem);
			}
		}

		assignRelationshipsToObjects(missingRecordsMap, context);
	}

	private void assignRelationshipsToObjects(Map<LookupAssignment, List<SObject>> missingRecordsMap, UowContext context) {
		for (LookupAssignment assignment : missingRecordsMap.keySet()) {
			LookupWrapper wrapper = assignment.wrapper;
			Schema.SObjectField lookupField = assignment.lookupField;
			List<SObject> recordsMissingLookup = missingRecordsMap.get(assignment);
			if (recordsMissingLookup.isEmpty()) {
				continue;
			}
			if (wrapper.parentMode == ParentMode.SAME_PARENT) {
				FL_SObjectNode parentNode = context.parentNodesByFactory.get(wrapper.dataFactory);
				if (parentNode == null) {
					SObject parentObject = wrapper.dataFactory.composeRecords(1, null, null, null, context)[0];
					parentNode = ensureNode(context, parentObject);
					context.parentNodesByFactory.put(wrapper.dataFactory, parentNode);
				}
				if (fieldCompatibleWithObject(lookupField, parentNode.getSObjectType())) {
					for (SObject childRecord : recordsMissingLookup) {
						FL_SObjectNode childNode = ensureNode(context, childRecord);
						addRelation(context, childNode, lookupField, parentNode);
					}
				}
			} else {
				List<SObject> parentObjectList = wrapper.dataFactory.composeRecords(recordsMissingLookup.size(), null, null, null, context);
				if (fieldCompatibleWithObject(lookupField, getSobjectType(parentObjectList[0]))) {
					for (Integer i = 0; i < recordsMissingLookup.size(); i++) {
						FL_SObjectNode parentNode = ensureNode(context, parentObjectList[i]);
						FL_SObjectNode childNode = ensureNode(context, recordsMissingLookup[i]);
						addRelation(context, childNode, lookupField, parentNode);
					}
				}
			}
		}
	}

	private Boolean fieldCompatibleWithObject(Schema.SObjectField fieldName, SObjectType parentObjectRecord) {
		List<SObjectType> referencedToTypes = fieldName.getDescribe().getReferenceTo();
		return referencedToTypes?.contains(parentObjectRecord) == true;
	}

	protected virtual LookupsBuilders getDefaultLookupBuilders() {
		return lookupsBuilders();
	}

	private LookupWrapper resolveLookupWrapper(
		Schema.SObjectField lookupField,
		SObject record,
		Map<Schema.SObjectField, LookupBuilder> lookupBuilders
	) {
		LookupBuilder builder = lookupBuilders.get(lookupField);
		if (builder != null) {
			return builder.resolve(record);
		}
		return null;
	}

	private FL_SObjectNode ensureNode(UowContext context, SObject record) {
		for (NodeEntry entry : context.nodesByInstance) {
			if (entry.instance === record) {
				return entry.node;
			}
		}

		FL_SObjectNode node = new FL_SObjectNode(record);
		context.nodesByInstance.add(new NodeEntry(record, node));
		context.uow.registerNode(node);
		return node;
	}

	private void addRelation(UowContext context, FL_SObjectNode source, Schema.SObjectField lookupField, FL_SObjectNode target) {
		if (isRequiredLookup(lookupField)) {
			context.uow.addRequiredRelation(source, lookupField, target);
		} else {
			context.uow.addOptionalRelation(source, lookupField, target);
		}
	}

	private Boolean isRequiredLookup(Schema.SObjectField lookupField) {
		DescribeFieldResult describe = lookupField.getDescribe();
		return describe.isNillable() == false;
	}

	public class LookupWrapper {
		public FL_DataFactory dataFactory;
		public ParentMode parentMode;
		public LookupWrapper(FL_DataFactory dataFactory, ParentMode parentMode) {
			this.dataFactory = dataFactory;
			this.parentMode = parentMode;
		}
	}

	public class LookupBuilder {
		private List<LookupCondition> conditions = new List<LookupCondition>();
		private LookupWrapper elseWrapper;
		private Boolean hasExplicitElse;

		public LookupBuilder always(FL_DataFactory dataFactory, ParentMode parentMode) {
			conditions.add(new LookupCondition(ConditionType.ALWAYS, null, null, new LookupWrapper(dataFactory, parentMode)));
			return this;
		}

		public LookupBuilder equals(SObjectField field, Object value, FL_DataFactory dataFactory, ParentMode parentMode) {
			conditions.add(new LookupCondition(ConditionType.EQUALS, field, value, new LookupWrapper(dataFactory, parentMode)));
			return this;
		}

		public LookupBuilder biggerThan(SObjectField field, Object value, FL_DataFactory dataFactory, ParentMode parentMode) {
			conditions.add(new LookupCondition(ConditionType.GREATER_THAN, field, value, new LookupWrapper(dataFactory, parentMode)));
			return this;
		}

		public LookupBuilder lessThan(SObjectField field, Object value, FL_DataFactory dataFactory, ParentMode parentMode) {
			conditions.add(new LookupCondition(ConditionType.LESS_THAN, field, value, new LookupWrapper(dataFactory, parentMode)));
			return this;
		}

		public LookupBuilder biggerOrEqualsThan(SObjectField field, Object value, FL_DataFactory dataFactory, ParentMode parentMode) {
			conditions.add(new LookupCondition(ConditionType.GREATER_OR_EQUALS, field, value, new LookupWrapper(dataFactory, parentMode)));
			return this;
		}

		public LookupBuilder lessOrEqualsThan(SObjectField field, Object value, FL_DataFactory dataFactory, ParentMode parentMode) {
			conditions.add(new LookupCondition(ConditionType.LESS_OR_EQUALS, field, value, new LookupWrapper(dataFactory, parentMode)));
			return this;
		}

		public LookupBuilder elseWith(FL_DataFactory dataFactory, ParentMode parentMode) {
			this.elseWrapper = new LookupWrapper(dataFactory, parentMode);
			this.hasExplicitElse = true;
			return this;
		}

		public LookupWrapper resolve(SObject record) {
			for (LookupCondition condition : conditions) {
				if (condition.matches(record)) {
					return condition.wrapper;
				}
			}
			return elseWrapper;
		}

		public Boolean hasElse() {
			return hasExplicitElse;
		}
	}

	public class LookupsBuilders {
		private final Map<Schema.SObjectField, LookupBuilder> buildersByField;

		public LookupsBuilders() {
			this.buildersByField = new Map<Schema.SObjectField, LookupBuilder>();
		}

		public LookupFieldBuilder fill(Schema.SObjectField lookupField) {
			LookupBuilder builder = buildersByField.get(lookupField);
			if (builder == null) {
				builder = new LookupBuilder();
				buildersByField.put(lookupField, builder);
			}
			return new LookupFieldBuilder(this, lookupField, builder);
		}

		public Map<Schema.SObjectField, LookupBuilder> build() {
			for (Schema.SObjectField lookupField : new List<Schema.SObjectField>(buildersByField.keySet())) {
				LookupBuilder builder = buildersByField.get(lookupField);
				if (builder != null && builder.hasElse() == false) {
					builder.elseWith(null, ParentMode.DIFFERENT_PARENT);
				}
			}
			return buildersByField;
		}

	}

	public class LookupFieldBuilder {
		private final LookupsBuilders parent;
		private final Schema.SObjectField lookupField;
		private final LookupBuilder builder;

		public LookupFieldBuilder(LookupsBuilders parent, Schema.SObjectField lookupField, LookupBuilder builder) {
			this.parent = parent;
			this.lookupField = lookupField;
			this.builder = builder;
		}

		public LookupsBuilders alwaysWith(FL_DataFactory dataFactory) {
			return alwaysWith(dataFactory, ParentMode.DIFFERENT_PARENT);
		}

		public LookupsBuilders alwaysWith(FL_DataFactory dataFactory, ParentMode parentMode) {
			builder.always(dataFactory, parentMode);
			return parent;
		}

		public LookupConditionFieldBuilder when(SObjectField field) {
			return new LookupConditionFieldBuilder(parent, builder, field);
		}

		public LookupsBuilders elseWith(FL_DataFactory dataFactory) {
			return elseWith(dataFactory, ParentMode.DIFFERENT_PARENT);
		}

		public LookupsBuilders elseWith(FL_DataFactory dataFactory, ParentMode parentMode) {
			builder.elseWith(dataFactory, parentMode);
			return parent;
		}
	}

	public class LookupConditionFieldBuilder {
		private final LookupsBuilders parent;
		private final LookupBuilder builder;
		private final SObjectField field;

		public LookupConditionFieldBuilder(LookupsBuilders parent, LookupBuilder builder, SObjectField field) {
			this.parent = parent;
			this.builder = builder;
			this.field = field;
		}

		public LookupConditionValueBuilder equalTo(Object value) {
			return new LookupConditionValueBuilder(parent, builder, field, ConditionType.EQUALS, value);
		}

		public LookupConditionValueBuilder biggerThan(Object value) {
			return new LookupConditionValueBuilder(parent, builder, field, ConditionType.GREATER_THAN, value);
		}

		public LookupConditionValueBuilder lessThan(Object value) {
			return new LookupConditionValueBuilder(parent, builder, field, ConditionType.LESS_THAN, value);
		}

		public LookupConditionValueBuilder biggerOrEqualsThan(Object value) {
			return new LookupConditionValueBuilder(parent, builder, field, ConditionType.GREATER_OR_EQUALS, value);
		}

		public LookupConditionValueBuilder lessOrEqualsThan(Object value) {
			return new LookupConditionValueBuilder(parent, builder, field, ConditionType.LESS_OR_EQUALS, value);
		}
	}

	public class LookupConditionValueBuilder {
		private final LookupsBuilders parent;
		private final LookupBuilder builder;
		private final SObjectField field;
		private final ConditionType conditionType;
		private final Object value;

		public LookupConditionValueBuilder(LookupsBuilders parent, LookupBuilder builder, SObjectField field, ConditionType conditionType, Object value) {
			this.parent = parent;
			this.builder = builder;
			this.field = field;
			this.conditionType = conditionType;
			this.value = value;
		}

		public LookupsBuilders with(FL_DataFactory dataFactory) {
			return with(dataFactory, ParentMode.DIFFERENT_PARENT);
		}

		public LookupsBuilders with(FL_DataFactory dataFactory, ParentMode parentMode) {
			builder.conditions.add(new LookupCondition(conditionType, field, value, new LookupWrapper(dataFactory, parentMode)));
			return parent;
		}
	}

	public static LookupsBuilders lookupsBuilders() {
		return new LookupsBuilders();
	}

	public static UowContext newUowContext(FL_UnitOfWork uow) {
		return new UowContext(uow);
	}

	public static UowContext getOrCreateStaticContext() {
		if (STATIC_CONTEXT == null) {
			STATIC_CONTEXT = new UowContext();
		}
		return STATIC_CONTEXT;
	}

    public static void performDML(FL_UnitOfWork.Mode uowMode) {
        if (STATIC_CONTEXT != null) {
            STATIC_CONTEXT.uow.performDMLs(uowMode);
            STATIC_CONTEXT = null;
        }
    }

	public static void performDML() {
		if (STATIC_CONTEXT != null) {
			STATIC_CONTEXT.uow.performDMLs(FL_UnitOfWork.Mode.SINGLE_TYPE);
			STATIC_CONTEXT = null;
		}
	}

	public enum ConditionType {
		ALWAYS,
		EQUALS,
		GREATER_THAN,
		LESS_THAN,
		GREATER_OR_EQUALS,
		LESS_OR_EQUALS
	}

	private class LookupCondition {
		public final ConditionType inConditionType;
		public final SObjectField field;
		public final Object value;
		public final LookupWrapper wrapper;

		public LookupCondition(ConditionType inConditionType, SObjectField field, Object value, LookupWrapper wrapper) {
			this.inConditionType = inConditionType;
			this.field = field;
			this.value = value;
			this.wrapper = wrapper;
		}

		public Boolean matches(SObject record) {
			if (inConditionType == ConditionType.ALWAYS) {
				return true;
			}
			if (field == null || record == null) {
				return false;
			}
			Object recordValue = record.get(field.getDescribe().getName());
			if (inConditionType == ConditionType.EQUALS) {
				return System.equals(recordValue, value);
			}
			Integer compareResult = compareValues(recordValue, value);
			if (compareResult == null) {
				return false;
			}
			if (inConditionType == ConditionType.GREATER_THAN) {
				return compareResult > 0;
			}
			if (inConditionType == ConditionType.LESS_THAN) {
				return compareResult < 0;
			}
			if (inConditionType == ConditionType.GREATER_OR_EQUALS) {
				return compareResult >= 0;
			}
			if (inConditionType == ConditionType.LESS_OR_EQUALS) {
				return compareResult <= 0;
			}
			return false;
		}
	}

	private static Integer compareValues(Object left, Object right) {
		if (left == null || right == null) {
			return null;
		}
		if (isNumeric(left) && isNumeric(right)) {
			Decimal leftNum = toDecimal(left);
			Decimal rightNum = toDecimal(right);
			return compareUsingOperators(leftNum, rightNum);
		}
		if (left instanceof Date && right instanceof Date) {
			return compareUsingOperators((Date) left, (Date) right);
		}
		if (left instanceof Datetime && right instanceof Datetime) {
			return compareUsingOperators((Datetime) left, (Datetime) right);
		}
		if (left instanceof Time && right instanceof Time) {
			return compareUsingOperators((Time) left, (Time) right);
		}
		if (left instanceof String && right instanceof String) {
			return ((String) left).compareTo((String) right);
		}
		if (left instanceof Id && right instanceof Id) {
			return String.valueOf(left).compareTo(String.valueOf(right));
		}
		return null;
	}

	private static Boolean isNumeric(Object value) {
		return value instanceof Decimal || value instanceof Integer || value instanceof Long || value instanceof Double;
	}

	private static Decimal toDecimal(Object value) {
		if (value instanceof Decimal) {
			return (Decimal) value;
		}
		if (value instanceof Integer) {
			return Decimal.valueOf((Integer) value);
		}
		if (value instanceof Long) {
			return Decimal.valueOf((Long) value);
		}
		if (value instanceof Double) {
			return Decimal.valueOf((Double) value);
		}
		return null;
	}

	private static Integer compareUsingOperators(Decimal left, Decimal right) {
		if (left == right) {
			return 0;
		}
		return left > right ? 1 : -1;
	}

	private static Integer compareUsingOperators(Date left, Date right) {
		if (left == right) {
			return 0;
		}
		return left > right ? 1 : -1;
	}

	private static Integer compareUsingOperators(Datetime left, Datetime right) {
		if (left == right) {
			return 0;
		}
		return left > right ? 1 : -1;
	}

	private static Integer compareUsingOperators(Time left, Time right) {
		if (left == right) {
			return 0;
		}
		return left > right ? 1 : -1;
	}

	private class LookupAssignment {
		public final Schema.SObjectField lookupField;
		public final LookupWrapper wrapper;

		public LookupAssignment(Schema.SObjectField lookupField, LookupWrapper wrapper) {
			this.lookupField = lookupField;
			this.wrapper = wrapper;
		}

		public Boolean equals(Object obj) {
			if (this === obj) {
				return true;
			}
			if (!(obj instanceof LookupAssignment)) {
				return false;
			}
			LookupAssignment other = (LookupAssignment) obj;
			return System.equals(lookupField, other.lookupField)
				&& System.equals(wrapper?.dataFactory, other.wrapper?.dataFactory)
				&& System.equals(wrapper?.parentMode, other.wrapper?.parentMode);
		}

		public override Integer hashCode() {
			Integer hash = 17;
			hash = 31 * hash + System.hashCode(lookupField);
			hash = 31 * hash + System.hashCode(wrapper?.dataFactory);
			hash = 31 * hash + System.hashCode(wrapper?.parentMode);
			return hash;
		}
	}

	public enum ParentMode {
		SAME_PARENT,
		DIFFERENT_PARENT
	}

	public class UowContext {
		public final FL_UnitOfWork uow;
		public final List<NodeEntry> nodesByInstance;
		public final Map<FL_DataFactory, FL_SObjectNode> parentNodesByFactory;

		public UowContext() {
			this(new FL_UnitOfWork());
		}

		public UowContext(FL_UnitOfWork uow) {
			this.uow = uow;
			this.nodesByInstance = new List<NodeEntry>();
			this.parentNodesByFactory = new Map<FL_DataFactory, FL_SObjectNode>();
		}
	}

	private class NodeEntry {
		public final SObject instance;
		public final FL_SObjectNode node;

		public NodeEntry(SObject instance, FL_SObjectNode node) {
			this.instance = instance;
			this.node = node;
		}
	}
}
