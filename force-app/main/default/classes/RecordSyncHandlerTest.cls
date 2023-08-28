public without sharing class RecordSyncHandlerTest extends RecordSync {
    public static Boolean TEST_RECORD_SYNC = false;
    public static Boolean ASYNC_MODE = false;

    public override Schema.DescribeSObjectResult getObjectType() {
        return Schema.SObjectType.Task;
    }

    public override Schema.DescribeFieldResult getChildRelationalField() {
        return Schema.SObjectType.Task.fields.WhatId;
    }

    public override Boolean shouldSync(SObject record) {
        return (String)record.get('Subject') != 'Delete me';
    }

    public override Boolean isAsynchronous(List<SObject> records) {
        return ASYNC_MODE;
    }

    public override Map<String, Object> getFieldMapping() {
        return new Map<String, Object> {
            'Subject' => 'Complete the case',
            'WhatId' => Case.fields.Id,
            'Description' => Case.fields.Subject,
            'Status' => RecordSyncTestCallable.class,
            'Priority' => new RecordSyncTestCallable()
        };
    }
}