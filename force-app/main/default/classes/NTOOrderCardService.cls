/**
 * @description CLT showcase service. Returns the running customer's NTO_Order__c
 * records filtered by Status__c, shaped for the c__ntoOrderList Custom Lightning Type.
 * Inner classes OrderCard / OrderCardList are the CLT data shapes referenced by
 * lightningTypes/ntoOrderList/schema.json. Wrapper field names (status_filter,
 * orders_result) MUST match the Agent Script action parameter names.
 *
 * Isolation: orders are queried WITH USER_MODE under `with sharing`, scoped to the
 * resolved Contact. resolveContactId() returns the running COMMUNITY user's Contact
 * (the production isolation pattern, identical to the portal). For an internal builder
 * preview (running user has no ContactId) it falls back to the seeded hero contact via
 * ORD-2001 so the cards still render -- no hardcoded Id, redeployable, demo-only.
 */
public with sharing class NTOOrderCardService {
  // CLT output element. All-String to mirror the recipe's CaseResult shape (lowest-risk render).
  public class OrderCard {
    @InvocableVariable
    public String orderNumber;
    @InvocableVariable
    public String status;
    @InvocableVariable
    public String total; // pre-formatted currency string
    @InvocableVariable
    public String orderDate; // pre-formatted date string
  }

  // CLT-typed displayable container -- the Lightning type schema.json points here.
  public class OrderCardList {
    @InvocableVariable
    public List<OrderCard> orders;
  }

  // Invocable request wrapper -- field name MUST match the action input parameter.
  public class OrderQueryRequest {
    @InvocableVariable(required=true)
    public String status_filter;
  }

  // Invocable response wrapper -- field name MUST match the action output parameter.
  public class OrderQueryResponse {
    @InvocableVariable
    public OrderCardList orders_result;
  }

  private static final Set<String> ALLOWED_STATUSES = new Set<String>{
    'Processing',
    'Shipped',
    'Delivered',
    'Returned'
  };

  @InvocableMethod(
    label='Get NTO Orders By Status'
    description='Returns the running customer\'s NTO orders filtered by status, as CLT order cards'
    category='NTO'
  )
  public static List<OrderQueryResponse> getOrdersByStatus(
    List<OrderQueryRequest> requests
  ) {
    List<OrderQueryResponse> responses = new List<OrderQueryResponse>();
    Id contactId = resolveContactId();

    for (OrderQueryRequest req : requests) {
      OrderQueryResponse res = new OrderQueryResponse();
      OrderCardList container = new OrderCardList();
      container.orders = new List<OrderCard>();

      String normalized = normalizeStatus(req.status_filter);

      if (contactId != null && normalized != null) {
        for (NTO_Order__c o : [
          SELECT Order_Number__c, Status__c, Total__c, CreatedDate
          FROM NTO_Order__c
          WHERE Contact__c = :contactId AND Status__c = :normalized
          WITH USER_MODE
          ORDER BY CreatedDate DESC
        ]) {
          OrderCard card = new OrderCard();
          card.orderNumber = o.Order_Number__c;
          card.status = o.Status__c;
          card.total = (o.Total__c == null) ? '' : formatCurrency(o.Total__c);
          card.orderDate = (o.CreatedDate == null)
            ? ''
            : o.CreatedDate.format('MMM d, yyyy');
          container.orders.add(card);
        }
      }

      res.orders_result = container;
      responses.add(res);
    }
    return responses;
  }

  /**
   * Production isolation: the running community user's Contact.
   * Demo fallback for internal preview (no ContactId on the running user):
   * resolve the seeded hero contact deterministically via ORD-2001 -- redeployable,
   * no hardcoded Id. Safe to keep (only fires for non-community users) or strip for prod.
   */
  private static Id resolveContactId() {
    Id ctc = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()]
    .ContactId;
    if (ctc != null) {
      return ctc;
    }
    List<NTO_Order__c> seed = [
      SELECT Contact__c
      FROM NTO_Order__c
      WHERE Order_Number__c = 'ORD-2001'
      LIMIT 1
    ];
    return seed.isEmpty() ? null : seed[0].Contact__c;
  }

  private static String normalizeStatus(String raw) {
    if (String.isBlank(raw)) {
      return null;
    }
    String trimmed = raw.trim();
    for (String s : ALLOWED_STATUSES) {
      if (s.equalsIgnoreCase(trimmed)) {
        return s;
      }
    }
    return null; // unknown status -> empty result -> renderer shows empty state
  }

  private static String formatCurrency(Decimal amount) {
    return '$' + amount.setScale(2).format();
  }
}
