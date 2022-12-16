trigger RecordSyncTestTrigger on Case (after insert, after update, before delete, after undelete) {
    if (RecordSyncHandlerTest.TEST_RECORD_SYNC == true) {
        new RecordSyncHandlerTest();
    }
}