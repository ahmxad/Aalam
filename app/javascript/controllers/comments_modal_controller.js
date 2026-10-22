import { Controller } from "@hotwired/stimulus";

// Opens and closes the comments window on top of the post page
export default class extends Controller {
  static targets = ["dialog"];

  open() {
    if (!this.dialogTarget.open) this.dialogTarget.showModal();
  }

  close() {
    this.dialogTarget.close();
  }

  // A click on the dimmed area (the dialog itself, not its content) closes the window
  closeOnBackdrop(event) {
    if (event.target === this.dialogTarget) this.close();
  }
  // Wheel and touch scrolling inside the window must not reach scripts that scroll the page behind it
  keepScrollInside(event) {
    event.stopPropagation();
  }
}
