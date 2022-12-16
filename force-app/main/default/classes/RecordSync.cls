/* Copyright: Amnon Kruvi, Kruvi Solutions, 30/08/2022 */
global abstract class RecordSync extends TriggerHandler {
    global abstract Schema.DescribeSObjectResult getObjectType();
    global abstract Schema.DescribeFieldResult getChildRelationalField();
    global virtual Schema.DescribeFieldResult getParentRelationalField() {return null;}
    global virtual void postProcess(SObject record, SObject newRecord) {}
    global abstract Map<String, Object> getFieldMapping();

    private Schema.DescribeSObjectResult OBJECT_TYPE;
    private Map<String, Object> FIELD_MAPPING;
    private Map<String, Callable> CALLABLE_CACHE;

    private Object getParentValue(SObject record, Object value, String childField, List<SObject> allRecords) {
        if (value instanceof Schema.SObjectField) {
            return record.get((Schema.SObjectField)value);
        } else if (value instanceof Type) {
            return runCallable(record, value, childField, allRecords);
        }
        return value;
    }

    private Object runCallable(SObject record, Object value, String childField, List<SObject> allRecords) {
        //Cache callables. This is so callables can query and cache their own data over multiple runs if they need to.
        if (CALLABLE_CACHE == null) {
            CALLABLE_CACHE = new Map<String, Callable>();
        }

        //Find callable instance in the cache
        Callable inst = CALLABLE_CACHE.get(childField);

        if (inst == null) {
            //Not found in cache, instantiate a new one
            inst = (Callable)((Type)value).newInstance();
        }

        //Cache the callable instance
        CALLABLE_CACHE.put(childField, inst);

        //Execute callable
        return inst.call('Calculate', new Map<String, Object> {
            'record' => record,
            'allRecords' => allRecords
        });
    }

    global virtual Boolean shouldSync(SObject record) {
        return true;
    }

    public override void afterInsert() {
        this.OBJECT_TYPE = this.getObjectType();
        this.FIELD_MAPPING = this.getFieldMapping();

        //Create a corresponding child record for each parent
        List<SObject> newRecords = new List<SObject>();
        Schema.SObjectType objType = OBJECT_TYPE.getSObjectType();

        for (SObject record : Trigger.new) {
            //Check whether the record should be synchronised with another
            if (!this.shouldSync(record)) {
                continue;
            }

            //Instantiate a new record
            SObject newRecord = objType.newSObject();

            //Copy all the fields from the parent to child record
            for (String childField : FIELD_MAPPING.keySet()) {
                Object parentField = FIELD_MAPPING.get(childField);
                Object value = getParentValue(record, parentField, childField, Trigger.new);

                newRecord.put(childField, value);
            }

            postProcess(record, newRecord);

            newRecords.add(newRecord);
        }
        Database.insert(newRecords, false);

        Schema.DescribeFieldResult parentRelationalField = getParentRelationalField();
        if (parentRelationalField != null) {
            List<SObject> toUpdate = new List<SObject>();

            //Copy the newly-created child record IDs to a field on the parent
            for (SObject newRecord : newRecords) {
                Id parentId = (Id)newRecord.get(getChildRelationalField().getSobjectField());
                SObject recordToUpdate = Trigger.new[0].getSObjectType().newSObject(parentId);
                recordToUpdate.put(parentRelationalField.getSobjectField(), newRecord.Id);
                toUpdate.add(recordToUpdate);
            }

            Database.update(toUpdate, false);
        }
    }

    public override void afterUndelete() {
        afterInsert();
    }

    private Map<Id, SObject> loadExistingRecords(String idField) {
        //Make a list of fields we need to query from the child object
        Set<String> childFields = new Set<String>();
        for (String childField : FIELD_MAPPING.keySet()) {
            childFields.add(childField.toLowerCase());
        }
        childFields.add(idField.toLowerCase());
        childFields.add('id');

        //Query all the existing child records alongside their field values
        List<SObject> childRecords;
        List<SObject> newRecords = Trigger.new;
        try {
            childRecords = Database.Query('SELECT ' + String.join(new List<String>(childFields), ',') + ' FROM ' + OBJECT_TYPE.getName() + ' WHERE ' + idField + ' IN :newRecords');
        } catch (QueryException e) {
            //This could happen if the ID field was also mapped to another field but without the namespace
            childFields.remove(idField.toLowerCase());
            childRecords = Database.Query('SELECT ' + String.join(new List<String>(childFields), ',') + ' FROM ' + OBJECT_TYPE.getName() + ' WHERE ' + idField + ' IN :newRecords');
        }

        //Map records by parent ID
        Map<Id, SObject> mapChildren = new Map<Id, SObject>();
        for (SObject child : childRecords) {
            mapChildren.put((Id)child.get(idField), child);
        }

        return mapChildren;
    }

    public override void afterUpdate() {
        this.OBJECT_TYPE = this.getObjectType();
        this.FIELD_MAPPING = this.getFieldMapping();

        List<SObject> toDelete = new List<SObject>();
        List<SObject> toUpdate = new List<SObject>();
        List<SObject> toInsert = new List<SObject>();

        //Load existing child records relating to the changed records
        String idField = this.getChildRelationalField().getName();
        Map<Id, SObject> mapChildren = loadExistingRecords(idField);

        //Iterate over the records to see which ones changed
        Schema.SObjectType objType = OBJECT_TYPE.getSObjectType();
        Integer cnt = Trigger.new.size();
        
        for (Integer i=0;i < cnt;i++) {
            SObject newRec = Trigger.new[i],
                    oldRec = Trigger.old[i];

            //Fetch child record
            SObject childRecord = mapChildren.get(newRec.Id);

            if (this.shouldSync(newRec)) {
                if (childRecord != null) {
                    //Child record found. Check each field on the parent to see if there was a change.
                    Boolean changed = false;
                    for (String childField : FIELD_MAPPING.keySet()) {
                        Object parentField = FIELD_MAPPING.get(childField);

                        //Calculate new value
                        Object newValue = getParentValue(newRec, parentField, childField, Trigger.new);

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
                    for (String childField : FIELD_MAPPING.keySet()) {
                        Object parentField = FIELD_MAPPING.get(childField);
                        childRecord.put(
                            childField, 
                            getParentValue(newRec, parentField, childField, Trigger.new)
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
        
        Database.update(toUpdate, false);
        Database.insert(toInsert, false);
        Database.delete(toDelete, false);

        //Link the parent to any newly created child records
        Schema.DescribeFieldResult parentRelationalField = getParentRelationalField();
        if (parentRelationalField != null) {
            toUpdate = new List<SObject>();

            //Copy the newly-created child record IDs to a field on the parent
            for (SObject newRecord : toInsert) {
                Id parentId = (Id)newRecord.get(getChildRelationalField().getSobjectField());
                SObject recordToUpdate = Trigger.new[0].getSObjectType().newSObject(parentId);
                recordToUpdate.put(parentRelationalField.getSobjectField(), newRecord.Id);
                toUpdate.add(recordToUpdate);
            }

            Database.update(toUpdate, false);
        }
    }

    public override void beforeDelete() {
        this.OBJECT_TYPE = this.getObjectType();
        this.FIELD_MAPPING = this.getFieldMapping();

        //Delete associated child records
        String idField = this.getChildRelationalField().getName();
        List<SObject> records = Trigger.old;
        Database.delete(Database.Query('SELECT Id FROM ' + OBJECT_TYPE.getName() + ' WHERE ' + idField + ' IN :records'), false);
    }
}