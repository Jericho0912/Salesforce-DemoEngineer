/**
 * Why this approach: a bulk-safe @InvocableMethod is the contract Agentforce (and Flow) expect —
 * the agent passes an order number, this returns a ready-to-speak status sentence plus structured
 * fields. One SOQL query handles the whole request list (no query-in-loop), and the External ID on
 * Order_Number__c makes the lookup exact and fast. Reused as a topic action by the Order Status bot intent.
 */
public with sharing class OrderStatusAction {
  public class Request {
    @InvocableVariable(
      label='Order Number'
      description='The NTO order number, e.g. ORD-1001'
      required=true
    )
    public String orderNumber;
  }

  public class Response {
    @InvocableVariable(
      label='Found'
      description='True when a matching order exists'
    )
    public Boolean found;
    @InvocableVariable(
      label='Order Status'
      description='Processing / Shipped / Delivered / Returned'
    )
    public String orderStatus;
    @InvocableVariable(
      label='Message'
      description='A customer-ready sentence describing the result'
    )
    public String message;
  }

  @InvocableMethod(
    label='Get NTO Order Status'
    description='Looks up an NTO order by its order number and returns the current status.'
    category='NTO'
  )
  public static List<Response> getOrderStatus(List<Request> requests) {
    Set<String> numbers = new Set<String>();
    for (Request r : requests) {
      if (String.isNotBlank(r.orderNumber)) {
        numbers.add(r.orderNumber.trim());
      }
    }

    Map<String, NTO_Order__c> byNumber = new Map<String, NTO_Order__c>();
    for (NTO_Order__c o : [
      SELECT Order_Number__c, Status__c
      FROM NTO_Order__c
      WHERE Order_Number__c IN :numbers
    ]) {
      byNumber.put(o.Order_Number__c, o);
    }

    List<Response> responses = new List<Response>();
    for (Request r : requests) {
      Response resp = new Response();
      String key = String.isBlank(r.orderNumber) ? null : r.orderNumber.trim();
      NTO_Order__c o = (key == null) ? null : byNumber.get(key);
      if (o == null) {
        resp.found = false;
        resp.orderStatus = null;
        resp.message =
          'I couldn\'t find an order with number "' +
          r.orderNumber +
          '". Please double-check the order number and try again.';
      } else {
        resp.found = true;
        resp.orderStatus = o.Status__c;
        resp.message =
          'Order ' +
          o.Order_Number__c +
          ' is currently ' +
          o.Status__c +
          '.';
      }
      responses.add(resp);
    }
    return responses;
  }
}
