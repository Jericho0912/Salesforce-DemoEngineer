# NTO Customer Portal — Architecture, Build Plan & Walkthrough

### Demo Engineer take-home · Northern Trail Outfitters · Agentforce Developer Edition

This doc does two jobs. First, it's the **build plan** for the Experience Site (Task 1) situated inside the full solution so the pieces connect. Second, it's the **walkthrough script** for the room — what you built, what was config vs hand-coded vs AI-assisted, and how Agentforce works under the hood. The slide says _"be ready to explain every line of code."_ Treat that as the grading rubric: a working demo earns a pass, but explaining _why_ each security annotation, wire, and guardrail exists is what gets you the offer.

---

## 0. The one-paragraph narrative (lead with this)

> An NTO customer lands on a branded self-service portal, checks their orders and cases, and opens chat. An Agentforce service agent answers routine questions by grounding on NTO's own knowledge and order data — **deflecting** the ticket entirely. When it can't resolve the issue, or the customer asks for a person, it **escalates** the live conversation to a human via Omni-Channel, with full context preserved. That agent works the case in a Service Console where a single Customer 360 component and the live chat sit side by side. Every layer reads and writes the same governed records, and every AI model call passes through the Einstein Trust Layer. It's redeployable by any SE because it's ~70% configuration and a handful of small, security-conscious, well-documented LWCs and Apex actions.

That paragraph hits all four tasks plus the "art of the possible" and "redeployable" framing on the slide. Memorize the shape of it.

---

## 1. Solution architecture

Four layers over one shared data core:

| Layer                | Who uses it              | Tech                                    | Task |
| -------------------- | ------------------------ | --------------------------------------- | ---- |
| Experience portal    | NTO customers            | Experience Cloud (LWR) + custom LWCs    | 1    |
| AI service agent     | Customers (in chat)      | Agentforce Service Agent + Atlas + MIAW | 2    |
| Single customer view | Agents **and** customers | One `@api`-configurable LWC + Apex      | 3    |
| Service console      | NTO agents               | Lightning Console app + Omni-Channel    | 4    |
| **Data core**        | everything               | Standard + minimal custom objects       | —    |

The architectural through-line worth saying out loud: **the Customer 360 LWC is one component deployed in two places** (console for the agent, portal for the customer), differing only by `@api` properties. That's the elegant bit and it directly satisfies Task 3's "@api configurable" requirement.

---

## 2. Data model (the single source of truth)

Keep it standard where you can — it signals platform fluency and it's what an SE would actually ship.

- **Account** — Business Accounts with **Contacts** as the community users. (Person Accounts are also valid for pure B2C; mention the trade-off: Person Accounts simplify the 1:1 customer model but complicate some sharing and reporting. Pick Business Account + Contact for the demo so sharing sets map cleanly.)
- **Order** + **OrderItem** + **Product2** + **Pricebook2** / **PricebookEntry** — standard order management. Gives the agent real records to read for "where's my order."
- **Case** + Case Feed / Case Comments — standard service object, shared between portal and console.
- **Lightning Knowledge** — articles for **deflection**: return policy, shipping windows, sizing/warranty FAQ. This is what the agent grounds on (RAG).
- **One NTO-flavored custom object** to make it feel like NTO, not a generic demo — e.g. `Gear_Registration__c` (outdoor gear with warranty + serial). Small, but it's the difference between "Northern Trail Outfitters" and "Acme Corp."

**Sharing model** (a question they _will_ ask): Org-Wide Defaults private; grant each customer access to only their own records via **Sharing Sets** (access where the record's `Contact`/`Account` matches the running user's contact/account). For Cases the standard `ContactId` is the key; for Orders, ensure an Account/Contact linkage exists to drive the sharing set. Use a **Customer Community Plus** license if you want sharing-rule flexibility; **Customer Community** is cheaper and sharing-set-based.

---

## 3. Task 1 — NTO Customer Portal (the Experience Site)

This is your primary build. Here it is end to end.

### 3.1 Template & foundation — and why

Use **Build Your Own (LWR)**, not the Aura-based Customer Service / Help Center template.

- **Why LWR:** it runs on Lightning Web Components + the Lightning Web Runtime — faster page loads, materially better Lighthouse/Core Web Vitals, full control over branding and custom components, and it's where Salesforce is investing. Aura templates are legacy.
- **The honest trade-off** (say this — it shows judgment): LWR ships fewer drag-and-drop standard components than Aura, so you hand-build more LWCs. For _this_ exercise that's a feature, not a bug — it gives you authored code to explain.

Enable, in order: **Digital Experiences** (Setup → Digital Experiences → Settings), set a domain → **New site → Build Your Own (LWR)** → name "NTO Customer Portal," set URL → configure **membership** (which profiles/permission sets can access).

### 3.2 Identity, access & sharing

- **Guest user** for the public Home page; **authenticated** users for My Orders / My Cases.
- Customers are **Contacts** enabled as Experience users.
- Sharing via **Sharing Sets** so each customer sees only their own Orders/Cases (see §2). OWD private underneath. This is the single most important thing to get right and to be able to explain — a portal that leaks one customer's data to another is an instant fail.

### 3.3 Branding for NTO ("feel like NTO, not a generic Salesforce demo")

- **Theme** (Experience Builder → Theme): brand colors (outdoorsy — deep greens, earth tones, a warm accent), typography (a brand-ish font over default Salesforce Sans), logo + favicon.
- **Custom CSS** via the Theme's CSS editor for the bits the theme panel can't reach (hero treatment, button radius, card shadows).
- A **branded hero** on Home with NTO imagery and copy, plus clear CTAs ("Track an order," "Get help").
- This is mostly **configuration** with a thin **hand-coded CSS** layer.

### 3.4 Pages & components

**Home (public)** — hero, value props, featured gear, search, "Get help" launching the chat. Mostly standard components + theme; minimal custom code.

**My Orders (authenticated)** — custom LWC `ntoMyOrders`:

- `@wire`s an Apex method `getMyOrders` (cacheable) that resolves the running user → their Contact → their Orders.
- Renders `lightning-datatable` or custom cards; row click navigates to the order detail (record page or a detail LWC).

**My Cases (authenticated)** — custom LWC `ntoMyCases`:

- Lists the user's Cases (same wire pattern).
- A **"Log a case"** button launches a **Screen Flow** (`NTO_Create_Case`) embedded in the site. Use a Flow rather than a hand-rolled form — it's declarative, defensible, and the kind of thing an SE shows off ("no code for the intake form").

**Embedded chat** — the Agentforce widget (built in Task 2), added either by dragging the **Embedded Messaging** component onto the page in Experience Builder or via the deployment **code snippet** in the site's Head Markup.

**Customer 360 (self-view)** — the same Task 3 LWC in `mode="customer"` (hides the risk badge, shows the customer their own order/case summary). Optional for Task 1, but it's a clean way to demonstrate the reuse story on the portal too.

### 3.5 Mobile experience

- LWR sites are **responsive by default**; verify in Experience Builder's **device preview** (mobile / tablet breakpoints).
- Custom LWCs use the SLDS responsive grid (`lightning-layout` with `size` / `small-device-size` attributes) and flexbox so cards reflow on narrow screens.
- **Art-of-the-possible upsell** (scope it as future, don't build it): **Mobile Publisher** turns the same Experience site into branded native iOS/Android apps — same code, app-store presence. Mentioning it shows you know the roadmap without burning a day on it.

### 3.6 Task 1 — what was config / hand-coded / AI-assisted

| Element                       | Configuration          | Hand-coded                                         | AI-assisted                      |
| ----------------------------- | ---------------------- | -------------------------------------------------- | -------------------------------- |
| Site, template, membership    | ✔ all clicks           | —                                                  | —                                |
| Branding (theme, logo, fonts) | ✔                      | thin custom CSS                                    | CSS variations                   |
| Home page                     | ✔ standard components  | —                                                  | layout/copy drafting             |
| My Orders / My Cases          | page placement         | `ntoMyOrders`/`ntoMyCases` LWCs + Apex controllers | LWC scaffold, SOQL, test classes |
| Create-case form              | ✔ Screen Flow          | —                                                  | —                                |
| Sharing model                 | ✔ sharing sets, OWD    | —                                                  | —                                |
| Embedded chat                 | ✔ deployment + drop-in | —                                                  | —                                |

---

## 4. Task 2 — Agentforce Service Bot (deflection + escalation)

### 4.1 Agent design

Build an **Agentforce Service Agent** (the customer-facing service agent that runs on Messaging channels — the modern replacement for Einstein Bots).

**Topics** (each is a scoped set of instructions + allowed actions — they're also your guardrails):

1. **Order Status** — classification: _questions about where an order is, tracking, delivery dates._
2. **Returns & Exchanges** — classification: _returning/exchanging items, refund status, return policy._
3. **General / FAQ** — grounded in Knowledge for everything else (sizing, shipping, warranty).

**Instructions** (natural language, per topic) — e.g. _"Always confirm the order number before giving status. Only reference orders belonging to the authenticated customer. If the customer is frustrated or asks for a person, escalate."_

**Actions** (what the agent can actually _do_):

- **Knowledge retrieval / grounding** action → answers FAQ-style questions from NTO articles. This is your **deflection** engine.
- **"Get Order Status"** — a **custom Apex invocable** (or an Autolaunched Flow) that takes an order number + the authenticated contact and returns status/tracking. **This is hand-coded** and is prime "explain every line" material (see §9 for the skeleton).
- **"Create a Case"** (Flow) if the agent needs to log an issue before escalating.

### 4.2 Grounding / RAG

Articles go into the **Data Library / Knowledge**; Atlas runs **semantic search (RAG)** to pull relevant chunks and ground its answer. Start with a small, high-value set (top 10–20 FAQs) — quality of source docs drives retrieval quality. Be ready to say: grounding is _why_ the agent doesn't hallucinate NTO's return window — it quotes the article, it doesn't invent.

### 4.3 Channel plumbing (the part people fumble)

1. Enable **Messaging** and **Enhanced Omni-Channel** (Setup → Omni-Channel Settings).
2. Build an **Omni-Channel Flow** (Omni-Flow) with a **Route Work** element → routes the incoming conversation to the Agentforce agent; set a **fallback queue** of humans.
3. Create a **Messaging channel** (Messaging for In-App and Web), routing type **Omni-Flow**, attach the flow + fallback queue.
4. Create an **Embedded Service Deployment** (Web Messaging); set the **endpoint/domain** to your Experience site domain; add **Trusted URLs** and configure **CORS**.
5. Drop the **Embedded Messaging** component into the site (or paste the snippet).

### 4.4 Escalation (deflect vs escalate — the heart of Task 2)

- **Deflect** = the agent fully resolves it in chat (FAQ answered from Knowledge, order status returned). No human, no case. This is the metric SEs sell on: deflection rate.
- **Escalate** = the agent can't resolve (no matching action, low confidence), or the customer explicitly asks for a person, or sentiment turns negative → it invokes a **transfer/escalation action** → Omni-Channel routes the **live conversation** to a human queue, **preserving the full transcript** so the customer never repeats themselves → optionally creates/links a **Case**. The human picks it up in the Console (Task 4).

### 4.5 Task 2 — what was config / hand-coded / AI-assisted

| Element                          | Configuration          | Hand-coded       | AI-assisted                 |
| -------------------------------- | ---------------------- | ---------------- | --------------------------- |
| Agent, topics, instructions      | ✔ Agent Builder        | —                | drafting topic instructions |
| Knowledge / grounding            | ✔ Data Library         | —                | drafting article content    |
| Get Order Status action          | invocable registration | ✔ Apex (or Flow) | scaffold + SOQL             |
| Channel / Omni-Flow / deployment | ✔ all config           | —                | —                           |
| Escalation path                  | ✔ Omni-Flow + action   | —                | —                           |

---

## 5. Task 3 — Customer 360 LWC (single customer view)

### 5.1 One component, two homes

The design move: a single LWC, configured per context by `@api` properties.

- `@api recordId` — the Contact/Account/Case in context.
- `@api mode` — `"agent"` (console) or `"customer"` (portal).
- `@api showRiskBadge` — boolean (on for agents, off for customers).
- `@api maxOrders` — integer (how many recent orders to show).
- `@api title` — overridable header.

That `@api` surface _is_ the "@api configurable" requirement on the slide. Same code in the console and the portal; behavior differs only by metadata you set in Lightning App Builder / Experience Builder.

### 5.2 Apex controller

`Customer360Controller.getCustomerSummary(Id recordId)` returns a wrapper: contact details, recent orders, open cases, a lifetime-value rollup, and the risk inputs. Non-negotiables to be able to explain:

- `with sharing` — the class respects the running user's record visibility (so a customer can't pull another customer's 360).
- **User-mode SOQL** (`WITH USER_MODE`) or `Security.stripInaccessible()` — enforces CRUD/FLS so the component never returns a field the user can't see.
- `@AuraEnabled(cacheable=true)` on read methods — enables client caching and Lightning Data Service freshness.

### 5.3 The risk badge (be honest about it)

A **transparent heuristic** for the demo:

```
risk = (open High/Critical cases × 3)
     + (returns in last 90 days × 2)
     + (days since last positive interaction ÷ 30)
→ Low (<3) / Medium (3–6) / High (>6)
```

Then say the production line out loud: _"This is a demonstrative heuristic. In production you'd drive this from a Data Cloud / Einstein churn model or a CRM Analytics score, not arithmetic in Apex."_ Knowing the difference between a demo heuristic and the real ML path is exactly the SE-level judgment they're probing.

### 5.4 Task 3 — config / hand-coded / AI-assisted

| Element           | Configuration                        | Hand-coded                      | AI-assisted            |
| ----------------- | ------------------------------------ | ------------------------------- | ---------------------- |
| LWC (markup + JS) | App Builder placement + `@api` props | ✔ component                     | scaffold, SLDS markup  |
| Apex controller   | —                                    | ✔ with sharing + user-mode SOQL | query methods, wrapper |
| Risk badge        | —                                    | ✔ heuristic                     | the scoring formula    |
| Reuse on portal   | ✔ Experience Builder props           | —                               | —                      |

---

## 6. Task 4 — Agent Workspace (Service Console)

"A workspace an NTO agent would _actually_ use." This layer is mostly **composition**, not new code.

- **Console app** (Lightning Console Navigation) — tabs/subtabs, a **utility bar** with the **Omni-Channel** widget, History, Notes, Macros.
- **Side-by-side layout** — a Lightning page (App Builder) with a two/three-region template: **Customer 360 LWC** on one side, the **live messaging/chat panel** on the other. That side-by-side is the "workspace an agent would use" — context and conversation in one glance.
- **Omni-Channel** — presence statuses, routing config, queues; this is where escalated chats land and where the agent accepts work.

### 6.1 Task 4 — config / hand-coded / AI-assisted

| Element                       | Configuration                  | Hand-coded | AI-assisted        |
| ----------------------------- | ------------------------------ | ---------- | ------------------ |
| Console app, nav, utility bar | ✔                              | —          | —                  |
| Side-by-side page             | ✔ App Builder regions          | —          | layout suggestions |
| Customer 360 in console       | ✔ (reused LWC, `mode="agent"`) | —          | —                  |
| Omni-Channel routing          | ✔                              | —          | —                  |

---

## 7. How Agentforce works under the hood

They'll ask. Here's the accurate, current mental model.

### 7.1 Three ingredients

An agent needs **data, reasoning, and actions**. Agentforce connects to your data, reasons over it, and executes any workflow/automation/API to get work done — natively on the platform.

### 7.2 The Atlas Reasoning Engine — the brain

Atlas is the reasoning engine behind Agentforce. At runtime, for each message:

1. **Trigger & context** — a user message (or a proactive event like a case status change) fires the agent. A context manager loads conversation history, variables, and persona so follow-ups ("what about the second one?") make sense.
2. **Topic classification** — Atlas evaluates the request against every topic and picks the best one, using each topic's _classification description_. The chosen topic scopes the problem: it supplies the instructions, constraints/policies, and the **only** actions the agent may use. This is both the focusing mechanism and the guardrail.
3. **Grounding (RAG)** — Atlas runs semantic search over Knowledge / Data Cloud to retrieve relevant facts and records, and fuses them with the query + instructions into an augmented prompt.
4. **Reason–Act–Observe (ReAct) loop** — it plans a step, **acts** (invokes a Flow / Apex / prompt template / API via function calling), **observes** the result, and decides whether it's done or needs another step. It can pause to ask a clarifying question mid-task.
5. **Response generation** — a generation LLM produces the final grounded, natural-language reply.

A useful nuance to drop: there are effectively **two LLM roles** — a reasoning/planning model (classification + planning) and a separate response-generation model (the text the customer reads). Surfacing the agent's _reasoning_ (visible in Agent Builder) is also a deliberate anti-hallucination and trust mechanism.

### 7.3 The Einstein Trust Layer (your enterprise story)

Every model call passes through the **Einstein Trust Layer**: a secure gateway with dynamic grounding, **PII data masking**, **zero data retention** by the model provider, **prompt-injection defense**, **toxicity detection**, and a full **audit trail**. Models can be Salesforce-hosted or **bring-your-own** (Anthropic Claude, OpenAI on Azure, Google, Amazon Bedrock) — all routed through the Trust Layer. For an SE, the Trust Layer is the answer to the first question every enterprise buyer asks: _"what happens to our data?"_

### 7.4 Mapped to your NTO demo

- _"Where's my order #12345?"_ → Atlas classifies → **Order Status** topic → reads instructions ("confirm order #, only this customer's orders") → calls the **Get Order Status** Apex action with the authenticated contact + order number → observes the record → generates _"Shipped Tuesday, arriving Thursday — here's tracking."_ That's a **deflection**.
- _"This is ridiculous, get me a person."_ → no resolving action + explicit human intent → **escalation** action → Omni-Channel routes the live chat to a human in the Console with full transcript. That's an **escalation**.

### 7.5 The line for the room

> "Agentforce is **topic-scoped reasoning over your governed Salesforce data and actions**, with every model call passing through the **Einstein Trust Layer** — so it's autonomous but bounded by the same metadata, sharing rules, and guardrails as the rest of the org."

---

## 8. Five-day execution plan

The slide budgets 5 days for **all four tasks**. Front-load foundation so nothing blocks later.

**Day 1 — Foundation.** Org prep (Agentforce Dev Edition). Enable Digital Experiences, Einstein, Agentforce, Messaging, Enhanced Omni-Channel. Build the data model + the one custom object. Load NTO sample data (accounts → contacts → community users, products, orders, cases, knowledge articles). Stand up the LWR site shell + auth + sharing sets.

**Day 2 — Experience site front end.** Branding (theme, logo, colors, fonts, CSS). Home page. Build `ntoMyOrders` + `ntoMyCases` LWCs + Apex controllers + tests. Create-case Screen Flow. Navigation. Responsive pass.

**Day 3 — Agentforce + embedded chat.** Build the Service Agent (topics, instructions, knowledge/grounding, Get Order Status Apex action). Omni-Flow + messaging channel + embedded deployment. Trusted URLs / CORS. Embed in the site. Test **deflection** and **escalation** end to end.

**Day 4 — Customer 360 + Console.** Build the `customer360` LWC + Apex controller + risk badge; make it `@api`-configurable. Build the Console app with Omni-Channel. Compose the side-by-side workspace page. Reuse the 360 on the portal.

**Day 5 — Polish, mobile, E2E, rehearsal.** Responsive/mobile pass, empty/error states, one clean end-to-end run (customer → deflect → escalate → agent works the case). Seed-data sanity. **Package it for redeployability** — metadata in source control, deploy via `sf` CLI, no hardcoded IDs (use Custom Metadata / Named Credentials for config). Rehearse the "explain every line" walkthrough.

---

## 9. Interview prep — "explain every line"

### 9.1 The Apex they'll grill (illustrative skeleton — flesh out and own it)

```apex
public with sharing class OrderController {
  // cacheable=true → client-side caching + Lightning Data Service freshness.
  // with sharing (class) → respects the running customer's record visibility.
  @AuraEnabled(cacheable=true)
  public static List<Order> getMyOrders(Integer maxRows) {
    Id contactId = [
      SELECT ContactId
      FROM User
      WHERE Id = :UserInfo.getUserId()
      WITH USER_MODE
    ]
    .ContactId; // resolve the logged-in community user → Contact

    return [
      SELECT Id, OrderNumber, Status, EffectiveDate, TotalAmount
      FROM Order
      WHERE BillToContactId = :contactId // only THIS customer's orders
      WITH USER_MODE // enforce CRUD/FLS at query time
      ORDER BY EffectiveDate DESC
      LIMIT :maxRows
    ];
  }
}
```

For every token in that block, have the _why_: `with sharing` vs `WITH USER_MODE` (object/sharing vs field/CRUD enforcement — they're complementary, not redundant), why you filter by the authenticated contact (data isolation), why `cacheable`, why `LIMIT` is parameterized. That's the depth the panel is checking.

### 9.2 Questions they'll ask — and crisp answers

- **Why LWR over Aura?** Modern stack, performance, control; trade-off is fewer drag-drop components → more authored LWCs (which you can explain).
- **How do you stop one customer seeing another's data?** OWD private + sharing sets keyed on Contact/Account; user-mode SOQL enforces FLS on top.
- **How does the agent avoid hallucinating?** Topic scoping + RAG grounding on Knowledge/records + visible reasoning; it quotes governed data, it doesn't invent.
- **What's the Trust Layer?** Secure gateway: masking, zero-retention, prompt defense, toxicity, audit — the "what happens to our data" answer.
- **What does the risk badge actually mean?** A demo heuristic; production would be a Data Cloud / Einstein model.
- **How would you scale this to production?** Data Cloud for unified profiles + real churn scoring, proper Knowledge governance, conversation analytics on deflection/transfer rates, CI/CD on the metadata.
- **Is it really redeployable by any SE?** Yes — metadata in source control, `sf` CLI deploy, zero hardcoded IDs, config externalized to Custom Metadata.

### 9.3 The honesty move on AI assistance

The slide explicitly allows AI tools — so don't hide it, but **own it**. The panel will probe the AI-assisted code _hardest_, because that's where candidates fall apart. The defense isn't "AI wrote it"; it's being able to explain, unprompted, why each security annotation, each `@wire`, each guardrail exists, and what you changed from the first draft and why. Walk in able to whiteboard the order-status flow and the escalation path from memory. If you can do that, the AI-assisted parts become a strength ("I used AI to scaffold, then hardened the security and tightened the queries"), not a liability.

### 9.4 Redeployability checklist

- All metadata in a repo, deployed via `sf project deploy start`.
- No hardcoded record IDs anywhere; config in Custom Metadata / Custom Settings.
- Named Credentials for any external endpoints.
- A short README: enable steps (Digital Experiences, Einstein, Agentforce, Messaging, Omni), deploy order, sample-data script.
