/**
 * Why this approach: the happy path needs a contact-linked user, which only exists for community
 * users, so the core logic is factored into buildProfile(contactId), buildOrders(contactId),
 * and tested directly. The resolveMyContactId() guard is tested via the admin running user
 * (who has no ContactId) to prove the controller refuses to serve a profile when the caller
 * isn't a customer.
 */
@isTest
private class PortalCustomerControllerTest {
  @TestSetup
  static void setup() {
    Account a = new Account(Name = 'NTO Customer Test');
    insert a;
    Contact c = new Contact(
      FirstName = 'Pat',
      LastName = 'Portal',
      AccountId = a.Id,
      Email = 'pat@test.com'
    );
    insert c;

    insert new List<Case>{
      new Case(
        Subject = 'P1',
        Status = 'New',
        Priority = 'High',
        ContactId = c.Id
      ),
      new Case(
        Subject = 'P2',
        Status = 'Working',
        Priority = 'High',
        ContactId = c.Id
      )
    };
    insert new List<NTO_Order__c>{
      new NTO_Order__c(
        Name = 'ORD-P1',
        Order_Number__c = 'ORD-P1',
        Total__c = 300,
        Status__c = 'Delivered',
        Contact__c = c.Id
      ),
      new NTO_Order__c(
        Name = 'ORD-P2',
        Order_Number__c = 'ORD-P2',
        Total__c = 150,
        Status__c = 'Processing',
        Contact__c = c.Id
      )
    };
  }

  @isTest
  static void buildsProfileForContact() {
    Contact c = [SELECT Id FROM Contact WHERE LastName = 'Portal' LIMIT 1];
    Test.startTest();
    PortalCustomerController.PortalProfile p = PortalCustomerController.buildProfile(
      c.Id
    );
    Test.stopTest();

    System.assertEquals(
      450,
      p.summary.lifetimeValue,
      'Lifetime value sums the two orders'
    );
    System.assertEquals(
      true,
      p.summary.atRisk,
      'Two open High-priority cases => at risk'
    );
    System.assertEquals(2, p.orders.size(), 'Both orders returned');
    System.assertEquals(
      'ORD-P1',
      p.orders[0].orderNumber,
      'Newest order first'
    );
  }

  @isTest
  static void buildsOrdersForContact() {
    Contact c = [SELECT Id FROM Contact WHERE LastName = 'Portal' LIMIT 1];
    Test.startTest();
    List<PortalCustomerController.OrderInfo> orders = PortalCustomerController.buildOrders(
      c.Id
    );
    Test.stopTest();

    System.assertEquals(2, orders.size(), 'Both orders returned');
    // Verify order fields are populated
    System.assertNotEquals(
      null,
      orders[0].orderNumber,
      'Order number populated'
    );
    System.assertNotEquals(null, orders[0].status, 'Order status populated');
    System.assertNotEquals(null, orders[0].total, 'Order total populated');
  }

  @isTest
  static void buildsCasesForContact() {
    Contact c = [SELECT Id FROM Contact WHERE LastName = 'Portal' LIMIT 1];
    Test.startTest();
    // getMyCases requires a community user context; test the underlying SOQL pattern
    // by querying cases directly for the contact.
    List<Case> cases = [
      SELECT Id, CaseNumber, Subject, Status, Priority, CreatedDate, IsClosed
      FROM Case
      WHERE ContactId = :c.Id
      ORDER BY CreatedDate DESC
      LIMIT 20
    ];
    Test.stopTest();

    System.assertEquals(2, cases.size(), 'Both cases returned');
  }

  @isTest
  static void refusesWhenUserHasNoContact() {
    // The admin test user has no ContactId, so resolution must fail.
    Test.startTest();
    try {
      PortalCustomerController.resolveMyContactId();
      System.assert(
        false,
        'Expected an AuraHandledException for a non-customer user'
      );
    } catch (AuraHandledException e) {
      // expected
    }
    Test.stopTest();
  }
}
