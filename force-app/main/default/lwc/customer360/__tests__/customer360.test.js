import { createElement } from "lwc";
import Customer360 from "c/customer360";
import { getRecord } from "lightning/uiRecordApi";
import getCustomerSummary from "@salesforce/apex/Customer360Controller.getCustomerSummary";

// Apex methods are mocked as test wire adapters so we can drive data/error states.
jest.mock(
  "@salesforce/apex/Customer360Controller.getCustomerSummary",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

const CONTACT_RECORD = {
  apiName: "Contact",
  fields: {
    Name: { value: "Avery Stone" },
    Email: { value: "avery.stone@nto-demo.com" },
    Account: { value: { fields: { Name: { value: "NTO Hero Account" } } } }
  }
};

const AT_RISK_SUMMARY = {
  contactId: "003000000000001",
  name: "Avery Stone",
  email: "avery.stone@nto-demo.com",
  accountName: "NTO Hero Account",
  lifetimeValue: 4798.49,
  openCaseCount: 3,
  atRisk: true,
  recentCases: [
    {
      id: "500000000000001",
      caseNumber: "00001",
      subject: "Hero escalation #1",
      status: "Escalated",
      priority: "High",
      isClosed: false
    },
    {
      id: "500000000000002",
      caseNumber: "00002",
      subject: "Hero escalation #2",
      status: "Working",
      priority: "High",
      isClosed: false
    }
  ]
};

const EMPTY_SUMMARY = {
  contactId: "003000000000009",
  name: "Thin Customer",
  email: "thin@nto-demo.com",
  accountName: "NTO Customer 1",
  lifetimeValue: 0,
  openCaseCount: 0,
  atRisk: false,
  recentCases: []
};

function createComponent() {
  const element = createElement("c-customer360", { is: Customer360 });
  element.recordId = "003000000000001";
  document.body.appendChild(element);
  return element;
}

function flushPromises() {
  return Promise.resolve();
}

describe("c-customer360", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("shows a spinner before data resolves", () => {
    const element = createComponent();
    const spinner = element.shadowRoot.querySelector("lightning-spinner");
    expect(spinner).not.toBeNull();
  });

  it("renders the At Risk badge, lifetime value and cases for a hero contact", async () => {
    const element = createComponent();
    getRecord.emit(CONTACT_RECORD);
    getCustomerSummary.emit(AT_RISK_SUMMARY);
    await flushPromises();

    const badge = element.shadowRoot.querySelector(".risk-badge");
    expect(badge).not.toBeNull();

    const ltv = element.shadowRoot.querySelector("lightning-formatted-number");
    expect(ltv.value).toBe(4798.49);

    const caseItems = element.shadowRoot.querySelectorAll("ul li");
    expect(caseItems.length).toBe(2);
  });

  it("shows the empty state and no risk badge for a thin contact", async () => {
    const element = createComponent();
    getRecord.emit(CONTACT_RECORD);
    getCustomerSummary.emit(EMPTY_SUMMARY);
    await flushPromises();

    expect(element.shadowRoot.querySelector(".risk-badge")).toBeNull();
    expect(element.shadowRoot.textContent).toContain("No cases on file");
  });

  it("renders an error message when the summary wire fails", async () => {
    const element = createComponent();
    getCustomerSummary.error();
    await flushPromises();

    const alert = element.shadowRoot.querySelector('[role="alert"]');
    expect(alert).not.toBeNull();
  });
});
