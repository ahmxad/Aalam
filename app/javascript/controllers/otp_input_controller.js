import { Controller } from "@hotwired/stimulus";

// Keeps only the digits of a typed or pasted code, and submits the form once the code is complete.
// Put it on the input itself.
export default class extends Controller {
  static values = { length: { type: Number, default: 6 } };

  format() {
    const digits = this.element.value
      .replace(/\D/g, "")
      .slice(0, this.lengthValue);
    this.element.value = digits;

    if (digits.length === this.lengthValue) this.element.form.requestSubmit();
  }
}
