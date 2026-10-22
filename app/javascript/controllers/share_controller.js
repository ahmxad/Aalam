import { Controller } from "@hotwired/stimulus";

// Shares the post: the phone's share menu on touch devices, a copied link everywhere else.
// A successful share is reported to the server, which keeps the share count.
export default class extends Controller {
  static targets = ["form", "status"];
  static values = { url: String, title: String };

  disconnect() {
    clearTimeout(this.timer);
  }

  async share() {
    try {
      if (this.canUseShareMenu()) {
        await navigator.share({ title: this.titleValue, url: this.urlValue });
      } else {
        await navigator.clipboard.writeText(this.urlValue);
        this.say("Link copied");
      }
      this.report();
    } catch (error) {
      // Closing the share menu is not a failure, and it is not counted
      if (error.name === "AbortError") return;

      // The browser refused to copy, so the person copies the link by hand
      window.prompt("Copy this link:", this.urlValue);
    }
  }

  canUseShareMenu() {
    return (
      typeof navigator.share === "function" &&
      window.matchMedia("(pointer: coarse)").matches
    );
  }

  // Submitting the hidden form lets Turbo send the request and update the count
  report() {
    this.formTarget.requestSubmit();
  }

  say(message) {
    this.statusTarget.textContent = message;
    clearTimeout(this.timer);
    this.timer = setTimeout(() => {
      this.statusTarget.textContent = "";
    }, 2500);
  }
}
