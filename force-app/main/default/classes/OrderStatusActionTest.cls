/**
 * Why this approach: exercises the invocable in the bulk shape Agentforce/Flow use (a list of
 * requests), asserting the found/not-found branches and that responses line up with requests.
 */
@isTest
private class OrderStatusActionTest {
  @TestSetup
  static void setup() {
    Account a = new Account(Name = 'NTO Customer Test');
    insert a;
    Contact c = new Contact(LastName = 'Buyer', AccountId = a.Id);
    insert c;
    insert new NTO_Order__c(
      Name = 'ORD-9001',
      Order_Number__c = 'ORD-9001',
      Total__c = 199.99,
      Status__c = 'Shipped',
      Contact__c = c.Id
    );
  }

  @isTest
  static void returnsStatusForKnownOrder() {
    OrderStatusAction.Request req = new OrderStatusAction.Request();
    req.orderNumber = 'ORD-9001';

    Test.startTest();
    List<OrderStatusAction.Response> res = OrderStatusAction.getOrderStatus(
      new List<OrderStatusAction.Request>{ req }
    );
    Test.stopTest();

    System.assertEquals(1, res.size(), 'One response per request');
    System.assertEquals(true, res[0].found, 'Order should be found');
    System.assertEquals(
      'Shipped',
      res[0].orderStatus,
      'Status should match the record'
    );
    System.assert(
      res[0].message.contains('Shipped'),
      'Message should mention the status'
    );
  }

  @isTest
  static void handlesUnknownOrderAndPreservesOrder() {
    OrderStatusAction.Request known = new OrderStatusAction.Request();
    known.orderNumber = 'ORD-9001';
    OrderStatusAction.Request unknown = new OrderStatusAction.Request();
    unknown.orderNumber = 'ORD-0000';

    Test.startTest();
    List<OrderStatusAction.Response> res = OrderStatusAction.getOrderStatus(
      new List<OrderStatusAction.Request>{ known, unknown }
    );
    Test.stopTest();

    System.assertEquals(2, res.size(), 'Two responses for two requests');
    System.assertEquals(
      true,
      res[0].found,
      'First request matches a real order'
    );
    System.assertEquals(false, res[1].found, 'Second request has no match');
    System.assert(
      res[1].message.contains('ORD-0000'),
      'Not-found message echoes the input'
    );
  }
}
