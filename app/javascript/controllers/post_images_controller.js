import { Controller } from "@hotwired/stimulus";
import { DirectUpload } from "@rails/activestorage";

// Pictures are converted to WebP in the browser before they are uploaded
const CONVERTIBLE_TYPES = ["image/jpeg", "image/png"];
const MAX_DIMENSION = 2400;
const JPEG_QUALITY = 0.9;

// Image manager for the post form.
//
// Chosen files are uploaded right away. Each image gets a row with an Insert button, which
// writes a Markdown reference at the cursor of the text field, and a Remove button.
// On save the form sends the complete list of images, so removing a row removes the image.
export default class extends Controller {
  static targets = ["input", "list", "template", "body", "message", "submit"];
  static values = {
    url: String,
    accept: Array,
    maxBytes: Number,
    limit: Number,
  };

  connect() {
    this.pending = 0;
  }

  select() {
    const files = Array.from(this.inputTarget.files);
    this.inputTarget.value = "";
    this.clearMessage();
    files.forEach((file) => this.upload(file));
  }

  insert(event) {
    const row = event.currentTarget.closest("[data-blob-id]");
    const alt = this.altTextFor(row.dataset.filename);
    this.insertAtCursor(`![${alt}](/images/${row.dataset.blobId})`);
  }

  remove(event) {
    event.currentTarget.closest("[data-blob-id]").remove();
  }

  async upload(file) {
    const problem = this.problemWith(file);
    if (problem) {
      this.showMessage(problem);
      return;
    }

    // The row is added before the conversion starts, so the image limit is counted correctly
    const row = this.buildRow(file);
    this.listTarget.append(row);
    this.setBusy(1);

    this.setStatus(row, "Converting to WebP");
    const prepared = await this.convertToWebp(file);
    this.renameRow(row, prepared.name);
    this.setStatus(row, "Uploading 0%");

    const upload = new DirectUpload(prepared, this.urlValue, {
      directUploadWillStoreFileWithXHR: (request) => {
        request.upload.addEventListener("progress", (event) => {
          if (event.lengthComputable) {
            this.setStatus(
              row,
              `Uploading ${Math.round((event.loaded / event.total) * 100)}%`,
            );
          }
        });
      },
    });

    upload.create((error, blob) => {
      this.setBusy(-1);

      if (error) {
        row.remove();
        this.showMessage(
          `${file.name} could not be uploaded. Please try again.`,
        );
      } else {
        this.finishRow(row, blob);
      }
    });
  }

  problemWith(file) {
    if (!this.acceptValue.includes(file.type)) {
      return `${file.name}: only JPEG, PNG or WebP images are allowed.`;
    }
    if (file.size > this.maxBytesValue) {
      return `${file.name}: images must be smaller than ${Math.round(this.maxBytesValue / 1048576)} MB.`;
    }
    if (this.listTarget.children.length >= this.limitValue) {
      return `A post can have at most ${this.limitValue} images.`;
    }
    return null;
  }

  buildRow(file) {
    const row = this.templateTarget.content.firstElementChild.cloneNode(true);
    row.dataset.filename = file.name;
    row.querySelector("[data-role='name']").textContent = file.name;
    this.setStatus(row, "Uploading 0%");
    row.querySelectorAll("button").forEach((button) => {
      button.disabled = true;
    });
    return row;
  }

  // Returns a WebP copy of a JPEG or PNG. If the browser cannot make one, the original file is used.
  async convertToWebp(file) {
    if (!CONVERTIBLE_TYPES.includes(file.type)) return file;

    try {
      const bitmap = await createImageBitmap(file, {
        imageOrientation: "from-image",
      });
      const scale = Math.min(
        1,
        MAX_DIMENSION / Math.max(bitmap.width, bitmap.height),
      );
      const canvas = document.createElement("canvas");
      canvas.width = Math.round(bitmap.width * scale);
      canvas.height = Math.round(bitmap.height * scale);
      canvas
        .getContext("2d")
        .drawImage(bitmap, 0, 0, canvas.width, canvas.height);
      bitmap.close();

      // Quality 1 gives a lossless WebP in Chromium browsers, which keeps screenshots sharp
      const quality = file.type === "image/png" ? 1 : JPEG_QUALITY;
      const blob = await new Promise((resolve) =>
        canvas.toBlob(resolve, "image/webp", quality),
      );
      if (!blob || blob.type !== "image/webp") return file;

      const name = file.name.replace(/\.[^.]+$/, "") + ".webp";
      return new File([blob], name, { type: "image/webp" });
    } catch {
      return file;
    }
  }

  renameRow(row, name) {
    row.dataset.filename = name;
    row.querySelector("[data-role='name']").textContent = name;
  }

  finishRow(row, blob) {
    row.dataset.blobId = blob.id;
    row.querySelector("input[type='hidden']").value = blob.signed_id;
    row.querySelector("img").src =
      `/rails/active_storage/blobs/redirect/${blob.signed_id}/${encodeURIComponent(blob.filename)}`;
    row.querySelectorAll("button").forEach((button) => {
      button.disabled = false;
    });
    this.setStatus(row, "");
  }

  insertAtCursor(markdown) {
    const field = this.bodyTarget;
    const start = field.selectionStart ?? field.value.length;
    const end = field.selectionEnd ?? start;
    const before = field.value.slice(0, start);
    const after = field.value.slice(end);

    // Keep the image on its own paragraph
    const lead =
      before === "" || before.endsWith("\n\n")
        ? ""
        : before.endsWith("\n")
          ? "\n"
          : "\n\n";
    const trail =
      after === "" || after.startsWith("\n\n")
        ? ""
        : after.startsWith("\n")
          ? "\n"
          : "\n\n";

    field.setRangeText(`${lead}${markdown}${trail}`, start, end, "end");
    field.dispatchEvent(new Event("input", { bubbles: true }));
    field.focus();
  }

  // "my_photo-01.png" becomes "my photo 01", and brackets are removed so they cannot break the Markdown
  altTextFor(filename) {
    return filename
      .replace(/\.[^.]+$/, "")
      .replace(/[_-]+/g, " ")
      .replace(/[\[\]]/g, "")
      .trim();
  }

  setStatus(row, text) {
    row.querySelector("[data-role='status']").textContent = text;
  }

  setBusy(change) {
    this.pending += change;
    if (this.hasSubmitTarget) this.submitTarget.disabled = this.pending > 0;
  }

  showMessage(text) {
    this.messageTarget.textContent = text;
    this.messageTarget.classList.remove("hidden");
  }

  clearMessage() {
    this.messageTarget.textContent = "";
    this.messageTarget.classList.add("hidden");
  }
}
