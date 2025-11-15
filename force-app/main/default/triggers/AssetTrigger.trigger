trigger AssetTrigger on Asset (after update) {
    if (Trigger.isAfter && Trigger.isUpdate) {
        AssetTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}
