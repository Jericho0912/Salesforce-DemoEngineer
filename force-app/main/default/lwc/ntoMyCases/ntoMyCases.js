/**
 * Why this approach: a standalone portal component that self-resolves the logged-in user's
 * cases via PortalCustomerController.getMyCases() — never accepts a recordId, so a customer
 * can only see their own cases. "Log a Case" launches NTO_Create_Case inline via
 * lightning-flow; no page navigation, no named-page dependency.
 */
import { LightningElement, wire } from "lwc";
import { refreshApex } from "@salesforce/apex";
import getMyCases from "@salesforce/apex/PortalCustomerController.getMyCases";

const STATUS_CLASSES = {
  New: "status-badge status-new",
  Working: "status-badge status-working",
  Escalated: "status-badge status-escalated",
  Closed: "status-badge status-closed"
};

const PRIORITY_CLASSES = {
  High: "priority-dot priority-high",
  Medium: "priority-dot priority-medium",
  Low: "priority-dot priority-low"
};

export default class NtoMyCases extends LightningElement {
  _wiredCasesResult;
  rawCases;
  error;
  loaded = false;
  showCaseForm = false;

  @wire(getMyCases)
  wiredCases(result) {
    this._wiredCasesResult = result;
    const { data, error } = result;
    if (data) {
      this.rawCases = data;
      this.error = undefined;
      this.loaded = true;
    } else if (error) {
      this.error = error;
      this.rawCases = undefined;
      this.loaded = true;
    }
  }

  get isLoading() {
    return !this.loaded;
  }

  get hasError() {
    return Boolean(this.error);
  }

  get errorMessage() {
    const e = this.error;
    if (!e) return "";
    if (Array.isArray(e.body)) return e.body.map((b) => b.message).join(", ");
    if (e.body && e.body.message) return e.body.message;
    return "We could not load your cases right now. Please try again later.";
  }

  get cases() {
    if (!this.rawCases) return [];
    return this.rawCases.map((c) => ({
      ...c,
      statusClass: STATUS_CLASSES[c.status] || "status-badge status-new",
      priorityClass: PRIORITY_CLASSES[c.priority] || "priority-dot priority-low"
    }));
  }

  get hasCases() {
    return this.cases && this.cases.length > 0;
  }

  handleLogCase() {
    this.showCaseForm = true;
  }

  handleCancelCase() {
    this.showCaseForm = false;
  }

  handleFlowStatusChange(event) {
    const { status } = event.detail;
    if (status === "FINISHED" || status === "FINISHED_SCREEN") {
      this.showCaseForm = false;
      refreshApex(this._wiredCasesResult);
    }
  }
}
