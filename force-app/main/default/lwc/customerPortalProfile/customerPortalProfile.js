/**
 * Why this approach: the portal component takes no recordId — it calls a cacheable Apex method that
 * resolves the logged-in user's own contact server-side, so a customer can only ever see their own
 * orders and cases. One wire, with loading/error/empty states, renders the whole "My Account" view.
 */
import { LightningElement, wire } from "lwc";
import getMyProfile from "@salesforce/apex/PortalCustomerController.getMyProfile";

export default class CustomerPortalProfile extends LightningElement {
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
    if (!e) {
      return "";
    }
    if (Array.isArray(e.body)) {
      return e.body.map((b) => b.message).join(", ");
    }
    if (e.body && e.body.message) {
      return e.body.message;
    }
    return "We could not load your account right now. Please try again later.";
  }

  get summary() {
    return this.profile ? this.profile.summary : undefined;
  }

  get orders() {
    return this.profile ? this.profile.orders : [];
  }

  get hasOrders() {
    return this.orders && this.orders.length > 0;
  }

  get recentCases() {
    return this.summary ? this.summary.recentCases : [];
  }

  get hasCases() {
    return this.recentCases && this.recentCases.length > 0;
  }
}
