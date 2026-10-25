import { Controller } from "@hotwired/stimulus";

// Shows a live strength rating while the user types a password.
// This is only a hint: the server still enforces the real rules.
const COMMON_PASSWORDS = new Set([
  "password",
  "password1",
  "password123",
  "12345678",
  "123456789",
  "1234567890",
  "qwerty123",
  "iloveyou",
  "admin123",
  "letmein1",
  "welcome1",
]);

const BAR_CLASSES = ["progress-error", "progress-warning", "progress-success"];
const TEXT_CLASSES = ["text-error", "text-warning", "text-success"];

const LEVELS = [
  {
    label: "Too short (at least 8 characters)",
    value: 1,
    bar: "progress-error",
    text: "text-error",
  },
  {
    label: "Weak password",
    value: 1,
    bar: "progress-error",
    text: "text-error",
  },
  {
    label: "Fair password",
    value: 2,
    bar: "progress-warning",
    text: "text-warning",
  },
  {
    label: "Strong password",
    value: 3,
    bar: "progress-success",
    text: "text-success",
  },
];

export default class extends Controller {
  static targets = ["input", "meter", "label"];

  update() {
    const password = this.inputTarget.value;
    this.render(password === "" ? null : LEVELS[this.level(password)]);
  }

  level(password) {
    if (password.length < 8) return 0;
    if (COMMON_PASSWORDS.has(password.toLowerCase())) return 1;

    const hasRepeats = /(.)\1{2,}/.test(password);

    // A long passphrase with enough different characters is strong on its own
    if (password.length >= 20 && !hasRepeats && new Set(password).size >= 10)
      return 3;

    let points = 0;
    if (password.length >= 12) points++;
    if (password.length >= 16) points++;
    if (/[a-z]/.test(password) && /[A-Z]/.test(password)) points++;
    if (/\d/.test(password)) points++;
    if (/[^A-Za-z0-9]/.test(password)) points++;
    if (hasRepeats) points--;

    if (points >= 4) return 3;
    if (points >= 2) return 2;
    return 1;
  }

  render(level) {
    this.meterTarget.classList.remove(...BAR_CLASSES);
    this.labelTarget.classList.remove(...TEXT_CLASSES);

    if (!level) {
      this.meterTarget.value = 0;
      this.labelTarget.textContent = "";
      return;
    }

    this.meterTarget.value = level.value;
    this.meterTarget.classList.add(level.bar);
    this.labelTarget.classList.add(level.text);
    this.labelTarget.textContent = level.label;
  }
}
