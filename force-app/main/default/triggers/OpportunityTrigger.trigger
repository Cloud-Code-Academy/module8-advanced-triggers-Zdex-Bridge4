/*
OpportunityTrigger Overview

This class defines the trigger logic for the Opportunity object in Salesforce. It focuses on three main functionalities:
1. Ensuring that the Opportunity amount is greater than $5000 on update.
2. Preventing the deletion of a 'Closed Won' Opportunity if the related Account's industry is 'Banking'.
3. Setting the primary contact on an Opportunity to the Contact with the title 'CEO' when updating.

Usage Instructions:
For this lesson, students have two options:
1. Use the provided `OpportunityTrigger` class as is.
2. Use the `OpportunityTrigger` from you created in previous lessons. If opting for this, students should:
    a. Copy over the code from the previous lesson's `OpportunityTrigger` into this file.
    b. Save and deploy the updated file into their Salesforce org.

Remember, whichever option you choose, ensure that the trigger is activated and tested to validate its functionality.
*/
trigger OpportunityTrigger on Opportunity(
  before insert,
  before update,
  after insert,
  before delete,
  after delete,
  after undelete
) {
  if (Trigger.isBefore && Trigger.isInsert) {
    //Set default Type for new Opportunities
    opportunityTriggerHandler.setDefaultType(Trigger.new);
  }

  if (Trigger.isBefore && Trigger.isUpdate) {
    //When an opportunity is updated validate that the amount is greater than 5000.
    opportunityTriggerHandler.validateAmountHelper(Trigger.new);

    //When an opportunity is updated set the primary contact on the opportunity to the contact with the title of 'CEO'.
    opportunityTriggerHandler.updatePrimaryContactHelper(Trigger.new);

    // Append Stage changes in Opportunity Description
    opportunityTriggerHandler.appendStageChangesOppDescription(Trigger.new);
  }

  if (Trigger.isAfter && Trigger.isInsert) {
    // Create a new Task for newly inserted Opportunities
    opportunityTriggerHandler.createTaskOpportunity(Trigger.new);
  }

  if (Trigger.isBefore && Trigger.isDelete) {
    //When an opportunity is deleted prevent the deletion of a closed won opportunity if the account industry is 'Banking'.
    // Prevent deletion of closed Opportunities
    opportunityTriggerHandler.preventDeleteHelper(Trigger.old);
  }

  if (Trigger.isAfter && Trigger.isDelete) {
    //Sends an email notification to the owner of the Opportunity when it gets deleted.
    opportunityTriggerHandler.notifyOwnersOpportunityDeleted(Trigger.old);
  }

  if (Trigger.isAfter && Trigger.isUndelete) {
    //Assigns a primary contact with the title of 'VP Sales' to undeleted Opportunities.
    //Only updates the Opportunities that don't already have a primary contact.
    opportunityTriggerHandler.assignPrimaryContact(Trigger.newMap);
  }
}
