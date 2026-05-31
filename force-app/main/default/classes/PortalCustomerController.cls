/**
 * Why this approach: the portal must show the *logged-in customer's* own data, so this controller
 * resolves the contact from UserInfo rather than trusting a recordId passed from the page — a guest
 * or community user can never request someone else's record. `with sharing` keeps record visibility
 * under the org's sharing rules (a sharing set grants each community user their own orders/cases),
 * and it reuses Customer360Controller for the case/risk/lifetime math so the logic lives in one place.
 */
public with sharing class PortalCustomerController {
  @AuraEnabled(cacheable=true)
  public static PortalProfile getMyProfile() {
    return buildProfile(resolveMyContactId());
  }

  /**
   * Standalone order list for the portal My Orders page.
   * Resolves the logged-in user's contact server-side — never accepts a page-passed recordId.
   */
  @AuraEnabled(cacheable=true)
  public static List<OrderInfo> getMyOrders() {
    return buildOrders(resolveMyContactId());
  }

  /**
   * Standalone case list for the portal My Cases page.
   * Resolves the logged-in user's contact server-side — never accepts a page-passed recordId.
   */
  @AuraEnabled(cacheable=true)
  public static List<Customer360Controller.CaseInfo> getMyCases() {
    Id contactId = resolveMyContactId();
    List<Customer360Controller.CaseInfo> cases = new List<Customer360Controller.CaseInfo>();
    for (Case cs : [
      SELECT Id, CaseNumber, Subject, Status, Priority, CreatedDate, IsClosed
      FROM Case
      WHERE ContactId = :contactId
      ORDER BY CreatedDate DESC
      LIMIT 20
    ]) {
      cases.add(new Customer360Controller.CaseInfo(cs));
    }
    return cases;
  }

  @TestVisible
  private static Id resolveMyContactId() {
    User u = [
      SELECT ContactId
      FROM User
      WHERE Id = :UserInfo.getUserId()
      LIMIT 1
    ];
    if (u.ContactId == null) {
      throw new AuraHandledException(
        'Your account is not linked to a customer contact.'
      );
    }
    return u.ContactId;
  }

  @TestVisible
  private static PortalProfile buildProfile(Id contactId) {
    PortalProfile profile = new PortalProfile();
    // Reuse the shared service layer for name, lifetime value, open cases, risk, recent cases.
    profile.summary = Customer360Controller.getCustomerSummary(contactId);
    profile.orders = buildOrders(contactId);
    return profile;
  }

  @TestVisible
  private static List<OrderInfo> buildOrders(Id contactId) {
    List<OrderInfo> orders = new List<OrderInfo>();
    for (NTO_Order__c o : [
      SELECT Order_Number__c, Status__c, Total__c
      FROM NTO_Order__c
      WHERE Contact__c = :contactId
      ORDER BY CreatedDate DESC
    ]) {
      orders.add(new OrderInfo(o));
    }
    return orders;
  }

  public class PortalProfile {
    @AuraEnabled
    public Customer360Controller.CustomerSummary summary;
    @AuraEnabled
    public List<OrderInfo> orders = new List<OrderInfo>();
  }

  public class OrderInfo {
    @AuraEnabled
    public String orderNumber;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public Decimal total;

    public OrderInfo(NTO_Order__c o) {
      this.orderNumber = o.Order_Number__c;
      this.status = o.Status__c;
      this.total = o.Total__c;
    }
  }
}
