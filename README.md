# Salesforce Simple Trigger Framework and Record Sync

A simplified trigger framework to extract logic from triggers, with uni-directional data synchronisation built-in.

## Deployment

<a href="https://githubsfdeploy.herokuapp.com/app/githubdeploy/akruvi/salesforce-simple-trigger-framework">
  <img src="https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/src/main/webapp/resources/img/deploy.png" alt="Deploy to Salesforce" />
</a>

## How do I make a trigger?

Start by creating a trigger handler class. This must extend the TriggerHandler class:
```Apex
public without sharing class MyTriggerHandler extends TriggerHandler {
}
```

The following methods are available to override:
+ beforeInsert
+ beforeUpdate
+ beforeDelete
+ beforeUndelete
+ afterInsert
+ afterUpdate
+ afterDelete
+ afterUndelete

For example:
```Apex
public override void beforeUpdate() {
    //Get new and old records
    List<Case> newCases = (List<Case>)Trigger.new,
               oldCases = (List<Case>)Trigger.old;

    //Do some stuff here
}
```

Next, create a trigger for the object and instantiate your trigger handler:
```Apex
trigger ScheduleObjectTrigger on Case(before update) {
    new MyTriggerHandler();
}
```

Done. Simple, right?

## Exception Handling

By default, exceptions in the trigger are thrown back and crash the current transaction. The error handler can be overridden to implement custom functionality or to ignore the exception altogether:

```Apex
public override void onError(Exception e) {
    //Handle exception here
}
```

My personal approach is that most trigger errors should not block the entire transaction, so creating an onError handler that does not throw the exception (and perhaps logs or reports it via email) is recommended. But I'm not your mother, I can't tell you what to do.

## Enabling and Disabling Trigger Functionality via Metadata

The provided custom metadata type can be used to enable or disable triggers.
Enter Setup -> Custom Metadata Types and select the Trigger Controller object.
Create a new record. In the Master Label field, enter the name of your trigger handler class (for example: MyTriggerHandler).
Use the checkboxes to activate or deactivate specific trigger events.

## About Uni-Directional Record Synchronisation

This feature allows you to create a trigger on any object that creates a parallel, always-synchronised record in another object.
This is great for synchronising data between two applications on the platform.

Child record values can come from the parent record, from hard-coded values, or from a Callable Apex class. Callable Apex classes are cached for increased performance.

Synchronisation handles the following events:

### Record Creation
When a parent record is created, a synchronised (child) record is created.

### Record Update
When a parent record is updated, if a child record already exists, it will also be updated. Otherwise, it will be created.

### Record Deletion
When a parent record is deleted, the child record is deleted.

### Record Undeletion
When a record is undeleted, a child record is re-created (not restored from the recycle bin, at least at this stage).

## Synchronisation Example

Here is a test class that shows how easy it is to synchronise two records:
```Apex
public without sharing class SyncCaseAndTask extends RecordSync {
    public override Schema.DescribeSObjectResult getObjectType() {
        //This returns the type of object that needs to be created
        return Schema.SObjectType.Task;
    }

    public override Schema.DescribeFieldResult getChildRelationalField() {
        //This returns the field where the parent record ID will be written.
        //This should be a lookup field pointing to the parent object.
        return Schema.SObjectType.Task.fields.WhatId;
    }

    public override Boolean shouldSync(SObject record) {
        //Implement this method to only synchronise records conditionally.
        //If true, the parent record will create a child record.
        return (String)record.get('Subject') != 'Delete me';
    }

    public override Map<String, Object> getFieldMapping() {
        //Returns a map containing field mappings from the child object perspective:
        //Field API Name on the Child Object => Value
        return new Map<String, Object> {
            'Subject' => 'Complete the case', //The task subject will be a constant string value (this can be any kind of object, like a decimal or date)
            'WhatId' => Case.fields.Id, //The WhatId field will be mapped to the Case ID field (fields must belong to the parent object)
            'Description' => Case.fields.Subject, //The Description field will be mapped to the case Subject field
            'Status' => MyCallableClass.class //The Status field will be calculated by the class MyCallableClass, which implements the Callable interface
        };
    }
}
```

This should then be followed by a trigger:
```Apex
trigger RecordSyncTestTrigger on Case (after insert, after update, before delete, after undelete) {
    new SyncCaseAndTask();
}
```

## Who wasted their time writing this garbage?

This garbage was written by Amnon Kruvi, whom you can reach for assistance at amnon@kruvi.co.uk

And if you're involved in a project for managing shift workers or field service, why not give [Isimio](https://www.isimio.com) a try?
