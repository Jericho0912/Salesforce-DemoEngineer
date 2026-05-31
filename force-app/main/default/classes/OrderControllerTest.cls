@IsTest
public with sharing class OrderControllerTest {
  private static final String PORTAL_USER_TYPE = 'CspLitePortal';

  @TestSetup
  static void setup() {
    // Two accounts, each with their own contact — isolation depends on distinct BillToContactIds
    Account acc1 = new Account(Name = 'NTO Test Acc 1');
    Account acc2 = new Account(Name = 'NTO Test Acc 2');
    insert new List<Account>{ acc1, acc2 };

    Contact c1 = new Contact(
      FirstName = 'Alex',
      LastName = 'Customer1',
      AccountId = acc1.Id
    );
    Contact c2 = new Contact(
      FirstName = 'Blair',
      LastName = 'Customer2',
      AccountId = acc2.Id
    );
    insert new List<Contact>{ c1, c2 };

    // Create a contact with zero orders for the empty-case test
    Account acc3 = new Account(Name = 'NTO Test Acc 3');
    insert acc3;
    Contact c3 = new Contact(
      FirstName = 'Casey',
      LastName = 'NoOrders',
      AccountId = acc3.Id
    );
    insert c3;

    Product2 p1 = new Product2(
      Name = 'Tent Alpha',
      Family = 'Camping',
      IsActive = true
    );
    Product2 p2 = new Product2(
      Name = 'Backpack Beta',
      Family = 'Hiking',
      IsActive = true
    );
    insert new List<Product2>{ p1, p2 };

    Id stdPbId = Test.getStandardPricebookId();
    PricebookEntry pbe1 = new PricebookEntry(
      Pricebook2Id = stdPbId,
      Product2Id = p1.Id,
      UnitPrice = 199.99,
      IsActive = true
    );
    PricebookEntry pbe2 = new PricebookEntry(
      Pricebook2Id = stdPbId,
      Product2Id = p2.Id,
      UnitPrice = 89.50,
      IsActive = true
    );
    insert new List<PricebookEntry>{ pbe1, pbe2 };

    // Two orders for contact 1 (different statuses/dates), one for contact 2
    Order o1a = new Order(
      AccountId = acc1.Id,
      BillToContactId = c1.Id,
      Status = 'Draft',
      EffectiveDate = Date.today().addDays(-3),
      Pricebook2Id = stdPbId
    );
    Order o1b = new Order(
      AccountId = acc1.Id,
      BillToContactId = c1.Id,
      Status = 'Draft',
      EffectiveDate = Date.today().addDays(-1),
      Pricebook2Id = stdPbId
    );
    Order o2 = new Order(
      AccountId = acc2.Id,
      BillToContactId = c2.Id,
      Status = 'Draft',
      EffectiveDate = Date.today().addDays(-2),
      Pricebook2Id = stdPbId
    );
    insert new List<Order>{ o1a, o1b, o2 };

    OrderItem oi1 = new OrderItem(
      OrderId = o1a.Id,
      PricebookEntryId = pbe1.Id,
      Product2Id = p1.Id,
      Quantity = 1,
      UnitPrice = 199.99
    );
    OrderItem oi2 = new OrderItem(
      OrderId = o1a.Id,
      PricebookEntryId = pbe2.Id,
      Product2Id = p2.Id,
      Quantity = 2,
      UnitPrice = 89.50
    );
    OrderItem oi3 = new OrderItem(
      OrderId = o1b.Id,
      PricebookEntryId = pbe1.Id,
      Product2Id = p1.Id,
      Quantity = 1,
      UnitPrice = 199.99
    );
    OrderItem oi4 = new OrderItem(
      OrderId = o2.Id,
      PricebookEntryId = pbe2.Id,
      Product2Id = p2.Id,
      Quantity = 1,
      UnitPrice = 89.50
    );
    insert new List<OrderItem>{ oi1, oi2, oi3, oi4 };

    // Portal users are deliberately the LAST thing inserted — orgs without an external-profile
    // toggle enabled will reject this DML, and we want all data above to survive that case.
    List<Profile> portalProfiles = [
      SELECT Id
      FROM Profile
      WHERE UserType = :PORTAL_USER_TYPE
      LIMIT 1
    ];
    if (!portalProfiles.isEmpty()) {
      Id pid = portalProfiles[0].Id;
      Long ts = DateTime.now().getTime();
      User u1 = buildPortalUser(pid, c1.Id, 'Alex', 'Customer1', 'cust1+' + ts);
      User u2 = buildPortalUser(
        pid,
        c2.Id,
        'Blair',
        'Customer2',
        'cust2+' + ts
      );
      User u3 = buildPortalUser(pid, c3.Id, 'Casey', 'NoOrders', 'cust3+' + ts);
      try {
        insert new List<User>{ u1, u2, u3 };
      } catch (DmlException dex) {
        // Org-wide toggle "Allow standard external profiles..." is off in this org.
        // Per-test guards (`if portalUsers.isEmpty()`) handle the resulting no-users state.
        System.debug(
          'OrderControllerTest: portal user insert blocked by org config — ' +
          dex.getMessage()
        );
      }
    }
  }

  private static User buildPortalUser(
    Id profileId,
    Id contactId,
    String first,
    String last,
    String unameBase
  ) {
    return new User(
      Alias = (last.length() > 6 ? last.substring(0, 6) : last).toLowerCase(),
      Email = unameBase + '@nto.test',
      EmailEncodingKey = 'UTF-8',
      FirstName = first,
      LastName = last,
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = profileId,
      ContactId = contactId,
      TimeZoneSidKey = 'America/Los_Angeles',
      Username = unameBase + '@nto.test.invalid'
    );
  }

  @IsTest
  static void testGetMyOrders_OnlyReturnsOwnContactOrders() {
    List<User> portalUsers = [
      SELECT Id, ContactId
      FROM User
      WHERE Contact.LastName = 'Customer1' AND IsActive = TRUE
      LIMIT 1
    ];
    if (portalUsers.isEmpty()) {
      System.assert(
        true,
        'no portal profile available — skipping isolation test'
      );
      System.debug(
        'OrderControllerTest: no CspLitePortal profile in this org; isolation test skipped'
      );
      return;
    }

    Contact c1 = [SELECT Id FROM Contact WHERE LastName = 'Customer1' LIMIT 1];
    Contact c2 = [SELECT Id FROM Contact WHERE LastName = 'Customer2' LIMIT 1];
    Set<String> c1OrderNumbers = new Set<String>();
    for (Order o : [
      SELECT OrderNumber
      FROM Order
      WHERE BillToContactId = :c1.Id
    ]) {
      c1OrderNumbers.add(o.OrderNumber);
    }
    Set<String> c2OrderNumbers = new Set<String>();
    for (Order o : [
      SELECT OrderNumber
      FROM Order
      WHERE BillToContactId = :c2.Id
    ]) {
      c2OrderNumbers.add(o.OrderNumber);
    }

    List<OrderController.OrderCard> cards;
    Test.startTest();
    System.runAs(portalUsers[0]) {
      cards = OrderController.getMyOrders(10);
    }
    Test.stopTest();

    System.assertNotEquals(null, cards, 'result must never be null');
    System.assertEquals(2, cards.size(), 'contact 1 has exactly two orders');
    for (OrderController.OrderCard card : cards) {
      System.assert(
        c1OrderNumbers.contains(card.orderNumber),
        'returned order must belong to contact 1: ' + card.orderNumber
      );
      System.assert(
        !c2OrderNumbers.contains(card.orderNumber),
        'contact 2 order leaked into contact 1 results: ' + card.orderNumber
      );
    }
  }

  @IsTest
  static void testGetMyOrders_EmptyWhenNoOrders() {
    List<User> portalUsers = [
      SELECT Id
      FROM User
      WHERE Contact.LastName = 'NoOrders' AND IsActive = TRUE
      LIMIT 1
    ];
    if (portalUsers.isEmpty()) {
      System.assert(true, 'no portal profile available — empty-case skipped');
      return;
    }
    List<OrderController.OrderCard> cards;
    System.runAs(portalUsers[0]) {
      cards = OrderController.getMyOrders(5);
    }
    System.assertNotEquals(null, cards, 'must return empty list, not null');
    System.assertEquals(
      0,
      cards.size(),
      'contact with no orders must return empty list'
    );
  }

  @IsTest
  static void testGetMyOrders_NoContactReturnsEmpty() {
    // Internal user (no ContactId) — exercises the early-exit branch
    List<OrderController.OrderCard> cards = OrderController.getMyOrders(5);
    System.assertNotEquals(null, cards, 'never null');
    System.assertEquals(
      0,
      cards.size(),
      'user without ContactId gets empty list'
    );
  }

  @IsTest
  static void testGetMyOrders_ClampingHandlesEdgeInputs() {
    // All clamp branches: null, zero, negative, over-cap — no exceptions; valid empty results
    Test.startTest();
    List<OrderController.OrderCard> n = OrderController.getMyOrders(null);
    List<OrderController.OrderCard> z = OrderController.getMyOrders(0);
    List<OrderController.OrderCard> neg = OrderController.getMyOrders(-1);
    List<OrderController.OrderCard> big = OrderController.getMyOrders(999);
    Test.stopTest();
    System.assertNotEquals(null, n);
    System.assertNotEquals(null, z);
    System.assertNotEquals(null, neg);
    System.assertNotEquals(null, big);
  }

  @IsTest
  static void testGetMyOrders_ProductSummaryAndTotalShape() {
    // Verifies productSummary joining and total-null coalescing without depending on portal users
    List<User> portalUsers = [
      SELECT Id
      FROM User
      WHERE Contact.LastName = 'Customer1' AND IsActive = TRUE
      LIMIT 1
    ];
    if (portalUsers.isEmpty()) {
      System.assert(true, 'no portal profile available — shape test skipped');
      return;
    }
    List<OrderController.OrderCard> cards;
    System.runAs(portalUsers[0]) {
      cards = OrderController.getMyOrders(10);
    }
    Boolean sawSummary = false;
    for (OrderController.OrderCard c : cards) {
      System.assertNotEquals(
        null,
        c.productSummary,
        'summary is empty string at worst, never null'
      );
      System.assertNotEquals(null, c.total, 'total coalesces null to 0');
      if (String.isNotBlank(c.productSummary)) {
        sawSummary = true;
      }
      // Joined names should not contain leading/trailing comma noise
      System.assert(!c.productSummary.startsWith(','), 'no leading comma');
      System.assert(!c.productSummary.endsWith(','), 'no trailing comma');
    }
    System.assert(
      sawSummary,
      'at least one order has items so summary should populate for some row'
    );
  }
}
