/**
 * Why this approach: builds its own fixtures (an at-risk hero, a thin contact, and a
 * deleted-id case) so the controller's risk math, lifetime-value sum, and error branches
 * are asserted explicitly rather than relying on org seed data.
 */
@isTest
private class Customer360ControllerTest {
  @TestSetup
  static void setup() {
    Account a = new Account(Name = 'NTO Customer Test');
    insert a;

    Contact hero = new Contact(
      FirstName = 'Hero',
      LastName = 'AtRisk',
      AccountId = a.Id,
      Email = 'hero@test.com'
    );
    Contact thin = new Contact(
      FirstName = 'Thin',
      LastName = 'NoData',
      AccountId = a.Id,
      Email = 'thin@test.com'
    );
    insert new List<Contact>{ hero, thin };

    // Hero: 2 open High-priority cases (triggers At Risk) + 1 closed.
    insert new List<Case>{
      new Case(
        Subject = 'H1',
        Status = 'New',
        Priority = 'High',
        ContactId = hero.Id
      ),
      new Case(
        Subject = 'H2',
        Status = 'Working',
        Priority = 'High',
        ContactId = hero.Id
      ),
      new Case(
        Subject = 'H3',
        Status = 'Closed',
        Priority = 'Low',
        ContactId = hero.Id
      )
    };

    insert new List<NTO_Order__c>{
      new NTO_Order__c(
        Name = 'ORD-T1',
        Order_Number__c = 'ORD-T1',
        Total__c = 100,
        Status__c = 'Delivered',
        Contact__c = hero.Id
      ),
      new NTO_Order__c(
        Name = 'ORD-T2',
        Order_Number__c = 'ORD-T2',
        Total__c = 250.50,
        Status__c = 'Shipped',
        Contact__c = hero.Id
      )
    };
  }

  @isTest
  static void heroIsAtRisk() {
    Contact hero = [SELECT Id FROM Contact WHERE LastName = 'AtRisk' LIMIT 1];
    Test.startTest();
    Customer360Controller.CustomerSummary s = Customer360Controller.getCustomerSummary(
      hero.Id
    );
    Test.stopTest();

    System.assertEquals(
      350.50,
      s.lifetimeValue,
      'Lifetime value should sum order totals'
    );
    System.assertEquals(2, s.openCaseCount, 'Two cases are open');
    System.assertEquals(
      true,
      s.atRisk,
      '2 open High-priority cases => At Risk'
    );
    System.assertEquals(
      3,
      s.recentCases.size(),
      'All three cases returned (under the 5 cap)'
    );
    System.assertEquals('Hero AtRisk', s.name, 'Contact name resolved');
  }

  @isTest
  static void thinContactIsEmptyAndNotAtRisk() {
    Contact thin = [SELECT Id FROM Contact WHERE LastName = 'NoData' LIMIT 1];
    Test.startTest();
    Customer360Controller.CustomerSummary s = Customer360Controller.getCustomerSummary(
      thin.Id
    );
    Test.stopTest();

    System.assertEquals(0, s.lifetimeValue, 'No orders => 0 lifetime value');
    System.assertEquals(0, s.openCaseCount, 'No open cases');
    System.assertEquals(
      false,
      s.atRisk,
      'No High-priority cases => not at risk'
    );
    System.assertEquals(0, s.recentCases.size(), 'No cases on file');
  }

  @isTest
  static void nullContactThrows() {
    Test.startTest();
    try {
      Customer360Controller.getCustomerSummary(null);
      System.assert(
        false,
        'Expected an AuraHandledException for a null contact id'
      );
    } catch (AuraHandledException e) {
      // expected
    }
    Test.stopTest();
  }

  @isTest
  static void unknownContactThrows() {
    Account a = [SELECT Id FROM Account LIMIT 1];
    Contact temp = new Contact(LastName = 'Temp', AccountId = a.Id);
    insert temp;
    Id deletedId = temp.Id;
    delete temp; // well-formed Contact Id that no longer exists

    Test.startTest();
    try {
      Customer360Controller.getCustomerSummary(deletedId);
      System.assert(
        false,
        'Expected an AuraHandledException for an unknown contact'
      );
    } catch (AuraHandledException e) {
      // expected
    }
    Test.stopTest();
  }
}
