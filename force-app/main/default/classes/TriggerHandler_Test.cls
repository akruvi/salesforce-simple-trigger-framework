@isTest public class TriggerHandler_Test {
    @IsTest static void testMergeControllers() {
        //Create two controllers to merge with different configuration
        Trigger_Controller__mdt ctrl1 = new Trigger_Controller__mdt(MasterLabel='Main', Before_Insert__c = true, Before_Update__c = true);
        Trigger_Controller__mdt ctrl2 = new Trigger_Controller__mdt(MasterLabel='Secondary', Before_Insert__c = false, Before_Update__c = true);

        //Merge the two controllers
        Test.startTest();
        TriggerHandler.mergeControllers(ctrl1, ctrl2);
        Test.stopTest();

        //Check results
        Assert.areEqual(false, ctrl1.Before_Insert__c, 'Field was not merged correctly on the main controller');
        Assert.areEqual(true, ctrl1.Before_Update__c, 'Field was deactivated incorrectly on the main controller');
    }

    @IsTest static void testOnError() {
        try {
            (new TriggerHandler());
            Assert.fail('Exception not thrown when instantiating trigger handler outside of trigger context');
        } catch (System.NullPointerException ex) {
            //OK
        }
    }
}
