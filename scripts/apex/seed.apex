// ============================================================
// NTO Demo — Seed Data (anonymous Apex)
// Why this approach: one bulk DML per object (no SOQL/DML in loops) keeps the
// script governor-safe and re-runnable. It is idempotent — every run first
// deletes prior 'NTO %' demo records, so presenters get a clean dataset and a
// guaranteed "At Risk" hero contact without manual cleanup.
// Run: sf apex run -f scripts/apex/seed.apex -o Demo-Org
// ============================================================

// ---- 1. Cleanup (child-first to respect lookups) ----
delete [SELECT Id FROM NTO_Order__c WHERE Contact__r.Account.Name LIKE 'NTO %'];
delete [SELECT Id FROM Case WHERE Account.Name LIKE 'NTO %'];
delete [SELECT Id FROM Contact WHERE Account.Name LIKE 'NTO %'];
delete [SELECT Id FROM Account WHERE Name LIKE 'NTO %'];

// ---- 2. Accounts (25 + 1 hero) ----
List<Account> accounts = new List<Account>();
for (Integer i = 1; i <= 25; i++) {
    accounts.add(new Account(Name = 'NTO Customer ' + i));
}
Account heroAccount = new Account(Name = 'NTO Hero Account');
accounts.add(heroAccount);
insert accounts;

// ---- 3. Contacts (50 regular + 1 hero) ----
List<String> firsts = new List<String>{
    'Alex','Jordan','Taylor','Morgan','Casey','Riley','Jamie','Quinn','Dana','Drew'
};
List<Contact> contacts = new List<Contact>();
for (Integer i = 0; i < 50; i++) {
    Account a = accounts[Math.mod(i, 25)];
    contacts.add(new Contact(
        FirstName = firsts[Math.mod(i, firsts.size())],
        LastName  = 'Customer ' + (i + 1),
        AccountId = a.Id,
        Email     = 'customer' + (i + 1) + '@nto-demo.com'
    ));
}
Contact hero = new Contact(
    FirstName = 'Avery',
    LastName  = 'Stone',
    AccountId = heroAccount.Id,
    Email     = 'avery.stone@nto-demo.com'
);
contacts.add(hero); // keep one DML; hero.Id is populated after insert
insert contacts;

// ---- 4. Cases (80 varied + 3 hero open High-priority) ----
List<String> openStatuses = new List<String>{ 'New', 'Working', 'Escalated' };
List<String> priorities   = new List<String>{ 'High', 'Medium', 'Low' };
List<Case> cases = new List<Case>();
for (Integer i = 0; i < 80; i++) {
    Contact c = contacts[Math.mod(i, contacts.size())];
    String status = (Math.mod(i, 4) == 0) ? 'Closed' : openStatuses[Math.mod(i, 3)];
    cases.add(new Case(
        Subject   = 'Inquiry #' + (i + 1),
        Status    = status,
        Priority  = priorities[Math.mod(i, 3)],
        ContactId = c.Id,
        AccountId = c.AccountId
    ));
}
// Hero risk trigger: 3 open High-priority cases (>= 2 required for "At Risk")
List<String> heroCaseStatus = new List<String>{ 'Escalated', 'Working', 'New' };
for (Integer i = 0; i < 3; i++) {
    cases.add(new Case(
        Subject   = 'Hero escalation #' + (i + 1),
        Status    = heroCaseStatus[i],
        Priority  = 'High',
        ContactId = hero.Id,
        AccountId = heroAccount.Id
    ));
}
insert cases;

// ---- 5. Orders (30 varied + 4 hero high-value) ----
List<String> orderStatuses = new List<String>{ 'Processing', 'Shipped', 'Delivered', 'Returned' };
List<NTO_Order__c> orders = new List<NTO_Order__c>();
for (Integer i = 0; i < 30; i++) {
    Contact c = contacts[Math.mod(i * 7, 50)];
    Decimal total = 50 + Math.mod(i * 37, 950); // 50..999
    String num = 'ORD-' + (1000 + (i + 1));     // ORD-1001 .. ORD-1030
    orders.add(new NTO_Order__c(
        Name            = num,
        Order_Number__c = num,
        Total__c        = total,
        Status__c       = orderStatuses[Math.mod(i, 4)],
        Contact__c      = c.Id
    ));
}
List<Decimal> heroTotals = new List<Decimal>{ 1299.00, 849.50, 2150.00, 499.99 };
List<String>  heroOrderStatus = new List<String>{ 'Delivered', 'Shipped', 'Delivered', 'Processing' };
for (Integer i = 0; i < 4; i++) {
    String num = 'ORD-' + (2000 + (i + 1));     // ORD-2001 .. ORD-2004
    orders.add(new NTO_Order__c(
        Name            = num,
        Order_Number__c = num,
        Total__c        = heroTotals[i],
        Status__c       = heroOrderStatus[i],
        Contact__c      = hero.Id
    ));
}
insert orders;

System.debug('=== NTO SEED COMPLETE ===');
System.debug('Accounts: ' + accounts.size() + ' | Contacts: ' + contacts.size() +
             ' | Cases: ' + cases.size() + ' | Orders: ' + orders.size());
System.debug('HERO CONTACT (At Risk): Avery Stone | Id=' + hero.Id +
             ' | 4 orders, 3 open High-priority cases');
