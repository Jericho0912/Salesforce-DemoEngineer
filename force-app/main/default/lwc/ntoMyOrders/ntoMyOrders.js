/**
 * NTO My Orders
 *
 * Why this approach:
 *   - Reads the running portal user's recent orders via `OrderController.getMyOrders`,
 *     which self-resolves the contact on the server. No recordId from the page means
 *     the component is safe to drop on any Experience Builder page.
 *   - `maxRows` is `@api` and passed reactively into the wire so Experience Builder
 *     authors can re-use the same component on Home (small count) and on a dedicated
 *     My Orders page (larger count) without code changes.
 *   - Status -> presentation mapping lives in a JS getter (`displayOrders`), not in
 *     markup, so the template stays declarative and new statuses are a one-line add.
 */
import { LightningElement, api, wire } from "lwc";
import getMyOrders from "@salesforce/apex/PortalCustomerController.getMyOrders";

const STATUS_MAP = {
  Processing: {
    badgeClass: "slds-badge",
    dotClass: "nto-dot nto-dot_slate",
    statusText: "We're preparing your order"
  },
  Shipped: {
    badgeClass: "slds-badge slds-theme_info",
    dotClass: "nto-dot nto-dot_blue",
    statusText: "On its way to you"
  },
  Delivered: {
    badgeClass: "slds-badge slds-theme_success",
    dotClass: "nto-dot nto-dot_green",
    statusText: "Successfully delivered"
  }
};

const FALLBACK_DECORATION = {
  badgeClass: "slds-badge",
  dotClass: "nto-dot nto-dot_slate",
  statusText: ""
};

export default class NtoMyOrders extends LightningElement {
  /** Experience Builder configurable. Forwarded to the Apex wire. */
  @api maxRows = 5;

  _data;
  _error;

  @wire(getMyOrders)
  wiredOrders({ data, error }) {
    if (data) {
      this._data = data;
      this._error = undefined;
    } else if (error) {
      this._error = error;
      this._data = undefined;
    }
  }

  get isLoading() {
    return this._data === undefined && this._error === undefined;
  }

  get hasError() {
    return this._error !== undefined;
  }

  get hasOrders() {
    return Array.isArray(this._data) && this._data.length > 0;
  }

  get isEmpty() {
    return !this.isLoading && !this.hasError && !this.hasOrders;
  }

  /**
   * Decorate the raw OrderCard list with presentation-only fields. Keeps the
   * markup free of conditional class soup and makes status mapping a single
   * source of truth.
   */
  get displayOrders() {
    if (!Array.isArray(this._data)) return [];
    return this._data.slice(0, this.maxRows).map((order) => {
      const decoration = STATUS_MAP[order.status] || FALLBACK_DECORATION;
      return {
        ...order,
        badgeClass: decoration.badgeClass,
        dotClass: decoration.dotClass,
        statusText: decoration.statusText,
        key: order.orderNumber
      };
    });
  }

  get errorMessage() {
    const e = this._error;
    if (!e) return "";
    if (e.body && Array.isArray(e.body)) {
      return e.body
        .map((b) => b.message)
        .filter(Boolean)
        .join(", ");
    }
    if (e.body && e.body.message) {
      return e.body.message;
    }
    if (typeof e.message === "string") {
      return e.message;
    }
    return "We couldn't load your orders right now. Please try again in a moment.";
  }

  handleViewOrder(event) {
    // The link is intentionally a no-op for the home dashboard demo — it
    // exists so the card has an affordance. Prevent the browser from
    // navigating to the href="javascript:void(0)" stub.
    event.preventDefault();
  }
}
