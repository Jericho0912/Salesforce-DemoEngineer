# NTO Task 2 — Agentforce Service Agent + CLT Showcase Playbook

> **Read order:** Part 1 is the graded deliverable. Build and verify it _fully_ before touching Part 2. Part 2 is bonus and fails silently — it must never sit between you and a working Task 2.
>
> **Labeling:** `[MINIMUM]` = required to satisfy the brief (Part 1). `[BONUS]` = art-of-the-possible (Part 2). `[PREP]` = panel talk-track (Part 3).

---

## 0. Verdicts before you build

### 0.1 Two-agent split — **agreed, but for a sharper reason than the one you gave**

Your stated rationale ("isolate the CLT chain so it can't jeopardize the core") is half-right. The runtime risk you're worried about is actually low: a misaligned CLT falls back to **plain text in that one response** — it does _not_ break sibling topics, crash the agent, or affect order-status / returns. So putting the CLT action inside the Task 2 agent wouldn't "take down" the deliverable.

The split is still **correct**, for two stronger reasons:

1. **Authoring-mode separation is structural, not stylistic.** Task 2 is authored in the Agent Builder UI (click-built `Bot` / `GenAiPlanner` / `GenAiPlugin` metadata). The CLT showcase needs the Agent Script properties `complex_data_type_name` + `is_displayable` + `source` on the action, which live in an `AiAuthoringBundle` (`.agent`). You don't cleanly co-author one agent across both modes — pick one per agent. Two agents = two clean authoring stories.
2. **Demo clarity.** The panel watches the core flow without a half-finished CLT renderer appearing mid-conversation. The bonus gets its own 60-second "and here's what's next" segment.

So: keep the split. Just don't _defend_ it in the room as "otherwise it breaks Task 2" — defend it as "different authoring surfaces, isolated demo narrative." That's the version that survives a follow-up question.

### 0.2 The optional 3rd FAQ topic — **conditional yes**

- **Add it only if you already have 2–3 NTO Knowledge articles seeded** (e.g. shipping policy, return window, sizing). Then it's a one-data-source + one-topic add and it gives you a _grounding + Einstein Trust Layer_ story for free — high value for a pre-sales panel.
- **If you have zero articles, skip it.** Authoring articles to make a third topic look full is scope creep against a graded build. Mention it as a roadmap item instead ("next I'd ground an FAQ topic on NTO Knowledge"). Config for it is in §1A.4 if you want it.

### 0.3 The one risk I want flagged up front (Part 2)

"Resolve the customer's contact via `UserInfo`" and "demonstrate in the Agent Builder preview" are in tension. The internal user running the builder preview has **no `ContactId`**, so a strict `UserInfo → User.ContactId` query returns zero rows → you'd see the styled _empty state_, not the card grid. The bundle handles this with a labeled demo fallback (resolve the seeded hero contact via `ORD-2001`). Details and the faithful-portal alternative in §2.4. This is a "know the seams" point, not a blocker.

---

# PART 1 — Task 2 Agent (Agent Builder UI) `[MINIMUM]`

## 1A — Design

### 1A.0 Agent type — confirmed

**Agentforce Service Agent**, authored in **Agent Builder UI**. Customer-facing, runs on the messaging surface, grounded in your service data. Not an internal Employee/Copilot agent.

### 1A.1 Topic — **Order Status**

| Facet                                                   | Content                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| ------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Classification description** _(how Atlas selects it)_ | "Use when the customer asks about the status, location, delivery progress, or tracking of an existing order, or references an order number (e.g. ORD-2001). Examples: _where is my order, has my order shipped, track ORD-2001, is my order delivered yet._"                                                                                                                                                                                                        |
| **Scope / instructions (NTO voice + guardrails)**       | Friendly, concise, trail-brand tone. **Require an order number**; if none is given, ask for it once. Call the action with the order number; **report only the status the action returns** — never guess, infer, or invent a status. If the action returns not-found, relay the friendly not-found message verbatim. **Never reveal another customer's order** — you only handle the customer's own orders. Do not promise delivery dates the action did not return. |
| **Action it calls**                                     | `OrderStatusAction` — `@InvocableMethod(label='Get NTO Order Status', category='NTO')`. Input: order number. Output: status string or friendly not-found. (Reused, already deployed.)                                                                                                                                                                                                                                                                               |

> **Isolation seam to know:** "own orders only" is enforced by **OWD External = Private + `with sharing`** in the live customer session, _not_ by the prompt. In the admin preview you'll see every order because the running admin has broad access — so demonstrate the isolation claim either by _explaining the sharing model_ or by previewing as a community user on the portal.

### 1A.2 Topic — **Returns & Exchanges**

| Facet                                             | Content                                                                                                                                                                                                                                                                                                                                                                           |
| ------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Classification description**                    | "Use when the customer wants to return, exchange, send back, or get a refund for an item or order, or asks how to start a return. Examples: _I want to return my boots, start a return for ORD-2002, how do I exchange this jacket._"                                                                                                                                             |
| **Scope / instructions (NTO voice + guardrails)** | Collect the **order number** and a **brief reason**. Confirm the details back to the customer before creating anything. Call the return flow. Relay the flow's `var_Message` and reference the created case. Only the customer's own orders. Do not quote refund timelines beyond NTO policy. If the customer is upset or asks for a person, hand to the escalation path (§1A.3). |
| **Action it calls**                               | `NTO_Create_Return` (AutoLaunched Flow). Inputs: `var_ContactId`, `var_OrderNumber`, `var_Reason` → Outputs: `var_CaseId`, `var_Message`. Creates a Case. (Reused, already built.)                                                                                                                                                                                                |

> **Contact-binding seam to know:** `var_ContactId` is populated from the **messaging session's customer context** (the logged-in Experience Cloud user's `ContactId`). In the **builder preview there is no customer**, so `var_ContactId` will be null — the flow still creates a Case (just unlinked) and returns `var_Message`, which is enough to demo. Say this out loud rather than letting the panel catch it.

### 1A.3 Escalation path

| Facet                         | Content                                                                                                                                                                                                                                                                                                                                                                          |
| ----------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Conditions**                | (a) Agent can't resolve — no matching topic, or repeated action failure; (b) customer explicitly asks for a human ("talk to a person / agent / representative"); (c) negative sentiment.                                                                                                                                                                                         |
| **Mechanism**                 | The Service Agent's built-in **transfer/escalate** behavior hands the conversation to **Omni-Channel**, which routes the **Messaging Session to a human queue**. The **full transcript is preserved** and attached to the routed work. The human picks it up in **`NTO_Service_Console`** via the Omni-Channel widget.                                                           |
| **Config (in Agent Builder)** | Turn on the escalate-to-human behavior and point it at your routing target (queue). This is agent-side config.                                                                                                                                                                                                                                                                   |
| **Omni setup (in Setup)**     | Enable Omni-Channel → create a **Queue** + **Routing Configuration** → create/confirm the **Messaging (Service) Channel** → route escalated messaging sessions to the queue (Omni-Channel Flow or routing config) → assign agents to the queue with an **Omni presence/status** → add the **Omni-Channel utility** + the Messaging Session record page to `NTO_Service_Console`. |

> Exact UI labels for the escalate behavior shift between releases — confirm the wording in your org, but the shape above (agent → Omni → queue → console, transcript preserved) is the defensible architecture.

### 1A.4 _(Optional)_ Topic — **General / FAQ (Knowledge-grounded)** `[BONUS-within-Part-1]`

Only if you have articles. Add **NTO Knowledge** as a grounding data source; create a **General Questions** topic with classification "company/product/policy questions not about a specific order or return"; instructions: answer **only** from grounded Knowledge, cite nothing it can't ground, defer to the order/returns topics for transactional asks. This is your Einstein Trust Layer + RAG talking point.

---

## 1B — Config vs code vs already-built

| Piece                                              | UI config |    Reuses existing asset    | New code | Notes                       |
| -------------------------------------------------- | :-------: | :-------------------------: | :------: | --------------------------- |
| Service Agent shell                                |    ✅     |              —              |    —     | Agent Builder               |
| Order Status topic (classification + instructions) |    ✅     |              —              |    —     | Click-built                 |
| Returns topic (classification + instructions)      |    ✅     |              —              |    —     | Click-built                 |
| Order-status action                                |     —     | ✅ `OrderStatusAction.cls`  |    —     | Already deployed, bulk-safe |
| Returns action                                     |     —     | ✅ `NTO_Create_Return` flow |    —     | Already built               |
| Escalation behavior                                |    ✅     |              —              |    —     | Agent-side toggle + target  |
| Omni routing (queue, routing config, presence)     |    ✅     |              —              |    —     | Setup config                |
| Messaging channel + Embedded Service               |    ✅     |              —              |    —     | Setup config (§1C)          |
| (Optional) FAQ topic + Knowledge grounding         |    ✅     |    ✅ Knowledge articles    |    —     | Only if articles exist      |

**Everything in Part 1 is config + reuse. Zero new code.** That is the right answer for a 5-day redeployable demo and a strong thing to say in the room.

---

## 1C — Channel, portal surfacing, and the critical fallback

### 1C.1 Prerequisites (enable BEFORE the dependent steps)

- [ ] **Agentforce + Einstein enabled** (Setup → Einstein / Agentforce). _(Pre-enabled on Agentforce Dev Edition — confirm.)_
- [ ] **Omni-Channel enabled** (needed for escalation).
- [ ] **Messaging enabled**, and a **Messaging for In-App and Web** channel created.
- [ ] **Experience site published** on its domain (already built in Task 1).

### 1C.2 Surface the agent on the Experience site

1. [ ] Create the **Messaging for Web** channel and connect the **Service Agent** as its handler/routing target.
2. [ ] Create an **Embedded Service Deployment** (type: Messaging for Web); set branding (NTO colors, logo, header).
3. [ ] Add the **Experience site domain** to **CORS allowlist** and **Trusted URLs/Trusted Sites / CSP** on the LWR site (LWR enforces CSP — the embedded snippet's origins must be allowlisted or the widget silently won't load).
4. [ ] Publish the deployment; copy its **code snippet**.
5. [ ] Add the snippet to the LWR site (site `<head>` via Experience Builder settings, or the **Embedded Messaging** component on a page), then publish the site.
6. [ ] Activate and test from the live site domain.

### 1C.3 ⚠️ CRITICAL FALLBACK — demo Task 2 with **zero embedding**

If embedding runs out of time, you can still fully demonstrate the graded deliverable from the **Agent Builder → Conversation Preview** pane:

- [ ] Open the agent → **Conversation Preview**.
- [ ] Run the three scripts in §1D live.
- [ ] For each turn, narrate what the panel is seeing: **topic classification → action invocation → grounded response.**
- [ ] For escalation, the preview shows the agent **deciding to escalate and emitting the hand-off message**. Be explicit about the boundary: _the routing decision and transcript hand-off are demoable here; live Omni routing into the console requires the live channel + an agent on presence._

**Order-status is your cleanest preview demo** (queries by order number directly, no contact context needed). Returns has the `var_ContactId` seam (§1A.2). Escalation shows the decision, not the live routing. Knowing exactly which parts are preview-faithful vs live-only is itself the Demo-Engineer skill being graded.

---

## 1D — Test script

| #   | Input (type into preview / chat)                           | Correct behavior                                                                                                                                                                                                     |
| --- | ---------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | `What's the status of ORD-2001?`                           | Classifies **Order Status** → calls `OrderStatusAction` with `ORD-2001` → returns the actual status in NTO voice (e.g. "Your order ORD-2001 is **Shipped** 🚚"). No invented detail.                                 |
| 1b  | `Where is order ORD-9999?`                                 | Same topic → action returns **friendly not-found** → agent relays it without fabricating a status.                                                                                                                   |
| 2   | `I want to return my boots from ORD-2001, they don't fit.` | Classifies **Returns** → collects/confirms order number + reason → calls `NTO_Create_Return` → relays `var_Message` + references the created Case. _(Preview: case may be unlinked — see §1A.2.)_                    |
| 3   | `This is ridiculous, I want to speak to a person.`         | Detects escalation intent (explicit human request + negative sentiment) → **escalation hand-off message** → (live) routes the Messaging Session to the Omni queue in `NTO_Service_Console` with transcript attached. |

---

## ✅ GATE — STOP HERE

Verify scripts 1, 1b, 2, 3 behave correctly in the preview. **Do not start Part 2 until this passes.** If you ship only Part 1, you have satisfied the brief.

---

# PART 2 — CLT Showcase Agent (Agent Script) `[BONUS]`

> Build only after the GATE passes. This whole chain falls back to plain text **with no error** on any single misalignment — the alignment table in §2.3 is the contract. The deployable source is in `nto-clt-showcase.zip`; every file is also reproduced inline in §2.5 so you can explain each piece.

## 2.1 Scenario (why this is the _right_ CLT demo)

User asks _"show me my orders that are in transit"_ → agent classifies → calls a **deterministic Apex query** of `NTO_Order__c` filtered by `Status__c` → returns a **CLT output** rendering each matching order as a branded card (number, status pill, total, date). Real data (34 records, varied statuses) → provably correct, nothing hand-waved. A list of records as styled cards is the textbook "why not just text?" justification: structured records read far better as cards than as a prose list.

**Ground rules honored:** output renderer **only** (no input editor); the only action is a **query**, not reasoning; buttons are decorative/narrated, never wired; contact resolved server-side for isolation; structure **cloned** from the official recipe.

## 2.2 Prerequisites

- [ ] Part 1 GATE passed.
- [ ] Org supports `AiAuthoringBundle`, `GenAiFunction`, and Lightning Type Bundle metadata at **API 66.0** (Agentforce Dev Edition does).
- [ ] `sf` CLI authenticated to the org as default (you already work this way).

## 2.3 THE ALIGNMENT TABLE — filled with the actual names used

**Check these first if cards render as text.** Every row is a hard equality.

| What                          | Where (file)                                                       | Value — must match across the row                                                           |
| ----------------------------- | ------------------------------------------------------------------ | ------------------------------------------------------------------------------------------- |
| **Type name**                 | `.agent` `complex_data_type_name` ↔ Lightning type folder          | `c__ntoOrderList` ↔ `lightningTypes/ntoOrderList/`                                          |
| **Source name**               | `.agent` `source` ↔ `GenAiFunction` `developerName`                | `Get_NTO_Orders_By_Status`                                                                  |
| **Apex class**                | `lightningTypes/ntoOrderList/schema.json` ↔ inner class in service | `@apexClassType/c__NTOOrderCardService$OrderCardList` ↔ `NTOOrderCardService.OrderCardList` |
| **LWC name**                  | `lightningDesktopGenAi/renderer.json` ↔ LWC bundle                 | `c/ntoOrderListRenderer` ↔ `lwc/ntoOrderListRenderer`                                       |
| **LWC target**                | LWC meta `sourceType` ↔ Lightning type name                        | `c__ntoOrderList`                                                                           |
| **Wrapper fields**            | Apex request/response fields ↔ action parameter names              | `status_filter` (input) · `orders_result` (output)                                          |
| _(plus)_ **invocationTarget** | `GenAiFunction` ↔ `.agent` `target` ↔ Apex class                   | `NTOOrderCardService` ↔ `apex://NTOOrderCardService`                                        |

> Output is `lightning__AgentforceOutput` with **`sourceType`** (not `targetType` — that's the input side, which you are not building). The displayable output is the **`OrderCardList` object** carrying a `List<OrderCard>`; the renderer iterates `value.orders`. Status→pill mapping lives in the **LWC getter** (presentation), not Apex.

## 2.4 Contact resolution & where to demo it

- **Production isolation (what you defend):** `NTOOrderCardService.resolveContactId()` returns the **running community user's `User.ContactId`**, and the query runs `with sharing` + `WITH USER_MODE`. Identical isolation to the portal.
- **Internal-preview fallback (labeled, redeployable):** if the running user has no `ContactId` (the builder-preview case), it resolves the **seeded hero contact via `ORD-2001`** — deterministic, no hardcoded Id, safe to keep (only fires for non-community users) or strip for prod.
- **Why the showcase is an _employee_ agent:** so the cards render in the **Agent Builder preview** with no community login. The fallback yields Avery's contact → her `Shipped` order (ORD-2002) → **cards render in preview**. The identical chain drops into the **customer Service Agent on the portal**; only the contact-resolution surface differs. That's the honest, panel-friendly framing.
- **Faithful alternative (more effort):** make it an `AgentforceServiceAgent` and surface it through the portal's Embedded Messaging logged in as Avery — real `UserInfo→Contact` isolation, real surface. Higher risk for a bonus; do this only if Part 1 + embedding are already solid.
- **Empty-state insight:** even with zero rows, an **aligned** chain renders the styled _"No matching orders"_ card. So an empty render still proves the CLT works; **plain text** is the only signal of misalignment.

## 2.5 Wire + deploy

### Recommended wiring approach

The Salesforce blog is explicit: the **Agentforce Builder UI enforces the naming constraints automatically and is the recommended starting point.** Given the silent-failure mode, do this:

1. Deploy the Apex + LWC + Lightning Type Bundle + `GenAiFunction` from source (deterministic, version-controlled).
2. Register/confirm the action and its **Input/Output Rendering → Custom Lightning Type** in **Setup → Agentforce Assets → Actions** (the UI validates the bindings the table above lists).
3. Author/confirm the small showcase agent. You can deploy the `.agent` as-is _or_ mirror it in the Builder UI as a safety net for the alignment.

### Deploy commands (API 66.0; org already default)

```bash
sf project deploy start -d force-app/main/default/classes
sf project deploy start -d force-app/main/default/lwc/ntoOrderListRenderer
sf project deploy start -d force-app/main/default/lightningTypes
sf project deploy start -d force-app/main/default/genAiFunctions
sf project deploy start -d force-app/main/default/aiAuthoringBundles
# or all at once:
sf project deploy start -d force-app/main/default
```

### The files (full source — also in the zip)

**`classes/NTOOrderCardService.cls`** — Apex service. Inner `OrderCard`/`OrderCardList` are the CLT shapes; `status_filter`/`orders_result` are the alignment-bound wrapper fields. `with sharing` + `WITH USER_MODE`; contact resolved server-side.

```apex
public with sharing class NTOOrderCardService {
  public class OrderCard {
    @InvocableVariable
    public String orderNumber;
    @InvocableVariable
    public String status;
    @InvocableVariable
    public String total; // pre-formatted currency string
    @InvocableVariable
    public String orderDate; // pre-formatted date string
  }
  public class OrderCardList {
    @InvocableVariable
    public List<OrderCard> orders;
  }
  public class OrderQueryRequest {
    @InvocableVariable(required=true)
    public String status_filter;
  }
  public class OrderQueryResponse {
    @InvocableVariable
    public OrderCardList orders_result;
  }

  private static final Set<String> ALLOWED_STATUSES = new Set<String>{
    'Processing',
    'Shipped',
    'Delivered',
    'Returned'
  };

  @InvocableMethod(
    label='Get NTO Orders By Status'
    description='Returns the running customer\'s NTO orders filtered by status, as CLT order cards'
    category='NTO'
  )
  public static List<OrderQueryResponse> getOrdersByStatus(
    List<OrderQueryRequest> requests
  ) {
    List<OrderQueryResponse> responses = new List<OrderQueryResponse>();
    Id contactId = resolveContactId();
    for (OrderQueryRequest req : requests) {
      OrderQueryResponse res = new OrderQueryResponse();
      OrderCardList container = new OrderCardList();
      container.orders = new List<OrderCard>();
      String normalized = normalizeStatus(req.status_filter);
      if (contactId != null && normalized != null) {
        for (NTO_Order__c o : [
          SELECT Order_Number__c, Status__c, Total__c, CreatedDate
          FROM NTO_Order__c
          WHERE Contact__c = :contactId AND Status__c = :normalized
          WITH USER_MODE
          ORDER BY CreatedDate DESC
        ]) {
          OrderCard card = new OrderCard();
          card.orderNumber = o.Order_Number__c;
          card.status = o.Status__c;
          card.total = (o.Total__c == null) ? '' : formatCurrency(o.Total__c);
          card.orderDate = (o.CreatedDate == null)
            ? ''
            : o.CreatedDate.format('MMM d, yyyy');
          container.orders.add(card);
        }
      }
      res.orders_result = container;
      responses.add(res);
    }
    return responses;
  }

  private static Id resolveContactId() {
    Id ctc = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()]
    .ContactId;
    if (ctc != null)
      return ctc;
    // Demo fallback for internal preview (no community ContactId) — redeployable, no hardcoded Id.
    List<NTO_Order__c> seed = [
      SELECT Contact__c
      FROM NTO_Order__c
      WHERE Order_Number__c = 'ORD-2001'
      LIMIT 1
    ];
    return seed.isEmpty() ? null : seed[0].Contact__c;
  }

  private static String normalizeStatus(String raw) {
    if (String.isBlank(raw))
      return null;
    String trimmed = raw.trim();
    for (String s : ALLOWED_STATUSES) {
      if (s.equalsIgnoreCase(trimmed))
        return s;
    }
    return null; // unknown -> empty result -> renderer shows empty state
  }

  private static String formatCurrency(Decimal amount) {
    return '$' + amount.setScale(2).format();
  }
}
```

**`lwc/ntoOrderListRenderer/ntoOrderListRenderer.js`** — receives the CLT object via `@api value`; pill mapping in a getter; empty case handled.

```js
import { LightningElement, api } from "lwc";

const PILL_BY_STATUS = {
  Processing: "slds-theme_warning",
  Shipped: "slds-theme_info",
  Delivered: "slds-theme_success",
  Returned: "slds-theme_error"
};

export default class NtoOrderListRenderer extends LightningElement {
  @api value;
  get orders() {
    const list = this.value?.orders ?? [];
    return list.map((order) => ({
      ...order,
      pillClass: PILL_BY_STATUS[order.status] ?? "slds-badge"
    }));
  }
  get hasOrders() {
    return this.orders.length > 0;
  }
  get emptyMessage() {
    return "No matching orders right now.";
  }
}
```

**`lwc/ntoOrderListRenderer/ntoOrderListRenderer.html`**

```html
<template>
  <lightning-card title="Your NTO Orders" icon-name="standard:orders">
    <div class="slds-var-p-horizontal_medium slds-var-p-bottom_medium">
      <template lwc:if="{hasOrders}">
        <div class="slds-grid slds-wrap slds-gutters_small">
          <template for:each="{orders}" for:item="order">
            <div
              key="{order.orderNumber}"
              class="slds-col slds-size_1-of-1 slds-medium-size_1-of-2 slds-var-m-bottom_small"
            >
              <div class="slds-box slds-box_x-small nto-card">
                <div
                  class="slds-grid slds-grid_align-spread slds-grid_vertical-align-center slds-var-m-bottom_x-small"
                >
                  <span class="slds-text-heading_small"
                    >{order.orderNumber}</span
                  >
                  <lightning-badge
                    label="{order.status}"
                    class="{order.pillClass}"
                  ></lightning-badge>
                </div>
                <p class="slds-text-body_small slds-text-color_weak">
                  {order.orderDate}
                </p>
                <p class="slds-text-heading_medium slds-var-m-top_x-small">
                  {order.total}
                </p>
              </div>
            </div>
          </template>
        </div>
      </template>
      <template lwc:else>
        <div class="slds-box slds-theme_shade slds-text-align_center">
          <p>{emptyMessage}</p>
        </div>
      </template>
    </div>
  </lightning-card>
</template>
```

**`lwc/ntoOrderListRenderer/ntoOrderListRenderer.js-meta.xml`** — target `lightning__AgentforceOutput`, `sourceType` = the CLT name.

```xml
<?xml version="1.0" encoding="UTF-8" ?>
<LightningComponentBundle xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>66.0</apiVersion>
    <isExposed>true</isExposed>
    <masterLabel>NTO Order List Renderer</masterLabel>
    <targets><target>lightning__AgentforceOutput</target></targets>
    <targetConfigs>
        <targetConfig targets="lightning__AgentforceOutput">
            <sourceType name="c__ntoOrderList" />
        </targetConfig>
    </targetConfigs>
</LightningComponentBundle>
```

_(plus `ntoOrderListRenderer.css` — a 4px NTO-green left border on `.nto-card`.)_

**`lightningTypes/ntoOrderList/schema.json`** — points to the Apex inner class via `@apexClassType/...$Inner`.

```json
{
  "title": "NTO Order List",
  "description": "A customer's NTO orders filtered by status, for rich card display",
  "lightning:type": "@apexClassType/c__NTOOrderCardService$OrderCardList"
}
```

**`lightningTypes/ntoOrderList/lightningDesktopGenAi/renderer.json`** — `"$"` overrides the UI for the whole type.

```json
{
  "renderer": {
    "componentOverrides": { "$": { "definition": "c/ntoOrderListRenderer" } }
  }
}
```

**`genAiFunctions/Get_NTO_Orders_By_Status/Get_NTO_Orders_By_Status.genAiFunction-meta.xml`**

```xml
<?xml version="1.0" encoding="UTF-8" ?>
<GenAiFunction xmlns="http://soap.sforce.com/2006/04/metadata">
    <description
  >Returns the customer's NTO orders filtered by status as rich order cards</description>
    <developerName>Get_NTO_Orders_By_Status</developerName>
    <invocationTarget>NTOOrderCardService</invocationTarget>
    <invocationTargetType>apex</invocationTargetType>
    <isConfirmationRequired>false</isConfirmationRequired>
    <isIncludeInProgressIndicator>true</isIncludeInProgressIndicator>
    <localDeveloperName>Get_NTO_Orders_By_Status</localDeveloperName>
    <masterLabel>Get NTO Orders By Status</masterLabel>
    <progressIndicatorMessage
  >Pulling up your orders...</progressIndicatorMessage>
</GenAiFunction>
```

**`genAiFunctions/Get_NTO_Orders_By_Status/input/schema.json`** — `status_filter` is planner-extracted text, **not** user input (no editor).

```json
{
  "required": ["status_filter"],
  "unevaluatedProperties": false,
  "properties": {
    "status_filter": {
      "title": "status_filter",
      "description": "The order status to filter by. One of: Processing, Shipped, Delivered, Returned.",
      "lightning:type": "lightning__textType",
      "lightning:isPII": false,
      "copilotAction:isUserInput": false,
      "copilotAction:isUsedByPlanner": true
    }
  },
  "lightning:type": "lightning__objectType"
}
```

**`genAiFunctions/Get_NTO_Orders_By_Status/output/schema.json`** — `orders_result` is displayable, typed to the CLT.

```json
{
  "unevaluatedProperties": false,
  "properties": {
    "orders_result": {
      "title": "orders_result",
      "description": "The matching orders rendered as rich cards",
      "lightning:type": "c__ntoOrderList",
      "lightning:isPII": false,
      "copilotAction:isDisplayable": true,
      "copilotAction:isUsedByPlanner": true,
      "copilotAction:useHydratedPrompt": false
    }
  },
  "lightning:type": "lightning__objectType"
}
```

**`aiAuthoringBundles/NTOOrderCards/NTOOrderCards.agent`** — the action's `complex_data_type_name`, `is_displayable`, `source`, and `target` are the four Agent-Script-side linchpins.

```text
config:
   developer_name: "NTOOrderCards"
   agent_label: "NTO Order Cards"
   agent_type: "AgentforceEmployeeAgent"
   description: "Shows a customer's NTO orders filtered by status as rich Custom Lightning Type cards"

system:
   messages:
      welcome: "Hi! Ask me to show your orders by status - e.g. 'show my orders in transit'."
      error: "Something went wrong pulling up your orders. Please try again."
   instructions: "You help NTO customers view their own orders, filtered by status, displayed as rich cards."

start_agent order_router:
   description: "Route order-by-status requests"
   reasoning:
      instructions: |
         Select the tool that best matches the user's message and conversation history. If it is unclear, make your best guess.
      actions:
         show_orders: @utils.transition to @subagent.order_cards
            description: "Route any request to view the customer's orders by status (in transit, delivered, returned, processing)."

subagent order_cards:
   description: "Resolves the requested status and displays the customer's matching orders as cards"
   reasoning:
      instructions: |
         Map the customer's wording to exactly one status value: "in transit", "on the way", "shipped" -> "Shipped"; "delivered", "arrived", "received" -> "Delivered"; "returned", "sent back" -> "Returned"; "processing", "being prepared", "not shipped yet" -> "Processing". Call {!@actions.getOrdersByStatus} with status_filter set to that single value, then display the orders_result cards. Do NOT restate the orders in text and do NOT output any extra text.
      actions:
         getOrdersByStatus: @actions.getOrdersByStatus
            with status_filter = ...
   actions:
      getOrdersByStatus:
         description: "Returns the customer's NTO orders filtered by status"
         inputs:
            status_filter: string
               description: "The order status to filter by: Processing, Shipped, Delivered, or Returned"
               label: "status_filter"
               is_required: True
               is_user_input: False
         outputs:
            orders_result: object
               description: "The matching orders for display as cards"
               label: "orders_result"
               complex_data_type_name: "c__ntoOrderList"
               filter_from_agent: False
               is_displayable: True
         target: "apex://NTOOrderCardService"
         label: "Get NTO Orders By Status"
         require_user_confirmation: False
         include_in_progress_indicator: True
         progress_indicator_message: "Pulling up your orders..."
         source: "Get_NTO_Orders_By_Status"
```

_(plus `NTOOrderCards.bundle-meta.xml` — `bundleType=AGENT`, `versionTag=v0.1`.)_

> **Grammar caveat (be honest in the room):** the `.agent` reasoning-block syntax (`with status_filter = ...`, `@utils.transition`) is modeled directly on the official recipe. Agent Script's DSL is new; if the `.agent` deploy errors on grammar, author the action wiring in the **Agentforce Builder UI** (per the blog's recommendation) — the CLT chain is identical either way. Cloning the recipe ≠ guaranteeing the grammar; the alignment _values_ are what I've verified.

## 2.6 Acceptance & debug

- [ ] Preview the **NTOOrderCards** agent → `show me my in-transit orders` → **card grid renders** (Avery's `Shipped` orders via the fallback). Try `show my delivered orders`, `which orders were returned`.
- [ ] **Renders as plain text?** The chain is misaligned. Walk §2.3 top to bottom — 90% of the time it's `complex_data_type_name` ≠ folder name, `source` ≠ `developerName`, or `sourceType` ≠ type name.
- [ ] **Cards but empty?** Alignment is fine; the query returned nothing — confirm the fallback contact has orders in that status, or you're filtering a status with no rows.
- [ ] **Doesn't render in the builder preview at all?** Try the agent on a Lightning page / the LEX agent panel (a CLT-supported surface). Still nothing → **stop and narrate the feature with this design + the alignment table.** The cards are a bonus; don't burn unlimited time.

---

# PART 3 — Under the hood `[PREP]`

> Tight, accurate talk-track. Map every claim back to an NTO flow you actually built.

## 3.1 Atlas Reasoning Engine — the loop

1. **Trigger** — the customer's message enters the agent session.
2. **Topic classification** — Atlas matches the utterance to one **topic** using your **classification descriptions** (this is exactly why those descriptions matter). → _NTO: "where's ORD-2001" → Order Status._
3. **Grounding / RAG** — relevant context is retrieved and injected: instructions, action schemas, and (if configured) Knowledge/Data Cloud grounding. → _NTO: the optional FAQ topic grounds on NTO Knowledge._
4. **Reason–Act–Observe loop** — within the topic, Atlas **plans** which action(s) to call, **acts** (invokes the Apex/Flow), **observes** the structured result, and decides whether it has enough to answer or must act again. → _NTO: calls `OrderStatusAction`, observes the status, decides it's done._
5. **Response generation** — composes the final grounded reply (or, with a CLT, **renders the structured output**). → _NTO: the friendly status line; in the showcase, the order cards._

## 3.2 The two-LLM-role nuance

Atlas separates **planning/reasoning** from **response generation**:

- a **reasoning role** classifies the topic and selects actions (the "what should I do");
- a **response role** turns grounded results into the customer-facing answer (the "how do I say it").
  This is why a well-scoped action with a clean schema matters more than prompt cleverness — the planner reasons over **structured action contracts**, not prose. Exact model routing is Salesforce-managed; don't overclaim specific model names in the room.

## 3.3 Einstein Trust Layer

Wraps every LLM call:

- **PII detection & masking** before data leaves to the model;
- **zero data retention** — prompts/responses aren't retained by the model provider;
- **prompt-injection & toxicity defense** plus grounding guardrails;
- **audit trail & feedback** for monitoring and improvement.
  → _NTO: the returns flow handles a customer's order + reason; the Trust Layer is your answer to a CISO-type "where does our customer data go" objection._

## 3.4 The CLT angle — beyond text, beyond Salesforce

- **Custom Lightning Types** override the default text UI with your **LWCs** for input and/or output inside the agent conversation (Lightning Experience, Enhanced Chat v2, Experience Builder). → _NTO: order cards instead of a prose list._
- **Headless Experience Layer (TDX 2026)** is built on the same CLT primitives and extends rich agentic UI **beyond Salesforce** — Slack, ChatGPT, and more. The pitch line: **"Define once, deploy anywhere, secure everywhere."** → _NTO: the same `ntoOrderList` card chain you built could surface a customer's orders inside Slack or a partner channel without re-authoring the agent — you're already working with the primitives that power it._

---

## Appendix — source control vs click-only (redeployability)

| Asset                                                                                       | Source-controllable?              | How                                                                                                                                               |
| ------------------------------------------------------------------------------------------- | --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `OrderStatusAction`, `Customer360Controller`, `ProductController`, `NTO_Create_Return` flow | ✅ already                        | In your repo; `sf project deploy`                                                                                                                 |
| Part 2 CLT chain (Apex, LWC, Lightning Type Bundle, `GenAiFunction`, Agent Script)          | ✅ fully source-first             | The zip; `sf project deploy start -d force-app/main/default`                                                                                      |
| Task 2 Service Agent definition (`Bot`/`GenAiPlanner`/`GenAiPlugin`/`GenAiFunction`)        | ⚠️ retrievable, not hand-editable | Build in UI, then `sf project retrieve start -m "Bot,GenAiPlanner,GenAiPlugin,GenAiFunction"` to version it; **don't hand-edit the raw metadata** |
| Embedded Service deployment, Messaging channel, Omni routing                                | ⚠️ partly metadata                | Mostly set up in UI; some types retrievable — treat as click-built config                                                                         |
| Knowledge articles, sample `NTO_Order__c` data                                              | ⚠️ data, not metadata             | Ship a re-runnable Apex/Anonymous or data-import seed with the package                                                                            |

**No hardcoded Ids anywhere.** Contact is resolved at runtime; the demo fallback resolves by the `ORD-2001` business key, which your seed guarantees exists. The package redeploys to any SE's org.
