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
            for (SObject loopRecord : sObjectRecords) {
                addLookups(new LookupContext(context, ensureNode(context, loopRecord)));
            }
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

    protected virtual void addLookups(LookupContext lookupContext) {
    }

    public class LookupContext {
        private final UowContext uowContext;
        private final FL_SObjectNode currentNode;

        private LookupContext(UowContext uowContext, FL_SObjectNode currentNode) {
            this.uowContext = uowContext;
            this.currentNode = currentNode;
        }

        public FL_SObjectNode node() {
            return currentNode;
        }

        public SObject record() {
            return currentNode?.instance;
        }

        public void addMissingRequiredLookup(Schema.SObjectField lookupField, FL_SObjectNode parentNode) {
            if (!isLookupMissing(lookupField)) {
                return;
            }
            uowContext.uow.addRequiredRelation(currentNode, lookupField, parentNode);
        }

        public void addMissingRequiredLookup(Schema.SObjectField lookupField, SObject parentRecord) {
            if (!isLookupMissing(lookupField)) {
                return;
            }
            FL_SObjectNode parentNode = ensureNodeLocal(parentRecord);
            uowContext.uow.addRequiredRelation(currentNode, lookupField, parentNode);
        }

        public void addMissingOptionalLookup(Schema.SObjectField lookupField, FL_SObjectNode parentNode) {
            if (!isLookupMissing(lookupField)) {
                return;
            }
            uowContext.uow.addOptionalRelation(currentNode, lookupField, parentNode);
        }

        public void addMissingOptionalLookup(Schema.SObjectField lookupField, SObject parentRecord) {
            if (!isLookupMissing(lookupField)) {
                return;
            }
            FL_SObjectNode parentNode = ensureNodeLocal(parentRecord);
            uowContext.uow.addOptionalRelation(currentNode, lookupField, parentNode);
        }

        public void addMissingLookup(Schema.SObjectField lookupField, FL_SObjectNode parentNode) {
            if (!isLookupMissing(lookupField)) {
                return;
            }
            uowContext.uow.addRequiredRelation(currentNode, lookupField, parentNode);
        }

        public void addMissingLookup(Schema.SObjectField lookupField, SObject parentRecord) {
            if (!isLookupMissing(lookupField)) {
                return;
            }
            FL_SObjectNode parentNode = ensureNodeLocal(parentRecord);
            uowContext.uow.addRequiredRelation(currentNode, lookupField, parentNode);
        }

        public void addMissingLookup(Schema.SObjectField lookupField, FL_DataFactory dataFactory) {
            addMissingLookup(lookupField, dataFactory, ParentMode.DIFFERENT_PARENT);
        }

        public void addMissingLookup(Schema.SObjectField lookupField, FL_DataFactory dataFactory, ParentMode parentMode) {
            if (!isLookupMissing(lookupField)) {
                return;
            }

            FL_SObjectNode parentNode;
            if (parentMode == FL_DataFactory.ParentMode.SAME_PARENT) {
                parentNode = uowContext.parentNodesByFactory.get(dataFactory);
                if (parentNode == null) {
                    SObject parentObject = dataFactory.composeRecords(1, null, null, null, uowContext)[0];
                    parentNode = ensureNodeLocal(parentObject);
                    uowContext.parentNodesByFactory.put(dataFactory, parentNode);
                }
            } else {
                SObject parentObject = dataFactory.composeRecords(1, null, null, null, uowContext)[0];
                parentNode = ensureNodeLocal(parentObject);
            }

            if (isFieldCompatibleWithNode(lookupField, parentNode)) {
                uowContext.uow.addRequiredRelation(currentNode, lookupField, parentNode);
            }
        }

        private Boolean isFieldCompatibleWithNode(Schema.SObjectField lookupField, FL_SObjectNode parentNode) {
            List<SObjectType> referencedToTypes = lookupField.getDescribe().getReferenceTo();
            return referencedToTypes?.contains(parentNode.getSObjectType()) == true;
        }

        private FL_SObjectNode ensureNodeLocal(SObject recordToEnsure) {
            for (NodeEntry entry : uowContext.nodesByInstance) {
                if (entry.instance === recordToEnsure) {
                    return entry.node;
                }
            }

            FL_SObjectNode node = new FL_SObjectNode(recordToEnsure);
            uowContext.nodesByInstance.add(new NodeEntry(recordToEnsure, node));
            uowContext.uow.registerNode(node);
            return node;
        }

        private Boolean isLookupMissing(Schema.SObjectField lookupField) {
            return record() != null && record().get(lookupField.getDescribe().getName()) == null;
        }
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
