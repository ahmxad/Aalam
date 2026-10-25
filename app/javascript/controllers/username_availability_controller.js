import { Controller } from "@hotwired/stimulus";

// Checks the username while the user types, so they see problems before submitting.
// The server still validates again on sign up.
export default class extends Controller {
  static targets = ["input", "hint"];
  static values = { url: String, delay: { type: Number, default: 400 } };

  connect() {
    // The form can be re-rendered with a username already filled in
    if (this.inputTarget.value.trim() !== "") this.check();
  }

  disconnect() {
    clearTimeout(this.timer);
    this.request?.abort();
  }

  check() {
    clearTimeout(this.timer);
    this.request?.abort();

    const username = this.inputTarget.value.trim();
    if (username === "") return this.show("");

    this.show("Checking...");
    this.timer = setTimeout(
      () => this.fetchAvailability(username),
      this.delayValue,
    );
  }

  async fetchAvailability(username) {
    this.request = new AbortController();

    try {
      const response = await fetch(
        `${this.urlValue}?username=${encodeURIComponent(username)}`,
        {
          headers: { Accept: "application/json" },
          signal: this.request.signal,
        },
      );
      if (!response.ok) throw new Error("Request failed");

      const result = await response.json();
      this.show(result.message, result.available ? "success" : "error");
    } catch (error) {
      if (error.name !== "AbortError")
        this.show("Could not check the username right now");
    }
  }

  show(message, state = "neutral") {
    this.hintTarget.textContent = message;
    this.hintTarget.classList.toggle("text-success", state === "success");
    this.hintTarget.classList.toggle("text-error", state === "error");
  }
}
