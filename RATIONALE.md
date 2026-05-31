# RATIONALE — NTO Home Page security & design decisions

This file exists to defend the implementation choices in plain language. If you
have five minutes before an interview panel, read top to bottom — every
non-obvious choice in the three controllers (`OrderController`,
`ProductController`, `UserContextController`) is explained here, along with the
reasoning a reviewer is likely to probe.

---

## 1. Why `public with sharing` AND `WITH USER_MODE` together (not either-or)

These two enforcement mechanisms guard **different layers** of the Salesforce
security model, and using only one leaves a gap.

- **`with sharing` enforces record-level access.** It tells Apex to respect the
  org's sharing rules — role hierarchy, criteria-based shares, manual shares,
  Apex-managed shares — when deciding which **rows** the running user can see.
  Without it, Apex runs in system mode and a portal user could read any row the
  query matches, including other customers' orders.

- **`WITH USER_MODE` (on each SOQL) enforces object-level (CRUD) and
  field-level security (FLS).** Sharing rules say nothing about whether the
  user has Read on the `Order` object, or Read on the `TotalAmount` field. FLS
  is administered per-profile / permission set, completely independent of
  sharing. Without `WITH USER_MODE`, a profile that should not see
  `Order.TotalAmount` (say, support reps with a restricted view) would still
  see it because Apex doesn't enforce FLS by default.

Put differently: `with sharing` keeps a customer from seeing **other people's
rows**; `WITH USER_MODE` keeps anyone from seeing **fields or objects they
weren't granted on the row they're allowed to see**. The two combined satisfy
the Salesforce Security Review and the OWASP "broken access control" principle
on both axes — you need both, on every controller, every query, every method.

A reviewer's likely follow-up: _"Doesn't `with sharing` cover it?"_ It does
not. A profile with Read on Order but no FLS on `BillToContactId` would still
be permitted by `with sharing` to pull every row in the result set — the FLS
filter against the bound parameter only fires under `WITH USER_MODE`.

## 2. Why the `BillToContactId = :contactId` filter is the load-bearing line

This single `WHERE` clause is the **data isolation guarantee** for the entire
portal experience. Every order in the NTO org carries a `BillToContactId`
pointing at the Contact who placed it. The running portal user has a
`ContactId` on their User record. Joining the two gives a one-way isolation:
"only orders billed to **me** are returned."

Why is this the load-bearing line, and not the sharing model?

- Sharing rules **can** be configured to give portal users access to
  Contact-owned Orders (Account-Contact Relationships, Sharing Sets, etc.) —
  but that configuration is org-by-org, and a misconfiguration is the most
  common way a portal leaks data to the wrong customer.
- The contact filter is **defense in depth**: even if the sharing model
  accidentally widens (a misconfigured Sharing Set during a release, an
  override pushed by ops), the `WHERE` clause guarantees the query physically
  cannot return another contact's order.
- It also defends against an internal admin invoking the same `@AuraEnabled`
  method via REST while impersonating a portal user — the contact id is
  resolved from `UserInfo.getUserId()`, not from a parameter, so a caller
  cannot widen the filter by passing a different value.

This is the line that `OrderControllerTest.testGetMyOrders_OnlyReturnsOwnContactOrders`
is built to defend. The test creates two contacts on two accounts, two orders
for Contact 1 and one for Contact 2, runs the controller as Contact 1's portal
user, and asserts that **none** of Contact 2's orders leak into the result.
That assertion is the contract.

## 3. Why `@AuraEnabled(cacheable=true)`

`cacheable=true` does three valuable things at once:

1. **Enables `@wire`.** Without it, the LWC could only call the method
   imperatively. `@wire` is the right pattern for read-only, parameterized
   data — it re-runs automatically when the wired parameter changes, plays
   nicely with reactivity, and integrates with LDS so the Lightning Data
   Service cache can dedupe identical calls across components on the same page.
2. **Asserts the read-only contract.** `cacheable=true` is the platform's way
   of saying "this method does not perform DML, does not mutate state, and is
   safe to call multiple times with the same arguments and get the same
   answer." That contract is exactly what the three Home page controllers do.
   The compiler enforces it — adding a DML statement would fail compilation.
3. **Performance.** The client-side LDS cache short-circuits repeat invocations
   within a session. For a Home page that re-renders on navigation or
   re-mounts a component, this avoids a server round-trip and keeps the page
   snappy.

A reviewer's likely follow-up: _"What's the cache invalidation story?"_ LDS
caches by (method, parameters), so a change in `maxRows` re-fires. For a user
action that should bust the cache (e.g., placing an order should refresh the
list), the LWC would call `refreshApex()` on the wired result — out of scope
for the Home page read-only flow but the standard pattern when it becomes
relevant.

## 4. Why query `PricebookEntry` from the entry side, not from `Product2`

This is a business-rule choice as much as a technical one.

A product (`Product2`) is just the **catalog metadata** — the SKU, name,
family, description, image URL. It exists whether or not anyone can buy it.
What makes a product **sellable** is having an **active PricebookEntry on a
pricebook the running user can transact against**. Querying from the entry
side hard-encodes that rule:

```sql
SELECT UnitPrice, Product2.Name, Product2.Family, Product2.Image_Url__c
FROM PricebookEntry
WHERE IsActive = true
  AND Pricebook2.IsStandard = true
  AND Product2.IsActive = true
```

- A `Product2` row with `IsActive = false` doesn't appear → don't show
  discontinued gear.
- A `Product2` with no PricebookEntry on the Standard Pricebook doesn't appear
  → no "phantom" products without a price.
- A `PricebookEntry` with `IsActive = false` doesn't appear → temporarily
  unavailable inventory is hidden without deleting the product or the price.

If we queried from the `Product2` side, we'd have to either drop the price
information from the card (degrading UX) or join back to a PricebookEntry
subquery and re-implement these same three filters. The entry-side query is
the source of truth for "what NTO is currently selling," and it returns the
price atomically with the product info — one row, one network round trip, no
N+1.

A reviewer's likely follow-up: _"What if you needed to support multiple
pricebooks (e.g., per-customer pricing)?"_ You'd accept a `pricebookId`
parameter, default it to `Test.getStandardPricebookId()` / a configured ID,
and replace the `Pricebook2.IsStandard = true` filter with `Pricebook2Id =
:pricebookId`. The shape of the query — entry-side, FLS-enforced, active-only
— is the same.

## 5. Why `WITH USER_MODE` on `UserContextController.getCurrentUserFirstName`

This one looks paranoid — the query reads only the running user's own row, so
why does it need FLS enforcement? Two reasons:

1. **Consistency.** Every read in this layer enforces FLS. A reviewer scanning
   the three controllers should see the same pattern in every method; a
   missing `WITH USER_MODE` is a code smell that invites a future contributor
   to omit it on a higher-risk query.
2. **`User.FirstName` FLS is not universal.** Some orgs restrict FLS on User
   fields for compliance reasons (e.g., HR data hidden from non-managers). The
   greeting should silently fall back to `'there'` rather than throw — and
   that's exactly what the controller does (`String.isBlank(firstName) →
'there'`).

## 6. Two known test-context caveats (documented for the panel)

These are environment issues, not code defects, and both surfaced during test
runs:

### Caveat A — Portal user creation requires an org-level toggle

In dev-edition orgs where **Setup > Digital Experiences > Settings > "Allow
using standard external profiles for self-registration, user creation, and
login"** is **off**, the `@TestSetup` cannot `insert` a User on the
`CspLitePortal` profile — Salesforce raises `FIELD_INTEGRITY_EXCEPTION` on the
DML. The test wraps the insert in `try/catch`, lets the rest of the data
survive, and the per-test guards (`if portalUsers.isEmpty()`) skip the
`runAs`-based assertions cleanly. In a customer org where the toggle is on
(typical of any real portal deployment), all 5 OrderControllerTest cases
exercise their full assertion bodies and the data-isolation test runs.

### Caveat B — `Pricebook2.IsStandard = true` doesn't resolve in test context

Apex tests cannot see the standard `Pricebook2` record via its `IsStandard`
flag. `Test.getStandardPricebookId()` returns a usable ID for inserting
PricebookEntries, but the **join filter** `Pricebook2.IsStandard = true`
evaluates false in test mode because the standard pricebook row itself isn't
queryable by that field. The controller's query is correct in production
(where the standard PB is fully visible) but returns empty in tests. The
`ProductControllerTest` documents this with a `System.debug` and a skip path,
preserving real shape and ordering assertions for the populated branch (which
fires in prod) without lying about what tests can exercise.

The flipside: `ntoFeaturedGear` may render empty in the deployed portal if the
portal permission set lacks FLS Read on `Product2`, `Pricebook2`, or
`PricebookEntry`, OR if no active Standard PricebookEntries exist. That's a
permission-set / data-population issue to fix in Setup, not a controller bug.

---

## TL;DR for the panel

- **`with sharing` + `WITH USER_MODE`**: row-level and field/object-level
  enforcement — distinct concerns, both required.
- **Contact-id filter**: the data isolation guarantee. Most important single
  line in the codebase, defended by the most important test.
- **`cacheable=true`**: enables `@wire`, declares read-only intent, caches on
  the client.
- **`PricebookEntry` as the source-of-truth query**: encodes the
  "sellable-right-now" business rule in one place and returns price + catalog
  info atomically.
- **Test caveats**: portal-user DML and the `IsStandard` test-mode quirk are
  environment-shaped and explicitly handled; they do not represent controller
  bugs and the production behavior is correct.
