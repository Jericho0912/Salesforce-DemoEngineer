# Portal Customer Users — Setup Guide

This document records every step taken to provision the two Experience Cloud portal users used in the NTO interview demo, including the blockers hit and how they were resolved.

---

## Overview

Two Experience Cloud customer users were created so an interview panel can log into the NTO portal, submit Cases, and verify that each user only sees their own data. They are on **separate Accounts** to enable record-level isolation testing.

| User             | Username                      | Contact                                 | Account                                 | User ID              |
| ---------------- | ----------------------------- | --------------------------------------- | --------------------------------------- | -------------------- |
| Avery Stone      | `avery.stone@nto-portal.demo` | Avery Stone (`003NS00002B6LxfYAF`)      | NTO Hero Account (`001NS00002mWMh7YAG`) | `005NS000010AbozYAC` |
| Drew Customer 50 | `customer50@nto-portal.demo`  | Drew Customer 50 (`003NS00002B6LxeYAF`) | NTO Customer 25 (`001NS00002mWMh6YAG`)  | `005NS000010Abp0YAC` |

---

## Phase 1 — Discovery

Queries run against the org before creating anything:

### Contacts

Queried 20 most recent Contacts with a non-null Email. The two candidates above were selected because they sit on **different Accounts**, which is required to demonstrate Case data isolation between portal users.

### Portal-capable profiles

The org contains Customer Community and Customer Community Plus variants. **Customer Community Plus Login User** (`00eNS00000KZ98hYAD`, UserType `PowerCustomerSuccess`) was chosen because:

- Login-based licensing (no per-member seat cost)
- Full Case create/edit support
- Enables account-based roles (Manager/User) needed for Sharing Sets to enforce per-account visibility

### Experience sites

| Site                                   | Status at discovery |
| -------------------------------------- | ------------------- |
| coral-cloud                            | Live                |
| The Northern Trail Outfitters          | Published/Active    |
| The Northern Trail Outfitters Customer | DownForMaintenance  |
| Default Help Center                    | UnderConstruction   |

The Northern Trail Outfitters site is used for this demo.

---

## Phase 2 — Permission Set

**File:** `force-app/main/default/permissionsets/NTO_Portal_Customer.permissionset-meta.xml`

Created and deployed. Grants:

| Object     | Create | Read | Edit | Delete | View All              |
| ---------- | ------ | ---- | ---- | ------ | --------------------- |
| Case       | ✅     | ✅   | ✅   | —      | ❌ (own records only) |
| Order      | —      | ✅   | —    | —      | ❌ (own records only) |
| OrderItem  | —      | ✅   | —    | —      | ❌ (own records only) |
| Product2   | —      | ✅   | —    | —      | ✅ (public catalog)   |
| Pricebook2 | —      | ✅   | —    | —      | ✅ (public catalog)   |

FLS: `Product2.Image_Url__c` — readable (note: field API name is `Image_Url__c`, not `Image_URL__c`).

Deploy ID: `0AfNS00000h4TFZ0A2` — **Succeeded**.

---

## Phase 3 — User Creation

**Script:** `scripts/apex/create_portal_users.apex`

Run via:

```
sf apex run --file scripts/apex/create_portal_users.apex --target-org Demo-Org
```

### Blockers hit (and resolved)

#### Blocker 1 — External profile gate

**Error:** `FIELD_INTEGRITY_EXCEPTION: To create or update users for this profile, go to Setup > Digital Experiences > Settings and select Allow using standard external profiles...`

**Fix:** Setup → Digital Experiences → Settings → enable **"Allow using standard external profiles for self-registration, user creation, and login"** → Save.

#### Blocker 2 — Account owner has no role

**Error:** `UNKNOWN_EXCEPTION: portal account owner must have a role`

**Root cause:** Both target Accounts (`NTO Hero Account`, `NTO Customer 25`) were owned by user `005NS00000zDqC9YAK` (jericho rosario) who had `UserRoleId = null`. Salesforce requires the Account owner to be in the role hierarchy before a portal user can be attached to that Account.

**Fix:** Assigned the **CEO** role (`00ENS00000bbiG62AI`) to that user:

```
sf data update record --sobject User --record-id 005NS00000zDqC9YAK \
  --values "UserRoleId=00ENS00000bbiG62AI" --target-org Demo-Org
```

### Permission set assignment

```
sf org assign permset --name NTO_Portal_Customer \
  --on-behalf-of avery.stone@nto-portal.demo --target-org Demo-Org

sf org assign permset --name NTO_Portal_Customer \
  --on-behalf-of customer50@nto-portal.demo --target-org Demo-Org
```

Both assignments: **Succeeded**.

---

## What you must still do manually

These steps cannot be done via the CLI or metadata deployment — they are click-only in Setup.

### 1. Set passwords for both portal users

The SF CLI cannot set passwords for portal/community users. Go to:

> Setup → Users → Users → find each user → **Reset Password**

This sends a reset email to each user's address. For the demo, if you need a known password, use the reset link to set one yourself, or create a temporary email alias.

| User                        | Email the reset goes to  |
| --------------------------- | ------------------------ |
| avery.stone@nto-portal.demo | avery.stone@nto-demo.com |
| customer50@nto-portal.demo  | customer50@nto-demo.com  |

### 2. Configure record-level isolation (OWD + Sharing Sets)

Record-level isolation — ensuring each portal user sees only their own Cases/Orders — is **not** enforced yet. The permission set alone does not isolate records.

Required configuration:

**A. Organisation-Wide Defaults (OWD)**

> Setup → Sharing Settings

Set OWD for:

- **Case** → `Private` (or leave as-is if already Private)
- **Order** → `Private`

If OWD is already Private, portal users will only see records they own or that are explicitly shared with them/their Account.

**B. Sharing Sets (for portal users)**

> Setup → Digital Experiences → Settings → Sharing Sets → New

Create one Sharing Set per object that portal users need to read:

- **Case Sharing Set** — map `User.ContactId → Case.ContactId` (or `User.AccountId → Case.AccountId`) with `Read/Write` access
- **Order Sharing Set** — map `User.AccountId → Order.AccountId` with `Read Only` access

This ensures each portal user only sees Cases and Orders linked to their own Account/Contact — without this, either everyone sees nothing or (if OWD is Public Read) everyone sees everything.

### 3. Add portal users to the Experience site membership

> Setup → Digital Experiences → All Sites → The Northern Trail Outfitters → Workspaces → Administration → Members

Ensure the **Customer Community Plus Login User** profile (or the specific users) are listed as site members. Without this, users can log in to Salesforce but not access the portal.

---

## Reference IDs

| Item                                            | ID                                                                      |
| ----------------------------------------------- | ----------------------------------------------------------------------- |
| Profile — Customer Community Plus Login User    | `00eNS00000KZ98hYAD`                                                    |
| Permission Set — NTO Portal Customer            | (query `SELECT Id FROM PermissionSet WHERE Name='NTO_Portal_Customer'`) |
| Experience Site — The Northern Trail Outfitters | `0DBNS000005d31Z4AQ`                                                    |
| Account — NTO Hero Account                      | `001NS00002mWMh7YAG`                                                    |
| Account — NTO Customer 25                       | `001NS00002mWMh6YAG`                                                    |
| Contact — Avery Stone                           | `003NS00002B6LxfYAF`                                                    |
| Contact — Drew Customer 50                      | `003NS00002B6LxeYAF`                                                    |
| User — avery.stone@nto-portal.demo              | `005NS000010AbozYAC`                                                    |
| User — customer50@nto-portal.demo               | `005NS000010Abp0YAC`                                                    |
| Role — CEO (assigned to Account owner)          | `00ENS00000bbiG62AI`                                                    |
