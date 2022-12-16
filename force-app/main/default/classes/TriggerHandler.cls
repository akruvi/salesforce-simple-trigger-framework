global virtual class TriggerHandler {
	public static Map<String, Trigger_Controller__mdt> mapTriggerControllers = null;

    global TriggerHandler() {
        try {
			Trigger_Controller__mdt controller = loadTriggerConfig();

			if (Trigger.isBefore) {
				if (Trigger.isInsert && controller.Before_Insert__c) {
					beforeInsert();
				} else if (Trigger.isUpdate && controller.Before_Update__c) {
					beforeUpdate();
				} else if (Trigger.isDelete && controller.Before_Delete__c) {
					beforeDelete();
				} else if (Trigger.isUndelete && controller.Before_Undelete__c) {
					beforeUndelete();
				}
			} else if (Trigger.isAfter) {
				if (Trigger.isInsert && controller.After_Insert__c) {
					afterInsert();
				} else if (Trigger.isUpdate && controller.After_Update__c) {
					afterUpdate();
				} else if (Trigger.isDelete && controller.After_Delete__c) {
					afterDelete();
				} else if (Trigger.isUndelete && controller.After_Undelete__c) {
					afterUndelete();
				}
			}
		} catch (Exception e) {
			onError(e);
		}
    }

	global virtual void onError(Exception e) {
		throw e;
	}

	private Trigger_Controller__mdt loadTriggerConfig() {
		if (TriggerHandler.mapTriggerControllers == null) {
			//Trigger map is not loaded. Query and populate map.
			TriggerHandler.mapTriggerControllers = new Map<String, Trigger_Controller__mdt>();

			//Query trigger controls
			List<Trigger_Controller__mdt> triggers = [SELECT MasterLabel, 
															 Before_Insert__c, Before_Update__c, Before_Delete__c, Before_Undelete__c,
															 After_Insert__c, After_Update__c, After_Delete__c, After_Undelete__c
													  FROM Trigger_Controller__mdt];

			//Map trigger controllers by label
			for (Trigger_Controller__mdt trig : triggers) {
				TriggerHandler.mapTriggerControllers.put(trig.MasterLabel.toLowerCase(), trig);
			}
		}

		//Figure out the name of the current trigger
		String className = String.valueOf(this).substring(0,String.valueOf(this).indexOf(':')).toLowerCase();
		Trigger_Controller__mdt controller = TriggerHandler.mapTriggerControllers.get(className);

		if (controller != null) {
			//Controller found, return it
			return controller;
		}

		//Return default controller with all options on
		return new Trigger_Controller__mdt(
			MasterLabel = 'Default',
			Before_Insert__c = true,
			Before_Update__c = true,
			Before_Delete__c = true,
			Before_Undelete__c = true,
			After_Insert__c = true,
			After_Update__c = true,
			After_Delete__c = true,
			After_Undelete__c = true
		);
	}

    global virtual void beforeInsert() {}
    global virtual void beforeUpdate() {}
    global virtual void beforeDelete() {}
    global virtual void beforeUndelete() {}

    global virtual void afterInsert() {}
    global virtual void afterUpdate() {}
    global virtual void afterDelete() {}
    global virtual void afterUndelete() {}
}
