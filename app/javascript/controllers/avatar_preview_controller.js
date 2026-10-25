import { Controller } from "@hotwired/stimulus";

const ALLOWED_TYPES = ["image/jpeg", "image/png", "image/webp"];

// Previews the chosen profile picture and explains problems before the form is submitted.
// The server checks and converts the file again.
export default class extends Controller {
  static targets = ["input", "image", "placeholder", "hint"];
  static values = { maxSize: { type: Number, default: 10 * 1024 * 1024 } };

  connect() {
    this.defaultHint = this.hintTarget.textContent;
  }

  disconnect() {
    this.releasePreview();
  }

  select() {
    const file = this.inputTarget.files[0];
    this.releasePreview();

    if (!file) return this.reset();

    if (!ALLOWED_TYPES.includes(file.type)) {
      return this.reject(
        `${file.name} is not supported. Choose a JPEG, PNG or WebP picture.`,
      );
    }
    if (file.size > this.maxSizeValue) {
      return this.reject(
        `${file.name} is ${this.formatSize(file.size)}. Pictures must be smaller than ${this.formatSize(this.maxSizeValue)}.`,
      );
    }

    this.previewUrl = URL.createObjectURL(file);
    this.showPreview(this.previewUrl);
    this.showHint(
      `${file.name} (${this.formatSize(file.size)}) will be converted to WebP automatically.`,
      false,
    );
  }

  reject(message) {
    this.inputTarget.value = "";
    this.hidePreview();
    this.showHint(message, true);
  }

  reset() {
    this.hidePreview();
    this.showHint(this.defaultHint, false);
  }

  showPreview(url) {
    if (!this.hasImageTarget) return;

    this.imageTarget.src = url;
    this.imageTarget.hidden = false;
    if (this.hasPlaceholderTarget) this.placeholderTarget.hidden = true;
  }

  hidePreview() {
    if (!this.hasImageTarget) return;

    this.imageTarget.removeAttribute("src");
    this.imageTarget.hidden = true;
    if (this.hasPlaceholderTarget) this.placeholderTarget.hidden = false;
  }

  releasePreview() {
    if (this.previewUrl) URL.revokeObjectURL(this.previewUrl);
    this.previewUrl = null;
  }

  showHint(message, isError) {
    this.hintTarget.textContent = message;
    this.hintTarget.classList.toggle("text-error", isError);
    this.hintTarget.classList.toggle("font-medium", isError);
    this.hintTarget.classList.toggle("opacity-70", !isError);
    this.inputTarget.classList.toggle("file-input-error", isError);
  }

  formatSize(bytes) {
    if (bytes >= 1024 * 1024) return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
    return `${Math.round(bytes / 1024)} KB`;
  }
}
