import { LightningElement, api } from "lwc";
import { CloseActionScreenEvent } from "lightning/actions";

export default class SampleComponent extends LightningElement {
  @api recordId;
  @api objectApiName;

  inputValue = "";

  // handlers, getters, setters
  // what more should I know?
  // I am not familiar with 'this' keyword.

  handleCancel() {
    this.dispatchEvent(new CloseActionScreenEvent());
  }

  // every time you use input or click? you must use events
  // find more about this lol

  handleInputChange(event) {
    this.inputValue = event.target.value;
    console.log(this.inputValue);
  }
}
