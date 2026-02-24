public inherited sharing abstract class FL_DataFactory {
	private static final Map<SObjectType, Integer> COUNT_MAP = new Map<SObjectType, Integer>();
    @TestVisible
	private static UowContext STATIC_CONTEXT;
	private SObjectType factorySObjectType;

	/**
	 * Returns a default record instance for this factory.
	 *
	 * @param index Sequential index used to build deterministic values.
	 * @return Default SObject instance for the current factory type.
	 */
	protected abstract SObject getDefaultRecord(Integer index);

	/**
	 * Applies conditional assignment logic after base values are set and the record is added to the output list.
	 * Use this hook for type-specific and record-type-specific branching (for example:
	 * `if (record.getSObjectType() == Contact.SObjectType)` and, when available on the object,
	 * checking `record.get('RecordTypeId')` after verifying the field exists in describe metadata).
	 *
	 * @param sObjectRecord The record being composed.
	 */
    protected virtual void assignConditionally(SObject sObjectRecord) {
    }

	/**
	 * Adds missing lookup relationships for the composed record.
	 *
	 * @param lookupContext Context wrapper for the current record and unit-of-work graph.
	 */
    protected virtual void addLookups(LookupContext lookupContext) {
    }

	private SObjectType getSobjectType() {
		if (factorySObjectType == null) {
			factorySObjectType = getSobjectType(getDefaultRecord(0));
		}
		return factorySObjectType;
	}

	private sObjectType getSobjectType(SObject objectRecord) {
		return objectRecord?.getSObjectType();
	}

	/**
	 * Composes and inserts a single default record.
	 *
	 * @return Inserted record instance.
	 */
	public SObject insertRecord() {
		return insertRecords(1)[0];
	}

	/**
	 * Composes and inserts a single record with shared override values.
	 *
	 * @param overrideValuesForAll Values to apply to all records being composed.
	 * @return Inserted record instance.
	 */
	public SObject insertRecord(SObject overrideValuesForAll) {
		return insertRecords(1, overrideValuesForAll, null)[0];
	}

	/**
	 * Composes and inserts multiple default records.
	 *
	 * @param recordsNumber Number of records to create.
	 * @return Inserted record instances.
	 */
	public List<SObject> insertRecords(Integer recordsNumber) {
		return insertRecords(recordsNumber, null, null);
	}

	/**
	 * Composes and inserts multiple records with optional shared and per-record overrides.
	 *
	 * @param recordsNumber Number of records to create.
	 * @param overrideValuesForAll Values to apply to all records.
	 * @param overrideValuesForEach Values to apply per index.
	 * @return Inserted record instances.
	 */
	public List<SObject> insertRecords(Integer recordsNumber, SObject overrideValuesForAll, List<SObject> overrideValuesForEach) {
		List<SObject> sObjectRecords = composeRecords(recordsNumber, overrideValuesForAll, overrideValuesForEach);
		performDML();
		return sObjectRecords;
	}

	/**
	 * Composes a single default record without DML.
	 *
	 * @return Composed record instance.
	 */
	public SObject composeRecords() {
		return composeRecords(1)[0];
	}

	/**
	 * Composes a single record with shared override values without DML.
	 *
	 * @param overrideValuesForAll Values to apply to the composed record.
	 * @return Composed record instance.
	 */
	public SObject composeRecords(SObject overrideValuesForAll) {
		return composeRecords(1, overrideValuesForAll, null)[0];
	}

    /**
     * Composes one record and returns its node in the static context.
     *
     * @param inSObject Override values for the composed record.
     * @return Node wrapping the composed record.
     */
    public FL_SObjectNode composeNode(SObject inSObject) {
        UowContext context = getOrCreateStaticContext();
        return composeNode(inSObject, context);
    }

    /**
     * Composes one record and returns its node in the provided context.
     *
     * @param inSObject Override values for the composed record.
     * @param context Unit-of-work context to compose into.
     * @return Node wrapping the composed record.
     */
    public FL_SObjectNode composeNode(SObject inSObject, UowContext context) {
        SObject composedRecord = composeRecords(1, inSObject, null, context)[0];
        return ensureNode(context, composedRecord);
    }

	/**
	 * Composes multiple default records without DML.
	 *
	 * @param recordsNumber Number of records to create.
	 * @return Composed record instances.
	 */
	public List<SObject> composeRecords(Integer recordsNumber) {
		return composeRecords(recordsNumber, null, null);
	}

	/**
	 * Composes multiple records using static context without DML.
	 *
	 * @param recordsNumber Number of records to create.
	 * @param overrideValuesForAll Values to apply to all records.
	 * @param overrideValuesForEach Values to apply per index.
	 * @return Composed record instances.
	 */
	public List<SObject> composeRecords(Integer recordsNumber, SObject overrideValuesForAll, List<SObject> overrideValuesForEach) {
		UowContext context = getOrCreateStaticContext();
		return composeRecords(recordsNumber, overrideValuesForAll, overrideValuesForEach, context);
	}

	/**
	 * Composes multiple records in the provided context without DML.
	 * This method always invokes {@code assignConditionally} per record after shared/per-record overrides are applied.
	 *
	 * @param recordsNumber Number of records to create.
	 * @param overrideValuesForAll Values to apply to all records.
	 * @param overrideValuesForEach Values to apply per index.
	 * @param context Unit-of-work context to compose into.
	 * @return Composed record instances.
	 */
	public List<SObject> composeRecords(Integer recordsNumber, SObject overrideValuesForAll, List<SObject> overrideValuesForEach, UowContext context) {
		List<SObject> sObjectRecords = new List<SObject>();
		Map<String, Object> mapOfValuesForAll = convertValuesIntoMap(overrideValuesForAll);
		List<Map<String, Object>> listMapOfValuesForEach = convertValuesIntoListOfMap(overrideValuesForEach);

		if (recordsNumber > 0 && listSizeEqualToRecordNumber(recordsNumber, overrideValuesForEach) && objectTypesAreEqual(overrideValuesForAll, overrideValuesForEach)) {
			Integer initialCounter = initiateCounter();

			for (Integer index = 0; index < recordsNumber; index++) {
				SObject sObjectRecord = getDefaultRecord(index + initialCounter);
				if (overrideValuesForAll != null) {
					assignValuesToObject(sObjectRecord, mapOfValuesForAll);
				}
				if (overrideValuesForEach != null) {
					assignValuesToObject(sObjectRecord, listMapOfValuesForEach[index]);
				}
				sObjectRecords.add(sObjectRecord);
                assignConditionally(sObjectRecord);
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

    public class LookupContext {
        private final UowContext uowContext;
        private final FL_SObjectNode currentNode;

        private LookupContext(UowContext uowContext, FL_SObjectNode currentNode) {
            this.uowContext = uowContext;
            this.currentNode = currentNode;
        }

        /**
         * Returns the current node being processed.
         *
         * @return Current node.
         */
        public FL_SObjectNode node() {
            return currentNode;
        }

        /**
         * Returns the current record instance.
         *
         * @return Current SObject instance.
         */
        public SObject record() {
            return currentNode?.instance;
        }

        /**
         * Adds a required lookup when the field is currently null.
         *
         * @param lookupField Lookup field to populate.
         * @param parentNode Parent node to relate.
         */
        public void addMissingRequiredLookup(Schema.SObjectField lookupField, FL_SObjectNode parentNode) {
            if (!isLookupMissing(lookupField)) {
                return;
            }
            uowContext.uow.addRequiredRelation(currentNode, lookupField, parentNode);
        }

        /**
         * Adds a required lookup when the field is currently null.
         *
         * @param lookupField Lookup field to populate.
         * @param parentRecord Parent record to relate.
         */
        public void addMissingRequiredLookup(Schema.SObjectField lookupField, SObject parentRecord) {
            if (!isLookupMissing(lookupField)) {
                return;
            }
            FL_SObjectNode parentNode = ensureNodeLocal(parentRecord);
            uowContext.uow.addRequiredRelation(currentNode, lookupField, parentNode);
        }

        /**
         * Adds an optional lookup when the field is currently null.
         *
         * @param lookupField Lookup field to populate.
         * @param parentNode Parent node to relate.
         */
        public void addMissingOptionalLookup(Schema.SObjectField lookupField, FL_SObjectNode parentNode) {
            if (!isLookupMissing(lookupField)) {
                return;
            }
            uowContext.uow.addOptionalRelation(currentNode, lookupField, parentNode);
        }

        /**
         * Adds an optional lookup when the field is currently null.
         *
         * @param lookupField Lookup field to populate.
         * @param parentRecord Parent record to relate.
         */
        public void addMissingOptionalLookup(Schema.SObjectField lookupField, SObject parentRecord) {
            if (!isLookupMissing(lookupField)) {
                return;
            }
            FL_SObjectNode parentNode = ensureNodeLocal(parentRecord);
            uowContext.uow.addOptionalRelation(currentNode, lookupField, parentNode);
        }

        /**
         * Adds a required lookup when the field is currently null.
         *
         * @param lookupField Lookup field to populate.
         * @param parentNode Parent node to relate.
         */
        public void addMissingLookup(Schema.SObjectField lookupField, FL_SObjectNode parentNode) {
            if (!isLookupMissing(lookupField)) {
                return;
            }
            uowContext.uow.addRequiredRelation(currentNode, lookupField, parentNode);
        }

        /**
         * Adds a required lookup when the field is currently null.
         *
         * @param lookupField Lookup field to populate.
         * @param parentRecord Parent record to relate.
         */
        public void addMissingLookup(Schema.SObjectField lookupField, SObject parentRecord) {
            if (!isLookupMissing(lookupField)) {
                return;
            }
            FL_SObjectNode parentNode = ensureNodeLocal(parentRecord);
            uowContext.uow.addRequiredRelation(currentNode, lookupField, parentNode);
        }

        /**
         * Adds a required lookup to a parent composed by another factory using default parent mode.
         *
         * @param lookupField Lookup field to populate.
         * @param dataFactory Parent factory used to compose parent record.
         */
        public void addMissingLookup(Schema.SObjectField lookupField, FL_DataFactory dataFactory) {
            addMissingLookup(lookupField, dataFactory, ParentMode.DIFFERENT_PARENT);
        }

        /**
         * Adds a required lookup to a parent composed by another factory using the requested parent mode.
         *
         * @param lookupField Lookup field to populate.
         * @param dataFactory Parent factory used to compose parent record.
         * @param parentMode Controls whether parents are reused or composed per child.
         */
        public void addMissingLookup(Schema.SObjectField lookupField, FL_DataFactory dataFactory, ParentMode parentMode) {
            if (!isLookupMissing(lookupField)) {
                return;
            }

            FL_SObjectNode parentNode;
            if (parentMode == FL_DataFactory.ParentMode.SAME_PARENT) {
                parentNode = uowContext.parentNodesByFactory.get(dataFactory);
                if (parentNode == null) {
                    SObject parentObject = dataFactory.composeRecords(1, null, null, uowContext)[0];
                    parentNode = ensureNodeLocal(parentObject);
                    uowContext.parentNodesByFactory.put(dataFactory, parentNode);
                }
            } else {
                SObject parentObject = dataFactory.composeRecords(1, null, null, uowContext)[0];
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

	/**
	 * Creates a new unit-of-work context backed by the provided UoW instance.
	 *
	 * @param uow Unit-of-work implementation to use.
	 * @return New context instance.
	 */
	public static UowContext newUowContext(FL_UnitOfWork uow) {
		return new UowContext(uow);
	}

	/**
	 * Returns the static context, creating it when needed.
	 *
	 * @return Existing or newly created static context.
	 */
	public static UowContext getOrCreateStaticContext() {
		if (STATIC_CONTEXT == null) {
			STATIC_CONTEXT = new UowContext();
		}
		return STATIC_CONTEXT;
	}

    /**
     * Performs DML for all records in static context using the provided mode, then clears static context.
     *
     * @param uowMode DML execution mode.
     */
    public static void performDML(FL_UnitOfWork.Mode uowMode) {
        if (STATIC_CONTEXT != null) {
            STATIC_CONTEXT.uow.performDMLs(uowMode);
            STATIC_CONTEXT = null;
        }
    }

	/**
	 * Performs DML for all records in static context using single-type mode, then clears static context.
	 */
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

		/**
		 * Creates a context with a new default unit of work.
		 */
		public UowContext() {
			this(new FL_UnitOfWork());
		}

		/**
		 * Creates a context using a provided unit-of-work instance.
		 *
		 * @param uow Unit-of-work implementation to use.
		 */
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
