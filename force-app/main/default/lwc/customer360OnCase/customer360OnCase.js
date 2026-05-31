/**
 * Why this approach: a thin wrapper keeps customer360 single-responsibility (Contact-driven)
 * while still serving the Case workspace. It wires the Case's ContactId, then hands that down to
 * the shared customer360 component — so the agent sees full customer context the moment a Case
 * opens, with zero duplicated logic between the Contact page and the Case page.
 */
import { LightningElement, api, wire } from "lwc";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import CASE_CONTACT_ID from "@salesforce/schema/Case.ContactId";

export default class Customer360OnCase extends LightningElement {
  @api recordId; // Case Id

  contactId;
  loaded = false;

  @wire(getRecord, { recordId: "$recordId", fields: [CASE_CONTACT_ID] })
  wiredCase({ data }) {
    if (data !== undefined) {
      this.loaded = true;
      this.contactId = getFieldValue(data, CASE_CONTACT_ID);
    }
  }

  get hasContact() {
    return Boolean(this.contactId);
  }

  get showNoContact() {
    return this.loaded && !this.contactId;
  }
}
