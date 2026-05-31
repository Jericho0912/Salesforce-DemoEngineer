# NTO Service Demo

A metadata-only Salesforce demo for Northern Trail Outfitters (NTO) service: **another SE can deploy the whole thing into a clean org with one script and zero code changes.** It showcases a single Apex service layer reused across a Lightning record page, a Service Console, an Agentforce bot, and an Experience Cloud portal.

---

## Prerequisites

- Salesforce CLI (`sf`) v2+ — `sf version`
- A Salesforce org authorized with the CLI. This build targets a Developer Edition org aliased `Demo-Org`:
  ```
  sf org login web --alias Demo-Org
  ```
- Node.js (only if you want to run the LWC Jest tests): `npm install`

---

## Install (one command)

```powershell
# Windows / PowerShell
.\scripts\setup.ps1 -OrgAlias Demo-Org
```

```bash
# macOS / Linux
./scripts/setup.sh Demo-Org
```

The script deploys all metadata, assigns the `NTO_Demo_Access` permission set, and loads seed data (25 accounts, 50 contacts, 80 cases, 30 orders, plus a hand-built **At Risk** hero customer — _Avery Stone_). The seed is idempotent: re-running it clears prior `NTO %` demo records first.

After it finishes, do the one-time manual steps below (Lightning page activation, Agentforce, Experience Cloud) — these involve org features that can't be fully scripted.

---

## What it does

| Task                        | Component                                                                   | Status                                        |
| --------------------------- | --------------------------------------------------------------------------- | --------------------------------------------- |
| **Customer 360**            | `Customer360Controller` + `customer360` LWC                                 | Fully deployed & tested                       |
| **Agent Workspace**         | `NTO Service Console` app + `Case Workspace 360` page + `customer360OnCase` | Fully deployed (activate page)                |
| **Agentforce bot**          | `OrderStatusAction` (invocable) + `NTO_Create_Return` (flow)                | Code deployed & tested; agent assembled in UI |
| **Experience Cloud portal** | `PortalCustomerController` + `customerPortalProfile` LWC                    | Code deployed & tested; site built in UI      |

**Hero moment:** open _Avery Stone_ (Contact) or any of her cases — the Customer 360 shows an **At Risk** badge (2+ open High-priority cases), a lifetime value of ~$4,798, and her recent cases, with no clicking.

### Activate the Lightning pages (one-time)

The record pages deploy but aren't auto-assigned:

- **Contact** → Setup → Object Manager → Contact → Lightning Record Pages → **Contact Customer 360** → _Activate_ (org default).
- **Case** → Object Manager → Case → Lightning Record Pages → **Case Workspace 360** → _Activate_ → set as the **NTO Service Console** app default.

---

## Agentforce Setup (manual, ~10 min)

The reusable code is already deployed; assemble the agent in the UI:

1. **Enable Agentforce**: Setup → _Einstein Setup_ / _Agentforce_ → turn on. (Developer Edition orgs may need Agentforce enabled first.)
2. **New Agent**: Setup → _Agentforce Studio_ → _Agents_ → **New** → Agentforce (Service) with **Atlas** reasoning. Grounding instructions: "You are NTO's customer service assistant. Help with order status and returns; escalate anything else to a human."
3. **Topic — Order Status**: add a topic, attach the action **Get NTO Order Status** (`OrderStatusAction`). It takes an order number (e.g. `ORD-1001`) and returns the status sentence.
4. **Topic — Return Request**: add a topic, attach the flow **NTO Create Return** (`NTO_Create_Return`). It creates a return Case (Type/Reason = _Other_, Origin = _Web_) and returns a confirmation message.
5. **Escalation**: add a topic that routes out-of-scope requests to a human/Service queue.
6. **Test** all three paths in the Agent preview, then activate.

---

## Experience Cloud Setup (manual, ~15 min)

The portal controller and component are deployed; build the site in the UI:

1. **Enable Digital Experiences**: Setup → _Digital Experiences_ → _Settings_ → Enable.
2. **New site**: _All Sites_ → **New** → _Build Your Own (LWR)_. Brand with NTO colors (green `#1a7a3c`, orange `#e8762d`, cream `#f7f3e8`) and a branded header.
3. **Add the component**: in Experience Builder, drop **My Account (Customer Portal)** (`customerPortalProfile`) onto a Home/profile page. It self-resolves the logged-in user's contact — no recordId.
4. **Sharing & FLS**: create a **Sharing Set** on `NTO_Order__c` so community users see orders where `Contact__c` = their contact; grant the community profile read on Account/Contact/Case/`NTO_Order__c` (mirror `NTO_Demo_Access`).
5. **Embedded chat**: add Embedded Messaging (Web) pointed at the Agentforce agent; brand the chat header.
6. Create a test community user linked to a seeded contact and verify they see **only their own** orders/cases.

---

## Troubleshooting

- **`cannot deploy to a required field`** — required picklists (e.g. `Status__c`) can't carry FLS in a permission set; they're implicitly visible.
- **Deploy rolls back entirely** — `sf` deploys are all-or-nothing; one failed component reverts the rest. Fix the failure and redeploy the set.
- **Customer 360 shows nothing** — confirm the Lightning page is _activated_, the contact has data, and `NTO_Demo_Access` is assigned.
- **Portal shows "not linked to a contact"** — the running user must be a community user whose `User.ContactId` is set.
- **Source tracking** — this Dev Edition org isn't source-tracked; always deploy by path (`sf project deploy start -d ...`).

---

## Architecture

```
                       ┌──────────────────────────────┐
                       │   Customer360Controller       │   with sharing
                       │   getCustomerSummary(contactId)│   cacheable=true
                       │   - lifetime value (SUM)       │   computed, never stored
                       │   - open cases / At Risk       │   aggregate SOQL, no DML
                       │   - last 5 cases               │
                       └──────────────┬─────────────────┘
                                      │ reused by
        ┌───────────────┬─────────────┼───────────────────┬───────────────────┐
        ▼               ▼             ▼                   ▼                   ▼
  customer360      customer360    PortalCustomer     OrderStatusAction   NTO_Create_Return
  (Contact page)   OnCase         Controller         (@InvocableMethod)  (Flow)
        │           (Case page)   + customerPortal        │                  │
        ▼               ▼          Profile (portal)        ▼                  ▼
  Record page    Service Console   Experience Cloud    Agentforce          Agentforce
                                                       Order Status        Return topic
```

**One read API, four channels.** See [`decisions.md`](./decisions.md) for the rationale behind every choice (`with sharing`, `cacheable=true`, `@wire` vs imperative, computed-not-stored, Flow vs Apex).

### Apex tests

```
sf apex run test -o Demo-Org -w 10 -r human \
  -t Customer360ControllerTest -t OrderStatusActionTest -t PortalCustomerControllerTest
```

All 11 pass; `Customer360Controller` is 100% covered. (Run targeted classes — a fresh org may carry unrelated pre-existing sample classes that fail `RunLocalTests`.) LWC: `npm test`.
