@isTest
public class RecordSync_Test {
    /* Check RecordSyncHandlerTest for the test class t hat converts objects into fields */

    @IsTest static void testCreateAndUpdate() {
        RecordSyncHandlerTest.TEST_RECORD_SYNC = true;

        //Create new cases
        List<Case> cases = new List<Case>();
        for (Integer i=0;i < 5;i++) {
            cases.add(
                new Case(
                    Subject = 'Test Case ' + (i+1)
                )
            );
        }

        Test.startTest();
        insert cases;
        Test.stopTest();

        //Verify tasks were created
        cases = [SELECT Id, Subject, (SELECT Subject, Description, Status FROM Tasks) FROM Case];

        Assert.areEqual(5, cases.size(), 'Some cases were not created or loaded successfully');
        for (Case c : cases) {
            Assert.areEqual(1, c.Tasks.size(), 'Task was not created for case, or too many tasks created');
            Assert.areEqual('Complete the case', c.Tasks[0].Subject, 'Task subject was not set correctly from a constant string value');
            Assert.areEqual(c.Subject, c.Tasks[0].Description, 'Description was not set correctly from the case Subject');
            Assert.areEqual('In Progress', c.Tasks[0].Status, 'Status was not set correctly from a callable class');
        }

        //Update case subjects
        for (Case c : cases) {
            c.Subject = 'Updated subject';
        }
        update cases;

        //Verify tasks were updated correctly
        cases = [SELECT Id, Subject, (SELECT Subject, Description, Status FROM Tasks) FROM Case];

        Assert.areEqual(5, cases.size(), 'Some cases were not created or loaded successfully');
        for (Case c : cases) {
            Assert.areEqual(1, c.Tasks.size(), 'Task was not created for case, or too many tasks created');
            Assert.areEqual('Complete the case', c.Tasks[0].Subject, 'Task subject was not set correctly from a constant string value');
            Assert.areEqual(c.Subject, c.Tasks[0].Description, 'Description was not set correctly from the case Subject');
            Assert.areEqual('In Progress', c.Tasks[0].Status, 'Status was not set correctly from a callable class');
        }
    }

    @IsTest static void testDeleteAndRecreate() {
        RecordSyncHandlerTest.TEST_RECORD_SYNC = true;

        //Create new cases
        List<Case> cases = new List<Case>();
        for (Integer i=0;i < 5;i++) {
            cases.add(
                new Case(
                    Subject = 'Test Case ' + (i+1)
                )
            );
        }

        insert cases;

        //Delete the tasks and make sure they're recreated when the cases are updated
        delete [SELECT Id FROM Task];

        Test.startTest();
        //Update the cases. This should trigger the child tasks to be recreated.
        update cases;
        Test.stopTest();
        
        //Verify tasks were re-created
        cases = [SELECT Id, Subject, (SELECT Subject, Description, Status FROM Tasks) FROM Case];

        Assert.areEqual(5, cases.size(), 'Some cases were not created or loaded successfully');
        for (Case c : cases) {
            Assert.areEqual(1, c.Tasks.size(), 'Task was not created for case, or too many tasks created');
            Assert.areEqual('Complete the case', c.Tasks[0].Subject, 'Task subject was not set correctly from a constant string value');
            Assert.areEqual(c.Subject, c.Tasks[0].Description, 'Description was not set correctly from the case Subject');
            Assert.areEqual('In Progress', c.Tasks[0].Status, 'Status was not set correctly from a callable class');
        }

        //Delete cases
        delete cases;

        //Verify tasks were deleted
        Assert.areEqual(0, [SELECT Id FROM Task].size(), 'Tasks were not deleted when cases were');
    }

    @IsTest static void testUndelete() {
        RecordSyncHandlerTest.TEST_RECORD_SYNC = true;

        //Create new cases
        List<Case> cases = new List<Case>();
        for (Integer i=0;i < 5;i++) {
            cases.add(
                new Case(
                    Subject = 'Test Case ' + (i+1)
                )
            );
        }

        insert cases;

        //Delete the cases so that tasks are also deleted
        delete cases;
        Assert.areEqual(0, [SELECT Id FROM Task].size(), 'Tasks were not deleted when cases were');

        //Undelete cases
        Test.startTest();
        undelete cases;
        Test.stopTest();
        
        //Verify tasks were re-created
        cases = [SELECT Id, Subject, (SELECT Subject, Description, Status FROM Tasks) FROM Case];

        Assert.areEqual(5, cases.size(), 'Some cases were not created or loaded successfully');
        for (Case c : cases) {
            Assert.areEqual(1, c.Tasks.size(), 'Task was not created for case, or too many tasks created');
            Assert.areEqual('Complete the case', c.Tasks[0].Subject, 'Task subject was not set correctly from a constant string value');
            Assert.areEqual(c.Subject, c.Tasks[0].Description, 'Description was not set correctly from the case Subject');
            Assert.areEqual('In Progress', c.Tasks[0].Status, 'Status was not set correctly from a callable class');
        }
    }

    @IsTest static void testShouldSync() {
        RecordSyncHandlerTest.TEST_RECORD_SYNC = true;

        //Create new cases
        List<Case> cases = new List<Case>();
        for (Integer i=0;i < 5;i++) {
            cases.add(
                new Case(
                    Subject = 'Test Case ' + (i+1)
                )
            );
        }

        //Mark one case as 'Delete me' to not sync it
        cases[4].Subject = 'Delete me';

        Test.startTest();
        insert cases;
        Test.stopTest();

        Id ignoredCaseId = cases[4].Id;

        //Verify tasks were created
        cases = [SELECT Id, Subject, (SELECT Subject, Description, Status FROM Tasks) FROM Case];

        Assert.areEqual(5, cases.size(), 'Some cases were not created or loaded successfully');
        for (Case c : cases) {
            if (c.Id == ignoredCaseId) {
                //Delete-me case
                Assert.areEqual(0, c.Tasks.size(), 'Task was created despite not meeting criteria');
            } else {
                //Other cases
                Assert.areEqual(1, c.Tasks.size(), 'Task was not created for case, or too many tasks created');
                Assert.areEqual('Complete the case', c.Tasks[0].Subject, 'Task subject was not set correctly from a constant string value');
                Assert.areEqual(c.Subject, c.Tasks[0].Description, 'Description was not set correctly from the case Subject');
                Assert.areEqual('In Progress', c.Tasks[0].Status, 'Status was not set correctly from a callable class');
            }
        }

        //Update another case to not meet criteria
        cases[0].Subject = 'Delete me';
        update cases;

        Id ignoredCaseId2 = cases[0].Id;

        //Verify that the task belonging to this case was deleted
        cases = [SELECT Id, Subject, (SELECT Subject, Description, Status FROM Tasks) FROM Case];

        Assert.areEqual(5, cases.size(), 'Some cases were not created or loaded successfully');
        for (Case c : cases) {
            if (c.Id == ignoredCaseId ||
                c.Id == ignoredCaseId2) {
                //Delete-me case
                Assert.areEqual(0, c.Tasks.size(), 'Task was created despite not meeting criteria');
            } else {
                //Other cases
                Assert.areEqual(1, c.Tasks.size(), 'Task was not created for case, or too many tasks created');
                Assert.areEqual('Complete the case', c.Tasks[0].Subject, 'Task subject was not set correctly from a constant string value');
                Assert.areEqual(c.Subject, c.Tasks[0].Description, 'Description was not set correctly from the case Subject');
                Assert.areEqual('In Progress', c.Tasks[0].Status, 'Status was not set correctly from a callable class');
            }
        }
    }
}