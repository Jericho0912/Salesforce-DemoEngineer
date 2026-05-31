# Architecture Decisions — NTO Service Demo

The walkthrough cheat sheet. Every choice below is defensible line-by-line.

---

### 1. Lifetime value & open-case count are computed in Apex, not stored

No `Lifetime_Value__c` field, no rollup summary, no trigger. `Customer360Controller.getCustomerSummary` computes them at query time with aggregate SOQL (`SUM(Total__c)`, `COUNT(Id) GROUP BY Priority`).

- **Why:** always accurate, nothing to keep in sync, no trigger maintenance, no rollup recalculation lag. The lookup-not-master-detail relationship on `NTO_Order__c` rules out roll-up summary fields anyway.
- **Trade-off:** a few SOQL queries per page load — fine for a 360 view; `cacheable=true` absorbs repeat reads.

### 2. `with sharing` on every controller

`Customer360Controller`, `OrderStatusAction`, and `PortalCustomerController` all run `with sharing`.

- **Why:** the same code runs for internal agents and external community users. `with sharing` enforces the running user's record visibility, so the portal can't leak one customer's data to another. Critical for the Experience Cloud guest/community context.

### 3. `cacheable=true` on read methods

`getCustomerSummary` and `getMyProfile` are `@AuraEnabled(cacheable=true)`.

- **Why:** enables client-side caching and lets the LWC use `@wire` (which requires cacheable). Faster, fewer server round-trips, automatic refresh on parameter change.
- **What it forbids:** no DML in a cacheable method. That's why returns are created by a **Flow**, not by the read controller.

### 4. `@wire` vs imperative Apex

Everything here uses `@wire` (declarative).

- **Why `@wire`:** the data is read-only and reactive to `recordId` — `@wire` re-runs automatically when the record changes, integrates with the LDS cache, and keeps the JS thin. `getRecord` (`@wire`) pulls Contact display fields straight from the UI API with no Apex round-trip.
- **When I'd go imperative:** for actions triggered by a button/user event, or non-cacheable calls that do DML (e.g. a "Create Return" button calling an imperative method). None of the read views need that.

### 5. Computed wrapper classes (DTOs) returned to LWC

Controllers return inner wrapper classes (`CustomerSummary`, `CaseInfo`, `OrderInfo`) with `@AuraEnabled` fields, not raw SObjects.

- **Why:** the component gets exactly the shape it needs, decoupled from the data model, and we don't over-expose fields.

### 6. Flow for the return, Apex invocable for order status

- **Return Request → Flow (`NTO_Create_Return`):** record creation (DML) that an admin can edit without code; declarative tools are the right call for a simple "create a Case" path, and it slots directly into Agentforce as an action.
- **Order Status → Apex invocable (`OrderStatusAction`):** needs a bulk-safe query against an External ID and a formatted, customer-ready sentence back — cleaner and more testable in Apex than in Flow.
- **Rule of thumb:** declarative for straightforward DML, Apex when there's query logic, formatting, or bulk handling.

### 7. One service layer feeds four channels — build once, reuse everywhere

`Customer360Controller.getCustomerSummary` is consumed by:

1. `customer360` LWC (Contact record page),
2. `customer360OnCase` wrapper (Service Console Case page),
3. `PortalCustomerController` (Experience Cloud portal) — which _calls_ it directly,
4. and the same data model backs `OrderStatusAction` / `NTO_Create_Return` for Agentforce.

- **Why:** the risk/lifetime/case logic exists in exactly one place. Fix it once, every surface benefits. This is the core story of the demo.

### 8. Thin Case-context wrapper instead of overloading the 360 component

`customer360` is Contact-driven; `customer360OnCase` wires the Case's `ContactId` and hands it down.

- **Why:** keeps `customer360` single-responsibility and reusable, while still serving the Case workspace. No branching logic inside the shared component.

### 9. Portal resolves the contact server-side from `UserInfo` — never a recordId

`PortalCustomerController.getMyProfile()` derives the contact from `UserInfo.getUserId()` → `User.ContactId`.

- **Why:** a community/guest user must only ever see their own data. Accepting a recordId from the page would let a user request someone else's record. Combined with `with sharing` + a Sharing Set on `NTO_Order__c`, access is enforced at the platform level, not just the query.

### 10. `Order_Number__c` as an External ID (+ Unique)

- **Why:** the Agentforce order-status action looks orders up by this human-facing value; an External ID makes it an indexed, exact, upsert-friendly key.

### 11. Metadata-only, deploy-by-path, idempotent seed

No org-specific hardcoding; `setup.ps1`/`setup.sh` deploy → assign perm set → seed. The org isn't source-tracked, so deploys are path-based and all-or-nothing.

- **Why:** satisfies the "another SE deploys with zero code changes" bar. The seed deletes prior `NTO %` records first so demos are repeatable.
