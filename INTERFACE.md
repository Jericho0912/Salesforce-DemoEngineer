# NTO Home Page — LWC ↔ Apex Interface Contract

This is the **fixed contract** the three Lightning Web Components and the three Apex
controllers are built against. Subagents A–D implement against this document only.
Do not change a signature or wrapper shape without updating this file first.

API version: **66.0**.

---

## 1. `OrderController.getMyOrders(Integer maxRows)`

- **Signature**
  ```apex
  @AuraEnabled(cacheable=true)
  public static List<OrderCard> getMyOrders(Integer maxRows)
  ```
- **Behavior**
  - Resolves the running user to their `ContactId` via `UserInfo.getUserId()`.
  - If the user has no `ContactId`, returns an empty list (not null).
  - Queries Orders `WHERE BillToContactId = :contactId` `ORDER BY EffectiveDate DESC`
    `LIMIT :maxRows` with a child subquery on `OrderItems` (limit 3) joined to
    `Product2.Name`.
  - All SOQL uses `WITH USER_MODE`.
  - `maxRows` is clamped: null or ≤ 0 → 5; > 100 → 100.
- **Returns** `List<OrderCard>`. Empty list when no orders. Never null.

### `OrderCard` wrapper (returned to LWC as JSON)

| field            | Apex type | JSON key         | Notes                                                         |
| ---------------- | --------- | ---------------- | ------------------------------------------------------------- |
| `orderNumber`    | `String`  | `orderNumber`    | `Order.OrderNumber`                                           |
| `status`         | `String`  | `status`         | `Order.Status` (e.g. `Processing`, `Shipped`, `Delivered`)    |
| `orderDate`      | `Date`    | `orderDate`      | `Order.EffectiveDate`                                         |
| `total`          | `Decimal` | `total`          | `Order.TotalAmount`; 0 if null                                |
| `productSummary` | `String`  | `productSummary` | Up to 3 `Product2.Name` values joined with `, ` (no ellipsis) |

All fields exposed `@AuraEnabled` (public). Empty list if user has no contact /
no matching orders.

---

## 2. `ProductController.getFeaturedGear(Integer maxRows)`

- **Signature**
  ```apex
  @AuraEnabled(cacheable=true)
  public static List<GearItem> getFeaturedGear(Integer maxRows)
  ```
- **Behavior**
  - Queries from the `PricebookEntry` side (the price is the contract — products
    without a Standard PricebookEntry are not "for sale").
  - Filter: `IsActive = true AND Pricebook2.IsStandard = true AND Product2.IsActive = true`.
  - Order: `Product2.Name ASC` (stable for tests).
  - `WITH USER_MODE`.
  - `maxRows` clamped: null or ≤ 0 → 4; > 50 → 50.
- **Returns** `List<GearItem>`. Empty list when no entries.

### `GearItem` wrapper

| field      | Apex type | JSON key   | Notes                                               |
| ---------- | --------- | ---------- | --------------------------------------------------- |
| `name`     | `String`  | `name`     | `Product2.Name`                                     |
| `family`   | `String`  | `family`   | `Product2.Family` (may be null)                     |
| `price`    | `Decimal` | `price`    | `PricebookEntry.UnitPrice`                          |
| `imageUrl` | `String`  | `imageUrl` | `Product2.Image_Url__c` (custom field; may be null) |

All fields exposed `@AuraEnabled`.

---

## 3. `UserContextController.getCurrentUserFirstName()`

- **Signature**
  ```apex
  @AuraEnabled(cacheable=true)
  public static String getCurrentUserFirstName()
  ```
- **Behavior**
  - Queries `SELECT FirstName FROM User WHERE Id = :UserInfo.getUserId() WITH USER_MODE`.
  - Returns the trimmed `FirstName`. Falls back to `'there'` (no exclamation) when
    `FirstName` is blank, so the banner reads "Welcome back, there".
- **Returns** `String`. Never null.

---

## LWC ↔ Apex imports

Components must import:

```js
import getMyOrders from "@salesforce/apex/OrderController.getMyOrders";
import getFeaturedGear from "@salesforce/apex/ProductController.getFeaturedGear";
import getCurrentUserFirstName from "@salesforce/apex/UserContextController.getCurrentUserFirstName";
```

All three methods are `@AuraEnabled(cacheable=true)` and are intended to be consumed via
`@wire`, not imperative calls.

## `@api` config exposed in Experience Builder

| Component         | `@api` prop     | Default | Notes                           |
| ----------------- | --------------- | ------- | ------------------------------- |
| `welcomeToast`    | `autoDismissMs` | 5000    | Auto-dismiss timeout in ms.     |
| `ntoMyOrders`     | `maxRows`       | 5       | Forwarded to `getMyOrders`.     |
| `ntoFeaturedGear` | `maxRows`       | 4       | Forwarded to `getFeaturedGear`. |
