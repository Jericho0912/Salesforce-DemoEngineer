import { LightningElement, api, wire } from "lwc";
import getCurrentUserFirstName from "@salesforce/apex/UserContextController.getCurrentUserFirstName";

export default class WelcomeToast extends LightningElement {
  @api autoDismissMs = 5000;

  firstName;
  visible = true;
  _dismissTimerId;

  @wire(getCurrentUserFirstName)
  wiredName({ data, error }) {
    if (data) {
      this.firstName = data;
    } else if (error) {
      // Soft greeting only — hide banner on error, no error UI.
      this.visible = false;
    }
  }

  connectedCallback() {
    const delay = Number(this.autoDismissMs);
    if (Number.isFinite(delay) && delay > 0) {
      // eslint-disable-next-line @lwc/lwc/no-async-operation
      this._dismissTimerId = setTimeout(() => this.dismiss(), delay);
    }
  }

  disconnectedCallback() {
    if (this._dismissTimerId) {
      clearTimeout(this._dismissTimerId);
      this._dismissTimerId = undefined;
    }
  }

  get greeting() {
    const name = this.firstName && String(this.firstName).trim();
    return name ? `Welcome back, ${name}` : "Welcome back";
  }

  dismiss = () => {
    this.visible = false;
    if (this._dismissTimerId) {
      clearTimeout(this._dismissTimerId);
      this._dismissTimerId = undefined;
    }
  };

  handleDismissClick() {
    this.dismiss();
  }
}
