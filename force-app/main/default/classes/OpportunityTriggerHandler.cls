public with sharing class OpportunityTriggerHandler {
  //Helper Methods for Opportuniy Trigger Handler Class
  /*
   * Opportunity validateAmountHelper
   * When an opportunity is updated validate that the amount is greater than 5000.
   * Trigger should only fire on update.
   */
  public static void validateAmountHelper(List<Opportunity> newOpportunities) {
    for (Opportunity opp : newOpportunities) {
      if (opp.Amount < 5000) {
        opp.addError('Opportunity amount must be greater than 5000');
      }
    }
  }

  /*
   * Opportunity preventDeleteHelper
   * When an opportunity is deleted prevent the deletion of a closed won opportunity if the account industry is 'Banking'.
   * Trigger should only fire on delete.
   */
  public static void preventDeleteHelper(List<Opportunity> opportunities) {
    //Get Account Ids from Opportunites
    Set<Id> accountIds = new Set<Id>();
    for (Opportunity opp : opportunities) {
      if (opp.AccountId != null) {
        accountIds.add(opp.AccountId);
      }
    }

    // Query Accounts with relevant data
    Map<Id, Account> accounts = new Map<Id, Account>(
      [
        SELECT Id, Industry
        FROM Account
        WHERE Id IN :accountIds AND Industry = 'Banking'
      ]
    );
    for (Opportunity opp : opportunities) {
      // Prevent deletion of closedwon Opportunities for abnking accounts
      if (
        opp.StageName == 'Closed Won' && accounts.containsKey(opp.AccountId)
      ) {
        opp.addError('Cannot delete closed opportunity');
      }
      // Prevent deletion of closed Opportunities
      else if (opp.IsClosed) {
        opp.addError('Cannot delete closed opportunity');
      }
    }
  }

  /*
   * Opportunity updatePrimaryContactHelper
   * When an opportunity is updated set the primary contact on the opportunity to the contact with the title of 'CEO'.
   * Trigger should only fire on update.
   */
  public static void updatePrimaryContactHelper(
    List<Opportunity> updatedOpportunities
  ) {
    //Get contacts related to the opportunity account
    Set<Id> accountIds = new Set<Id>();
    for (Opportunity opp : updatedOpportunities) {
      accountIds.add(opp.AccountId);
    }

    Map<Id, Contact> contacts = new Map<Id, Contact>(
      [
        SELECT Id, FirstName, AccountId
        FROM Contact
        WHERE AccountId IN :accountIds AND Title = 'CEO'
        ORDER BY FirstName ASC
      ]
    );
    Map<Id, Contact> accountIdToContact = new Map<Id, Contact>();

    for (Contact cont : contacts.values()) {
      if (!accountIdToContact.containsKey(cont.AccountId)) {
        accountIdToContact.put(cont.AccountId, cont);
      }
    }

    for (Opportunity opp : updatedOpportunities) {
      if (opp.Primary_Contact__c == null) {
        if (accountIdToContact.containsKey(opp.AccountId)) {
          opp.Primary_Contact__c = accountIdToContact.get(opp.AccountId).Id;
        }
      }
    }
  }

  // Set default Type for new Opportunities
  public static void setDefaultType(List<Opportunity> newOpportunities) {
    for (Opportunity opp : newOpportunities) {
      if (opp.Type == null) {
        opp.Type = 'New Customer';
      }
    }
  }

  // else if (Trigger.isUpdate){
  // Append Stage changes in Opportunity Description
  public static void appendStageChangesOppDescription(
    List<Opportunity> opportunities
  ) {
    for (Opportunity opp : opportunities) {
      Opportunity oldOpp = (Opportunity) Trigger.oldMap.get(opp.Id);

      //Check if stage name has changed
      if (opp.StageName != null && opp.StageName != oldOpp.StageName) {
        if (opp.Description == null) {
          opp.Description = ''; //initialize description if null
        }
      }
      opp.Description +=
        '\n Stage Change:' +
        opp.StageName +
        ':' +
        DateTime.now().format();
    }
  }

  //if (Trigger.isAfter && Trigger.isInsert)
  // Create a new Task for newly inserted Opportunities
  public static void createTaskOpportunity(List<Opportunity> newOpportunities) {
    List<Task> tasks = new List<Task>();

    // Loop through each opportunity and create a task
    for (Opportunity opp : newOpportunities) {
      if (opp.Primary_Contact__c != null) {
        // Check for null Primary Contact
        Task tsk = new Task();
        tsk.Subject = 'Call Primary Contact';
        tsk.WhatId = opp.Id; // Associate task with opportunity
        tsk.WhoId = opp.Primary_Contact__c; // Associate task with primary contact
        tsk.OwnerId = opp.OwnerId; // Assign task owner
        tsk.ActivityDate = Date.today().addDays(3); // Set task due date
        tasks.add(tsk);
      } else {
        System.debug(
          'Skipping Opportunity with ID: ' +
            opp.Id +
            ' due to missing Primary Contact.'
        );
      }
    }
    // Insert tasks if the list is not empty
    if (!tasks.isEmpty()) {
      try {
        insert tasks;
        System.debug('Successfully inserted ' + tasks.size() + ' tasks.');
      } catch (DmlException e) {
        System.debug('Failed to insert tasks: ' + e.getMessage());
      }
    } else {
      System.debug('No tasks to insert.');
    }
  }

  //else if (Trigger.isDelete){
  /*
    notifyOwnersOpportunityDeleted:
    - Sends an email notification to the owner of the Opportunity when it gets deleted.
    - Uses Salesforce's Messaging.SingleEmailMessage to send the email.
    */
  public static void notifyOwnersOpportunityDeleted(
    List<Opportunity> deletedOpportunities
  ) {
    //collect opportunity owner IDs
    Set<Id> ownerIds = new Set<Id>();
    for (Opportunity opp : deletedOpportunities) {
      if (opp.OwnerId != null) {
        ownerIds.add(opp.OwnerId);
      }
    }

    //query user emails for opportunity owners
    Map<Id, User> ownerEmails = new Map<Id, User>(
      [SELECT Id, Email FROM User WHERE Id IN :ownerIds]
    );

    //create email messages
    List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
    List<String> toAddresses = new List<String>();
    for (Opportunity opp : deletedOpportunities) {
      User owner = ownerEmails.get(opp.OwnerId);
      toAddresses.add(owner.Email);
      if (owner != null && owner.Email != null) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(toAddresses);
        mail.setSubject('Opportunity Deleted : ' + opp.Name);
        mail.setPlainTextBody(
          'Your Opportunity: ' + opp.Name + ' has been deleted.'
        );
        mails.add(mail);
      }
    }

    //send email messages
    if (!mails.isEmpty()) {
      try {
        Messaging.sendEmail(mails);
      } catch (Exception e) {
        System.debug('Exception: ' + e.getMessage());
      }
    }
  }
  //else if (Trigger.isUndelete)
  /*
    assignPrimaryContact:
    - Assigns a primary contact with the title of 'VP Sales' to undeleted Opportunities.
    - Only updates the Opportunities that don't already have a primary contact.
    */
  public static void assignPrimaryContact(Map<Id, Opportunity> oppNewMap) {
    //collect account IDs from opportunities
    Set<Id> accountIds = new Set<Id>();
    for (Opportunity opp : oppNewMap.values()) {
      if (opp.AccountId != null) {
        accountIds.add(opp.AccountId);
      }
    }

    //query primary contacts with the title of 'VP Sales' to related accounts and store in map (Id, contact)
    Map<Id, Contact> contactsMap = new Map<Id, Contact>();
    Contact[] primaryContacts = [
      SELECT Id, AccountId
      FROM Contact
      WHERE Title = 'VP Sales' AND AccountId IN :accountIds
    ];
    for (Contact con : primaryContacts) {
      contactsMap.put(con.AccountId, con);
    }
    //get opportunities to update
    List<Opportunity> oppsToUpdate = new List<Opportunity>();
    for (Opportunity opp : oppNewMap.values()) {
      if (opp.Primary_Contact__c == null && opp.AccountId != null) {
        Contact primaryContact = contactsMap.get(opp.AccountId);
        if (primaryContact != null) {
          Opportunity oppToUpdate = new Opportunity(Id = opp.Id);
          oppToUpdate.Primary_Contact__c = primaryContact.Id;
          oppsToUpdate.add(oppToUpdate);
        }
      }
    }
    //bulk update opportunities
    if (!oppsToUpdate.isEmpty()) {
      update oppsToUpdate;
    }
  }
}
