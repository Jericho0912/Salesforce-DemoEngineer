import { LightningElement, api } from "lwc";

// Status -> SLDS pill theme. Mapping lives here (presentation), not in Apex.
const PILL_BY_STATUS = {
  Processing: "slds-theme_warning",
  Shipped: "slds-theme_info",
  Delivered: "slds-theme_success",
  Returned: "slds-theme_error"
};

export default class NtoOrderListRenderer extends LightningElement {
  // Populated by the platform with the CLT output object (OrderCardList).
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
