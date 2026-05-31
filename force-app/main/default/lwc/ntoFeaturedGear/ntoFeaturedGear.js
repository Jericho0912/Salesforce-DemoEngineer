import { LightningElement, api, wire } from "lwc";
import getFeaturedGear from "@salesforce/apex/ProductController.getFeaturedGear";

export default class NtoFeaturedGear extends LightningElement {
  @api maxRows = 4;

  gear;
  error;

  @wire(getFeaturedGear, { maxRows: "$maxRows" })
  wiredGear({ data, error }) {
    if (data) {
      this.gear = data;
      this.error = undefined;
    } else if (error) {
      this.error = error;
      this.gear = undefined;
    }
  }

  get isLoading() {
    return this.gear === undefined && this.error === undefined;
  }

  get hasError() {
    return this.error !== undefined;
  }

  get hasData() {
    return Array.isArray(this.gear) && this.gear.length > 0;
  }

  get isEmpty() {
    return Array.isArray(this.gear) && this.gear.length === 0;
  }

  get errorMessage() {
    if (!this.error) {
      return "";
    }
    if (this.error.body && this.error.body.message) {
      return this.error.body.message;
    }
    if (this.error.message) {
      return this.error.message;
    }
    return "Something went wrong loading featured gear.";
  }

  get cards() {
    if (!Array.isArray(this.gear)) {
      return [];
    }
    return this.gear.map((item, index) => ({
      key: `${index}-${item.name}`,
      name: item.name,
      family: item.family,
      price: item.price,
      imageUrl: item.imageUrl
    }));
  }
}
