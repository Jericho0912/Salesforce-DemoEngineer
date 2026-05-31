/**
 * Why this approach: two complementary wires keep the UI declarative and cached. getRecord
 * pulls the Contact's display fields straight from Salesforce's UI API (no Apex round-trip),
 * while the cacheable getCustomerSummary wire returns the computed lifetime value, open-case
 * count, risk flag, and recent cases. Both refresh automatically when recordId changes, so the
 * same component drops onto a Contact page, an app page, or a portal profile unchanged.
 */
import { LightningElement, api, wire } from "lwc";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import getCustomerSummary from "@salesforce/apex/Customer360Controller.getCustomerSummary";
import NAME_FIELD from "@salesforce/schema/Contact.Name";
import EMAIL_FIELD from "@salesforce/schema/Contact.Email";
import ACCOUNT_NAME_FIELD from "@salesforce/schema/Contact.Account.Name";

const CONTACT_FIELDS = [NAME_FIELD, EMAIL_FIELD, ACCOUNT_NAME_FIELD];

export default class Customer360 extends LightningElement {
  @api recordId; // Contact Id

  contact;
  contactError;

  summary;
  summaryError;
  summaryLoaded = false;

  @wire(getRecord, { recordId: "$recordId", fields: CONTACT_FIELDS })
  wiredContact({ data, error }) {
    if (data) {
      this.contact = data;
      this.contactError = undefined;
    } else if (error) {
      this.contactError = error;
      this.contact = undefined;
    }
  }

  @wire(getCustomerSummary, { contactId: "$recordId" })
  wiredSummary({ data, error }) {
    if (data) {
      this.summary = data;
      this.summaryError = undefined;
      this.summaryLoaded = true;
    } else if (error) {
      this.summaryError = error;
      this.summary = undefined;
      this.summaryLoaded = true;
    }
  }

  get name() {
    return getFieldValue(this.contact, NAME_FIELD);
  }

  get email() {
    return getFieldValue(this.contact, EMAIL_FIELD);
  }

  get accountName() {
    return getFieldValue(this.contact, ACCOUNT_NAME_FIELD);
  }

  get isLoading() {
    return !this.summaryLoaded;
  }

  get hasError() {
    return Boolean(this.summaryError || this.contactError);
  }

  get errorMessage() {
    const e = this.summaryError || this.contactError;
    if (!e) {
      return "";
    }
    if (Array.isArray(e.body)) {
      return e.body.map((b) => b.message).join(", ");
    }
    if (e.body && e.body.message) {
      return e.body.message;
    }
    return "An unexpected error occurred while loading customer data.";
  }

  get hasRecentCases() {
    return Boolean(
      this.summary &&
      this.summary.recentCases &&
      this.summary.recentCases.length > 0
    );
  }
}
