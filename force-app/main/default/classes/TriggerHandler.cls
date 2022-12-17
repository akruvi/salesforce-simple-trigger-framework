global virtual class TriggerHandler {
	private static final String APPLIES_TO_EVERYONE = 'Everyone',
								APPLIES_TO_USER = 'Username',
								APPLIES_TO_PROFILE = 'Profile',
								APPLIES_TO_ROLE = 'Role',
								APPLIES_TO_PERM_SET = 'Permission Set';
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

			UserData ud = new UserData();

			//Query trigger controls
			List<Trigger_Controller__mdt> triggers = [SELECT MasterLabel, Applies_To_Type__c, Applies_To_Value__c,
															 Before_Insert__c, Before_Update__c, Before_Delete__c, Before_Undelete__c,
															 After_Insert__c, After_Update__c, After_Delete__c, After_Undelete__c
													  FROM Trigger_Controller__mdt];

			//Map trigger controllers by label (trigger handler name) and filter them to only ones relevant for this user
			for (Trigger_Controller__mdt trig : triggers) {
				//Check that this trigger controller applies to the user
				if (ud.isApplicable(trig)) {
					//Find an existing controller for this class
					Trigger_Controller__mdt existing = TriggerHandler.mapTriggerControllers.get(trig.MasterLabel.toLowerCase());

					if (existing != null) {
						//Existing controller found. Merge the two.
						mergeControllers(existing, trig);
					} else {
						//New controller found.
						TriggerHandler.mapTriggerControllers.put(trig.MasterLabel.toLowerCase(), trig);
					}
				}
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

	@TestVisible
	static private void mergeControllers(Trigger_Controller__mdt main, Trigger_Controller__mdt secondary) {
		main.Before_Insert__c &= secondary.Before_Insert__c;
		main.Before_Update__c &= secondary.Before_Update__c;
		main.Before_Delete__c &= secondary.Before_Delete__c;
		main.Before_Undelete__c &= secondary.Before_Undelete__c;
		main.After_Insert__c &= secondary.After_Insert__c;
		main.After_Update__c &= secondary.After_Update__c;
		main.After_Delete__c &= secondary.After_Delete__c;
		main.After_Undelete__c &= secondary.After_Undelete__c;
	}

	private class UserData {
		private Set<String> roleNames;
		private Set<String> permSets;
		private String profileName;
		private String userName;

		private UserData() {
			//Load user details
			User u = [SELECT Id, Username, Profile.Name, UserRole.Name, UserRole.DeveloperName,
							 (SELECT PermissionSet.Name FROM PermissionSetAssignments)
					  FROM User
					  WHERE Id = :UserInfo.geTUserId()];

			//Create a set of assigned permission sets
			this.permSets = new Set<String>();
			for (PermissionSetAssignment psa : u.PermissionSetAssignments) {
				permSets.add(psa.PermissionSet?.Name);
			}

			//Extract profile and role names from the user
			this.profileName = u?.Profile?.Name;

			this.roleNames = new Set<String>();
			this.roleNames.add(u?.UserRole?.Name);
			this.roleNames.add(u?.UserRole?.DeveloperName);

			this.userName = u.Username;
		}

		private Boolean isApplicable(Trigger_Controller__mdt trig) {
			if (trig.Applies_To_Type__c == APPLIES_TO_PROFILE) {
				return trig.Applies_To_Value__c.equalsIgnoreCase(this.profileName);
			} else if (trig.Applies_To_Type__c == APPLIES_TO_ROLE) {
				return this.roleNames.contains(trig.Applies_To_Value__c);
			} else if (trig.Applies_To_Type__c == APPLIES_TO_PERM_SET) {
				return this.permSets.contains(trig.Applies_To_Value__c);
			} else if (trig.Applies_To_Type__c == APPLIES_TO_USER) {
				return trig.Applies_To_Value__c.equalsIgnoreCase(this.userName);
			}

			return true;
		}
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
