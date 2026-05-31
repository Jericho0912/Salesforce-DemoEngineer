public with sharing class OrderController { // enforces sharing rules so portal users never see other contacts' orders
  @AuraEnabled(cacheable=true)
  public static List<OrderCard> getMyOrders(Integer maxRows) {
    Integer clamped;
    if (maxRows == null || maxRows <= 0) {
      clamped = 5;
    } else if (maxRows > 100) {
      clamped = 100;
    } else {
      clamped = maxRows;
    }

    Id currentUserId = UserInfo.getUserId();
    Id contactId = null;
    // WITH USER_MODE so FLS/CRUD on User is honored even for the running user's row
    for (User u : [
      SELECT ContactId
      FROM User
      WHERE Id = :currentUserId
      WITH USER_MODE
      LIMIT 1
    ]) {
      contactId = u.ContactId;
    }

    if (contactId == null) {
      return new List<OrderCard>();
    }

    // bind contactId so internal users impersonating cannot widen the filter via injection
    List<Order> orders = [
      SELECT
        OrderNumber,
        Status,
        EffectiveDate,
        TotalAmount,
        (SELECT Product2.Name FROM OrderItems LIMIT 3)
      FROM Order
      WHERE BillToContactId = :contactId
      WITH USER_MODE
      ORDER BY EffectiveDate DESC NULLS LAST
      LIMIT :clamped
    ];

    List<OrderCard> result = new List<OrderCard>();
    for (Order o : orders) {
      OrderCard card = new OrderCard();
      card.orderNumber = o.OrderNumber;
      card.status = o.Status;
      card.orderDate = o.EffectiveDate;
      card.total = (o.TotalAmount == null) ? 0 : o.TotalAmount;

      List<String> names = new List<String>();
      if (o.OrderItems != null) {
        for (OrderItem oi : o.OrderItems) {
          if (oi.Product2 != null && oi.Product2.Name != null) {
            names.add(oi.Product2.Name);
            if (names.size() == 3) {
              break;
            }
          }
        }
      }
      card.productSummary = String.join(names, ', ');
      result.add(card);
    }
    return result;
  }

  public class OrderCard {
    @AuraEnabled
    public String orderNumber;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public Date orderDate;
    @AuraEnabled
    public Decimal total;
    @AuraEnabled
    public String productSummary;
  }
}
