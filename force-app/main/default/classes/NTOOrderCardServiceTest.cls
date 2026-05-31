/**
 * @description Coverage for NTOOrderCardService. Seeds a Contact + ORD-2001 (drives the
 * demo-fallback contact resolution) plus a Shipped order, then asserts the CLT wrapper.
 */
@isTest
private class NTOOrderCardServiceTest {
  @testSetup
  static void setup() {
    Contact c = new Contact(LastName = 'Stone', FirstName = 'Avery');
    insert c;
    insert new List<NTO_Order__c>{
      new NTO_Order__c(
        Order_Number__c = 'ORD-2001',
        Status__c = 'Shipped',
        Total__c = 129.00,
        Contact__c = c.Id
      ),
      new NTO_Order__c(
        Order_Number__c = 'ORD-2002',
        Status__c = 'Shipped',
        Total__c = 89.50,
        Contact__c = c.Id
      ),
      new NTO_Order__c(
        Order_Number__c = 'ORD-2003',
        Status__c = 'Delivered',
        Total__c = 59.00,
        Contact__c = c.Id
      )
    };
  }

  @isTest
  static void returnsMatchingOrdersAsCards() {
    NTOOrderCardService.OrderQueryRequest req = new NTOOrderCardService.OrderQueryRequest();
    req.status_filter = 'Shipped';

    Test.startTest();
    List<NTOOrderCardService.OrderQueryResponse> res = NTOOrderCardService.getOrdersByStatus(
      new List<NTOOrderCardService.OrderQueryRequest>{ req }
    );
    Test.stopTest();

    System.assertEquals(1, res.size(), 'One response expected');
    System.assertNotEquals(
      null,
      res[0].orders_result,
      'Container must never be null'
    );
    System.assertEquals(
      2,
      res[0].orders_result.orders.size(),
      'Two Shipped orders expected for the seeded contact'
    );
    System.assertEquals(
      'ORD-2002',
      res[0].orders_result.orders[1].orderNumber,
      'Second card should be a shipped order'
    );
  }

  @isTest
  static void unknownStatusReturnsEmptyContainer() {
    NTOOrderCardService.OrderQueryRequest req = new NTOOrderCardService.OrderQueryRequest();
    req.status_filter = 'Teleported';

    Test.startTest();
    List<NTOOrderCardService.OrderQueryResponse> res = NTOOrderCardService.getOrdersByStatus(
      new List<NTOOrderCardService.OrderQueryRequest>{ req }
    );
    Test.stopTest();

    System.assertEquals(
      0,
      res[0].orders_result.orders.size(),
      'Unknown status must yield an empty (not null) order list'
    );
  }
}
