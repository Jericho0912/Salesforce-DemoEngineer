import { LightningElement, wire } from "lwc";
import { refreshApex } from "@salesforce/apex";
import getMyCases from "@salesforce/apex/PortalCustomerController.getMyCases";

// Wire returns: id, caseNumber, subject, status, priority, createdDate, isClosed.
// No controller changes made.

const STATUS_CLASSES = {
  New: "nto-case-pill nto-case-pill_new",
  Working: "nto-case-pill nto-case-pill_working",
  Escalated: "nto-case-pill nto-case-pill_escalated",
  Closed: "nto-case-pill nto-case-pill_closed"
};

const PRIORITY_CLASSES = {
  High: "priority-dot priority-high",
  Medium: "priority-dot priority-medium",
  Low: "priority-dot priority-low"
};

function formatOpenedDate(dateStr) {
  if (!dateStr) return "";
  try {
    return new Intl.DateTimeFormat(navigator.language || "en-US", {
      month: "short",
      day: "2-digit",
      year: "numeric"
    }).format(new Date(dateStr));
  } catch {
    return "";
  }
}

export default class NtoMyCases extends LightningElement {
  _wiredCasesResult;
  rawCases;
  error;
  loaded = false;
  showCaseForm = false;
  _activeStatusFilter = "All";
  _caseSearch = "";

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

  get statusFilterOptions() {
    return [
      { label: "All", value: "All" },
      { label: "Open", value: "New" },
      { label: "Working", value: "Working" },
      { label: "Escalated", value: "Escalated" },
      { label: "Closed", value: "Closed" }
    ].map((o) => ({
      ...o,
      cls:
        o.value === this._activeStatusFilter
          ? "nto-filter-chip nto-filter-chip_active"
          : "nto-filter-chip"
    }));
  }

  get cases() {
    if (!this.rawCases) return [];
    return this.rawCases.map((c) => {
      const subjectTrimmed = c.subject && c.subject.trim();
      return {
        ...c,
        displaySubject: subjectTrimmed || "Untitled case",
        isUntitled: !subjectTrimmed,
        subjectClass: subjectTrimmed
          ? "case-subject"
          : "case-subject case-subject_untitled",
        openedLabel: c.createdDate
          ? "Opened " + formatOpenedDate(c.createdDate)
          : "",
        statusClass:
          STATUS_CLASSES[c.status] || "nto-case-pill nto-case-pill_new",
        priorityClass:
          PRIORITY_CLASSES[c.priority] || "priority-dot priority-low"
      };
    });
  }

  get filteredCases() {
    let cases = this.cases;
    if (this._activeStatusFilter !== "All") {
      cases = cases.filter((c) => c.status === this._activeStatusFilter);
    }
    const q = this._caseSearch.trim().toLowerCase();
    if (q) {
      cases = cases.filter(
        (c) =>
          (c.caseNumber && c.caseNumber.toLowerCase().includes(q)) ||
          (c.subject && c.subject.toLowerCase().includes(q))
      );
    }
    return cases;
  }

  get hasCases() {
    return this.filteredCases && this.filteredCases.length > 0;
  }

  handleStatusFilterClick(event) {
    this._activeStatusFilter = event.currentTarget.dataset.value;
  }

  handleCaseSearch(event) {
    this._caseSearch = event.target.value;
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
