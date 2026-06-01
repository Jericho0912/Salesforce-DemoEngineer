import { LightningElement, api, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import getMyOrders from "@salesforce/apex/PortalCustomerController.getMyOrders";

// Wire returns: orderNumber, status, total — no date, itemCount, or thumbnails.
// If those fields are needed later, extend PortalCustomerController.OrderInfo.

const STATUS_MAP = {
  Processing: {
    pillClass: "nto-order-pill nto-order-pill_processing",
    statusText: "We’re preparing your order"
  },
  Shipped: {
    pillClass: "nto-order-pill nto-order-pill_shipped",
    statusText: "On its way to you"
  },
  Delivered: {
    pillClass: "nto-order-pill nto-order-pill_delivered",
    statusText: "Successfully delivered"
  },
  Returned: {
    pillClass: "nto-order-pill nto-order-pill_returned",
    statusText: "Return processed"
  }
};

const FALLBACK = {
  pillClass: "nto-order-pill nto-order-pill_processing",
  statusText: ""
};

export default class NtoMyOrders extends NavigationMixin(LightningElement) {
  @api maxRows = 5;

  _data;
  _error;
  _activeFilter = "All";
  _searchQuery = "";

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

  get filterOptions() {
    return [
      { label: "All", value: "All" },
      { label: "In transit", value: "Shipped" },
      { label: "Delivered", value: "Delivered" },
      { label: "Returns", value: "Returned" }
    ].map((o) => ({
      ...o,
      cls:
        o.value === this._activeFilter
          ? "nto-filter-chip nto-filter-chip_active"
          : "nto-filter-chip"
    }));
  }

  get displayOrders() {
    if (!Array.isArray(this._data)) return [];
    return this._data.slice(0, this.maxRows).map((order) => {
      const d = STATUS_MAP[order.status] || FALLBACK;
      return {
        ...order,
        pillClass: d.pillClass,
        statusText: d.statusText,
        key: order.orderNumber
      };
    });
  }

  get filteredOrders() {
    let orders = this.displayOrders;
    if (this._activeFilter !== "All") {
      orders = orders.filter((o) => o.status === this._activeFilter);
    }
    const q = this._searchQuery.trim().toLowerCase();
    if (q) {
      orders = orders.filter((o) => o.orderNumber.toLowerCase().includes(q));
    }
    return orders;
  }

  get hasFilteredOrders() {
    return this.filteredOrders.length > 0;
  }

  get errorMessage() {
    const e = this._error;
    if (!e) return "";
    if (e.body && Array.isArray(e.body))
      return e.body
        .map((b) => b.message)
        .filter(Boolean)
        .join(", ");
    if (e.body && e.body.message) return e.body.message;
    if (typeof e.message === "string") return e.message;
    return "We couldn’t load your orders right now. Please try again in a moment.";
  }

  handleFilterClick(event) {
    this._activeFilter = event.currentTarget.dataset.value;
  }

  handleSearch(event) {
    this._searchQuery = event.target.value;
  }

  handleViewOrder(event) {
    event.preventDefault();
    // View order detail — no detail page wired yet; no-op to prevent href navigation.
  }

  handleReturnItem() {
    // Navigates to My Cases page so the customer can open a return case via
    // the existing NTO_Create_Case flow. No separate return mechanism built.
    this[NavigationMixin.Navigate]({
      type: "comm__namedPage",
      attributes: { name: "My_Cases__c" }
    });
  }

  handleGoHome() {
    this[NavigationMixin.Navigate]({
      type: "comm__namedPage",
      attributes: { name: "Home" }
    });
  }
}
