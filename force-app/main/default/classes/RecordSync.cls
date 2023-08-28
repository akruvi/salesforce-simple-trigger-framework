/* Copyright: Amnon Kruvi, Kruvi Solutions, 30/08/2022 */
global abstract class RecordSync extends TriggerHandler implements Queueable {
    private Schema.DescribeSObjectResult objectType;
    private Map<String, Object> fieldMapping;
    private Map<String, Callable> callableCache;
    private List<SObject> records;

    private static Boolean isTest = Test.isRunningTest();
    
    global abstract Schema.DescribeSObjectResult getObjectType();
    global abstract Schema.DescribeFieldResult getChildRelationalField();
    global virtual Schema.DescribeFieldResult getParentRelationalField() {return null;}
    global virtual void postProcess(SObject record, SObject newRecord) {}
    global abstract Map<String, Object> getFieldMapping();

    private Object getParentValue(SObject record, Object value, String childField, List<SObject> allRecords) {
        //Process the value based on the type of object it is
        if (value instanceof Schema.SObjectField) {
            //Field: get the field value from the record
            return record.get((Schema.SObjectField)value);
        } else if (value instanceof Type) {
            //Class: instantiate and execute the class
            return runCallable(record, value, childField, allRecords);
        } else if (value instanceof Callable) {
            //Callable instance: execute the instance as-is
            return runCallableInstance(record, (Callable)value, childField, allRecords);
        }
        return value;
    }

    private Object runCallableInstance(SObject record, Callable callableInstance, String childField, List<SObject> allRecords) {
        return callableInstance.call('Calculate', new Map<String, Object> {
            'record' => record,
            'allRecords' => allRecords,
            'field' => childField
        });
    }

    private Object runCallable(SObject record, Object value, String childField, List<SObject> allRecords) {
        //Cache callables. This is so callables can query and cache their own data over multiple runs if they need to.
        if (callableCache == null) {
            callableCache = new Map<String, Callable>();
        }

        //Find callable instance in the cache
        Callable inst = callableCache.get(childField);

        if (inst == null) {
            //Not found in cache, instantiate a new one
            inst = (Callable)((Type)value).newInstance();
        }

        //Cache the callable instance
        callableCache.put(childField, inst);

        //Execute callable
        return runCallableInstance(record, inst, childField, allRecords);
    }

    global virtual Boolean shouldSync(SObject record) {
        //Override this method to determine which parent records should synchronise (assume all)
        return true;
    }

    global virtual Boolean isAsynchronous(List<SObject> records) {
        //Override this method to create asynchronous synchronisation
        return false;
    }

    public override void afterInsert() {
        synchronise(Trigger.new);
    }

    public override void afterUndelete() {
        afterInsert();
    }

    private Map<Object[], SObject> loadExistingRecords(List<SObject> records, String idField, String parentRelationalField) {
        //Make a list of fields we need to query from the child object
        Set<String> childFields = new Set<String>();
        for (String childField : fieldMapping.keySet()) {
            childFields.add(childField.toLowerCase());
        }
        childFields.add(idField.toLowerCase());
        childFields.add('id');

        //If the records are linked on the parent side as well, query those directly (to allow bi-directional sync)
        Set<Id> directlyRelatedRecords = new Set<Id>();
        if (parentRelationalField != null) {
            for (SObject record : records) {
                Id idValue = (Id)record.get(parentRelationalField);
                if (idValue != null) {
                    directlyRelatedRecords.add(idValue);
                }
            }
        }

        //Query all the existing child records alongside their field values
        List<SObject> childRecords;
        try {
            childRecords = Database.Query('SELECT ' + String.join(new List<String>(childFields), ',') + ' FROM ' + objectType.getName() + ' WHERE ' + idField + ' IN :records OR Id IN :directlyRelatedRecords');
        } catch (QueryException e) {
            //This could happen if the ID field was also mapped to another field but without the namespace
            childFields.remove(idField.toLowerCase());
            childRecords = Database.Query('SELECT ' + String.join(new List<String>(childFields), ',') + ' FROM ' + objectType.getName() + ' WHERE ' + idField + ' IN :records OR Id IN :directlyRelatedRecords');
        }

        //Map records by parent ID
        Map<Object[], SObject> mapChildren = new Map<Object[], SObject>();
        for (SObject child : childRecords) {
            Id idValue = (Id)child.get(idField);

            //Map the child record by the parent ID
            mapChildren.put(new Object[] {1, idValue}, child);
            
            //Map the child record by its record ID
            mapChildren.put(new Object[] {2, child.Id}, child);
        }

        return mapChildren;
    }

    public override void afterUpdate() {
        synchronise(Trigger.new);
    }

    global void synchronise(List<SObject> newRecords) {
        //If we're running in a synchronous context, and the
        //process is meant to run asynchronously, call the
        //future method. Otherwise, run it immediately.
        if (!System.isFuture() && 
            !System.isBatch() &&
            !System.isQueueable() &&
            !System.isScheduled() &&
            isAsynchronous(newRecords)) {
            //Asynchronous
            synchroniseFuture(newRecords);
        } else {
            //Synchronous
            synchroniseNow(newRecords);
        }
    }

    global void synchroniseFuture(List<SObject> newRecords) {
        //Enqueue this job for future processing
        this.records = newRecords;
        System.enqueueJob(this);
    }

    public void execute(QueueableContext ctx) {
        //Process enqueued records
        synchroniseNow(this.records);
    }

    global void synchroniseNow(List<SObject> newRecords) {
        this.objectType = this.getObjectType();
        this.fieldMapping = this.getFieldMapping();

        List<SObject> toDelete = new List<SObject>();
        List<SObject> toUpdate = new List<SObject>();
        List<SObject> toInsert = new List<SObject>();

        //Load existing child records relating to the changed records
        String idField = this.getChildRelationalField().getName();
        String parentRelationalField = getParentRelationalField()?.getName();
        Map<Object[], SObject> mapChildren = loadExistingRecords(newRecords, idField, parentRelationalField);

        //Iterate over the records to see which ones changed
        Schema.SObjectType objType = objectType.getSObjectType();
        Integer cnt = newRecords.size();
        
        for (Integer i=0;i < cnt;i++) {
            SObject newRec = newRecords[i];

            //Fetch child record
            SObject childRecord = mapChildren.get(new Object[] {1, newRec.Id});
            if (childRecord == null && 
                parentRelationalField != null) {
                //Child record not found, but there is a parent relationship: look for the record from there
                Id childRecordId = (Id)newRec.get(parentRelationalField);
                if (childRecordId != null) {
                    childRecord = mapChildren.get(new Object[] {2, childRecordId});
                }
            }

            if (this.shouldSync(newRec)) {
                if (childRecord != null) {
                    //Child record found. Check each field on the parent to see if there was a change.
                    Boolean changed = false;
                    for (String childField : fieldMapping.keySet()) {
                        Object parentField = fieldMapping.get(childField);

                        //Calculate new value
                        Object newValue = getParentValue(newRec, parentField, childField, newRecords);

                        if (newValue != childRecord.get(childField)) {
                            //Change found, update child record
                            changed = true;
                            childRecord.put(
                                childField, 
                                newValue
                            );
                        }
                    }

                    if (changed == true) {
                        toUpdate.add(childRecord);
                    }
                } else {
                    //Child record not found. Create one.
                    childRecord = objType.newSObject();

                    //Copy all the fields from the parent to child record
                    for (String childField : fieldMapping.keySet()) {
                        Object parentField = fieldMapping.get(childField);
                        childRecord.put(
                            childField, 
                            getParentValue(newRec, parentField, childField, newRecords)
                        );
                    }

                    toInsert.add(childRecord);
                }
            } else {
                //Child record, if it exists, should be deleted
                if (childRecord != null) {
                    toDelete.add(childRecord);
                }
            }
        }
        
        Database.update(toUpdate, isTest);
        Database.insert(toInsert, isTest);
        Database.delete(toDelete, isTest);

        //Link the parent to any newly created child records
        if (parentRelationalField != null) {
            toUpdate = new List<SObject>();

            //Map all records by ID
            Map<Id, SObject> newRecordsMap = new Map<Id, SObject>();
            for (SObject record : newRecords) {
                newRecordsMap.put(record.Id, record);
            }

            //Copy the newly-created child record IDs to a field on the parent
            for (SObject newRecord : toInsert) {
                Id parentId = (Id)newRecord.get(getChildRelationalField().getSobjectField());
                SObject parent = newRecordsMap.get(parentId);
                if (parent != null && parent.get(parentRelationalField) != newRecord.Id) {
                    SObject recordToUpdate = newRecords[0].getSObjectType().newSObject(parentId);
                    recordToUpdate.put(parentRelationalField, newRecord.Id);
                    toUpdate.add(recordToUpdate);
                }
            }

            Database.update(toUpdate, isTest);
        }
    }

    public override void beforeDelete() {
        this.objectType = this.getObjectType();
        this.fieldMapping = this.getFieldMapping();

        //Delete associated child records
        String idField = this.getChildRelationalField().getName();
        List<SObject> records = Trigger.old;
        Database.delete(Database.Query('SELECT Id FROM ' + objectType.getName() + ' WHERE ' + idField + ' IN :records'), isTest);
    }
}