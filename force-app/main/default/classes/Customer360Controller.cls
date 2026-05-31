/**
 * Why this approach: a single `with sharing`, `cacheable=true` service method is the one
 * read API that LWC, the Service Console, the portal, and Agentforce all reuse — build once,
 * surface everywhere. Lifetime value and open-case counts are computed here at query time
 * (aggregate SOQL) rather than stored as rollup fields, so the numbers are always accurate
 * with nothing to keep in sync. No DML lives here, which is exactly what `cacheable=true` requires.
 */
public with sharing class Customer360Controller {
  @AuraEnabled(cacheable=true)
  public static CustomerSummary getCustomerSummary(Id contactId) {
    if (contactId == null) {
      throw new AuraHandledException('A contact id is required.');
    }

    List<Contact> contacts = [
      SELECT Id, Name, Email, Account.Name
      FROM Contact
      WHERE Id = :contactId
      LIMIT 1
    ];
    if (contacts.isEmpty()) {
      throw new AuraHandledException('Contact not found or not accessible.');
    }
    Contact c = contacts[0];

    CustomerSummary summary = new CustomerSummary();
    summary.contactId = c.Id;
    summary.name = c.Name;
    summary.email = c.Email;
    summary.accountName = (c.Account != null) ? c.Account.Name : null;

    // Lifetime value: SUM of order totals, computed at query time (never stored).
    AggregateResult ltv = [
      SELECT SUM(Total__c) total
      FROM NTO_Order__c
      WHERE Contact__c = :contactId
    ];
    Decimal total = (Decimal) ltv.get('total');
    summary.lifetimeValue = (total == null) ? 0 : total;

    // Open case counts grouped by priority in one query — drives both the
    // open-case KPI and the "At Risk" flag (2+ open High-priority cases).
    Integer openCount = 0;
    Integer openHighCount = 0;
    for (AggregateResult ar : [
      SELECT Priority, COUNT(Id) cnt
      FROM Case
      WHERE ContactId = :contactId AND IsClosed = FALSE
      GROUP BY Priority
    ]) {
      Integer cnt = (Integer) ar.get('cnt');
      openCount += cnt;
      if ('High'.equals((String) ar.get('Priority'))) {
        openHighCount += cnt;
      }
    }
    summary.openCaseCount = openCount;
    summary.atRisk = openHighCount >= 2;

    // Last 5 cases (any status), newest first.
    List<CaseInfo> recent = new List<CaseInfo>();
    for (Case cs : [
      SELECT Id, CaseNumber, Subject, Status, Priority, CreatedDate, IsClosed
      FROM Case
      WHERE ContactId = :contactId
      ORDER BY CreatedDate DESC
      LIMIT 5
    ]) {
      recent.add(new CaseInfo(cs));
    }
    summary.recentCases = recent;

    return summary;
  }

  public class CustomerSummary {
    @AuraEnabled
    public Id contactId;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String email;
    @AuraEnabled
    public String accountName;
    @AuraEnabled
    public Decimal lifetimeValue;
    @AuraEnabled
    public Integer openCaseCount;
    @AuraEnabled
    public Boolean atRisk;
    @AuraEnabled
    public List<CaseInfo> recentCases = new List<CaseInfo>();
  }

  public class CaseInfo {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String caseNumber;
    @AuraEnabled
    public String subject;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public String priority;
    @AuraEnabled
    public Datetime createdDate;
    @AuraEnabled
    public Boolean isClosed;

    public CaseInfo(Case cs) {
      this.id = cs.Id;
      this.caseNumber = cs.CaseNumber;
      this.subject = cs.Subject;
      this.status = cs.Status;
      this.priority = cs.Priority;
      this.createdDate = cs.CreatedDate;
      this.isClosed = cs.IsClosed;
    }
  }
}
