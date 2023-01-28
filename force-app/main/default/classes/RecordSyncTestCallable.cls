public with sharing class RecordSyncTestCallable implements Callable {
    public String call(String method, Map<String, Object> params) {
        //This class is called as part of the unit test

        //Verify we have the right parameters coming in
        String field = (String)params.get('field');
        List<SObject> allRecords = (List<SObject>)params.get('allRecords');
        SObject record = (SObject)params.get('record');

        Assert.isTrue(record instanceof Case, 'The record that came in was not a Case: ' + record.getSObjectType().getDescribe().getName());
        Assert.areEqual(5, allRecords.size(), 'We expect the same number of tasks to come into the class as are created in the unit test');

        //Return a value based on the field
        if (field == 'Status') {
            //For the status field, return In Progress
            return 'In Progress';
        } else if (field == 'Priority') {
            //For priority, return High
            return 'High';
        } else {
            Assert.fail('Unexpected field name: ' + field);
        }
        return null;
    }
}
