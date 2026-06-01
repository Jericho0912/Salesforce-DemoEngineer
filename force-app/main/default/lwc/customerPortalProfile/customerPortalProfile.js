import { LightningElement, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import getMyProfile from "@salesforce/apex/PortalCustomerController.getMyProfile";

export default class CustomerPortalProfile extends NavigationMixin(
  LightningElement
) {
  profile;
  error;
  loaded = false;

  @wire(getMyProfile)
  wiredProfile({ data, error }) {
    if (data) {
      this.profile = data;
      this.error = undefined;
      this.loaded = true;
    } else if (error) {
      this.error = error;
      this.profile = undefined;
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
    return "We could not load your account right now. Please try again later.";
  }

  get summary() {
    return this.profile ? this.profile.summary : undefined;
  }

  get orders() {
    return this.profile ? this.profile.orders : [];
  }

  get hasOrders() {
    return Array.isArray(this.orders) && this.orders.length > 0;
  }

  get recentCases() {
    return this.summary ? this.summary.recentCases : [];
  }

  get hasCases() {
    return Array.isArray(this.recentCases) && this.recentCases.length > 0;
  }

  get initials() {
    const name = this.summary && this.summary.name;
    if (!name) return "?";
    const parts = name.trim().split(/\s+/);
    if (parts.length === 1) return parts[0].charAt(0).toUpperCase();
    return (
      parts[0].charAt(0) + parts[parts.length - 1].charAt(0)
    ).toUpperCase();
  }

  get displayCases() {
    if (!Array.isArray(this.recentCases)) return [];
    return this.recentCases.map((c) => ({
      id: c.id,
      caseNumber: c.caseNumber,
      status: c.status,
      priority: c.priority,
      displaySubject:
        c.subject && c.subject.trim()
          ? c.subject
          : "(No subject) — " + c.caseNumber
    }));
  }

  handleLogout() {
    this[NavigationMixin.Navigate]({
      type: "comm__loginPage",
      attributes: { actionName: "logout" }
    });
  }

  handleViewAllOrders() {
    this[NavigationMixin.Navigate]({
      type: "comm__namedPage",
      attributes: { name: "My_Orders__c" }
    });
  }

  handleViewAllCases() {
    this[NavigationMixin.Navigate]({
      type: "comm__namedPage",
      attributes: { name: "My_Cases__c" }
    });
  }
}
