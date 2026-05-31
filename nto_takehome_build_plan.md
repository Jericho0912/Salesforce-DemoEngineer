# NTO Demo Engineer Take-Home — Build Plan (Handoff Spec for Claude CLI)

> Target org: SFDX-authenticated dev/scratch org via `sf` CLI (never username/password).
> Build order below is **reuse order**, not pack numbering. Task labels preserved.
> For every Apex class and LWC, write a 2–3 sentence "why this approach" header comment and log the decision in `decisions.md`. That file is the walkthrough cheat sheet.

---

## STEP 0 — Data Model (prerequisite for everything)

**Standard objects (already exist, no changes):**

- **Account** — `Name`
- **Contact** — `LastName`, `AccountId`, `Email`
- **Case** — `Subject`, `Status`, `Priority`, `ContactId`, `Type`, `Reason`, `CreatedDate`

**Custom object to create — `NTO_Order__c`:**
| Field | Type | Notes |
|---|---|---|
| `Order_Number__c` | Text(20) | **Mark as External ID** — bot looks orders up by this |
| `Total__c` | Currency(16,2) | — |
| `Status__c` | Picklist | Processing / Shipped / Delivered / Returned |
| `Contact__c` | Lookup(Contact) | parent for rollup-at-query-time |

**Architecture decision (defend this):** Lifetime value and open-case count are **computed in Apex at query time, NOT stored as fields**. No `Lifetime_Value__c`, no rollup, no trigger. Rationale: always accurate, nothing to keep in sync.

**Acceptance:** `NTO_Order__c` created with 4 fields; `Order_Number__c` is an External ID; permission set grants read on all four objects.

---

## STEP 1 — Seed Data (anonymous Apex via `sf apex run`)

Insert in dependency order, bulkified (one DML per object):

1. **25 Accounts** — `NTO Customer {i}`
2. **50 Contacts** — distributed across accounts, with Email
3. **80 Cases** — varied `Status` (New/Working/Escalated/Closed) and `Priority` (High/Medium/Low), tied to contacts
4. **30 `NTO_Order__c`** — `ORD-{1000+i}`, varied Total, Status, tied to contacts
5. **ONE hero contact, hand-built:** a named loyal customer with 4+ orders and **2+ open High-priority cases** so the risk badge fires on stage.

**Acceptance:** `SELECT COUNT() FROM Case` and `SELECT COUNT() FROM NTO_Order__c` return expected numbers; hero contact verified to trigger "At Risk".

---

## STEP 2 — Task 3: Customer 360 (BUILD THIS FIRST — it's the spine)

**Apex — `Customer360Controller`** (`with sharing`)

- `@AuraEnabled(cacheable=true) getCustomerSummary(Id contactId)`
- Returns a wrapper: Contact fields, lifetime value (`SUM(Total__c)` of orders for that contact), open case count, last 5 Cases, risk flag (`true` if 2+ open High-priority cases).
- Bulk-safe SOQL, no DML, no SOQL in loops.

**LWC — `customer360`**

- `@api recordId`
- `@wire(getRecord)` for Contact fields + `@wire(getCustomerSummary)` for the computed data
- Renders: header (name, lifetime value, risk badge), open-case count, last-5-cases list (`for:each` with `key`)
- Loading state + error state + empty state

**Acceptance:** Drop on a Contact record page; hero contact shows "At Risk" + 5 cases + lifetime value; a thin contact shows the empty state gracefully.

> NOTE: `Customer360Controller` is structurally identical to the live-challenge `CaseHistoryController`. Building it = drilling it.

---

## STEP 3 — Task 4: Agent Workspace (reuses Task 3 LWC)

- Lightning **Service Console app** "NTO Service Console"
- Case as primary workspace tab; Contact as related sub-tab
- Pin **`customer360` LWC** to the Case record page (the hero moment for the agent)
- Chat/utility item in the utility bar
- _(Optional polish, cut if short on time):_ 2 macros ("Send return label", "Escalate to T2"), a "Create Return" quick action on Case

**Acceptance:** Opening a Case shows the 360 component beside it; agent sees full customer context instantly with no clicking.

---

## STEP 4 — Task 2: Agentforce Service Bot (reuses NTO_Order\_\_c + Case)

- Agentforce agent, Atlas reasoning, grounding instructions reference NTO context
- **Intent 1 — Order Status:** Apex **invocable** action queries `NTO_Order__c` by `Order_Number__c`, returns status
- **Intent 2 — Return Request:** Flow that creates a `Case` (Type/Reason set)
- **Escalation topic:** routes to a Service queue / human when out of scope
- Test all 3 paths in the bot tester

**Acceptance:** Bot answers an order-status query, files a return as a Case, and escalates correctly.

---

## STEP 5 — Task 1: Experience Cloud Portal (reuses Task 3 LWC + Task 2 bot)

- LWR site, NTO branding (green / orange / cream), branded header
- Pages: **Home**, **My Orders**, **My Cases** (use a customer-facing trim of `customer360` on a profile page)
- **Context change:** resolve the **logged-in user's** contact — do NOT pass an arbitrary recordId
- Embedded Messaging (Web channel) pointed at the Agentforce agent; branded chat header
- Respect guest/community user sharing + FLS

**Acceptance:** A logged-in test customer sees only _their own_ orders/cases and can open the branded chat to the bot.

---

## STEP 6 — Plug-and-Play Hardening (the "another SE deploys it" requirement)

- SFDX project, **metadata-only**
- `scripts/setup.sh` (or `.ps1`): deploy metadata → assign perm set → run seed Apex → publish site
- `README.md` leading with the pack's "another SE deploys with zero code changes" line. Sections: Prerequisites / Install / What it does / Troubleshooting / Architecture diagram
- `decisions.md`: why `@wire` vs imperative, why `cacheable=true`, why `with sharing`, why Flow vs Apex action, why computed-not-stored

**Acceptance:** A clean org + one script run reproduces the whole demo.

---

## DECISIONS TO HAVE RANGED FOR THE WALKTHROUGH ("explain every line")

- Why `with sharing` on the controllers
- Why `cacheable=true` (and what it forbids — no DML)
- `@wire` vs imp­erative — where you used each and why
- Why lifetime value is computed, not stored
- How the same Apex service layer feeds LWC, portal, and Agentforce — build once, reuse everywhere
- Portal vs internal behavior: guest user sharing + FLS

## SEQUENCING NOTE FOR CLAUDE CLI

Build STEP 2 (Customer 360) fully before STEP 3–5, since 3, 4, and 5 all reuse the LWC. Keep each task in its own focused context; do not cross-contaminate.
