import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage"

// Image manager for the post form.
//
// Chosen files are uploaded right away. Each image gets a row with an Insert button, which
// writes a Markdown reference at the cursor of the text field, and a Remove button.
// On save the form sends the complete list of images, so removing a row removes the image.
export default class extends Controller {
  static targets = ["input", "list", "template", "body", "message", "submit"]
  static values = { url: String, accept: Array, maxBytes: Number, limit: Number }

  connect() {
    this.pending = 0
  }

  select() {
    const files = Array.from(this.inputTarget.files)
    this.inputTarget.value = ""
    this.clearMessage()
    files.forEach((file) => this.upload(file))
  }

  insert(event) {
    const row = event.currentTarget.closest("[data-blob-id]")
    const alt = this.altTextFor(row.dataset.filename)
    this.insertAtCursor(`![${alt}](/images/${row.dataset.blobId})`)
  }

  remove(event) {
    event.currentTarget.closest("[data-blob-id]").remove()
  }

  upload(file) {
    const problem = this.problemWith(file)
    if (problem) {
      this.showMessage(problem)
      return
    }

    const row = this.buildRow(file)
    this.listTarget.append(row)
    this.setBusy(1)

    const upload = new DirectUpload(file, this.urlValue, {
      directUploadWillStoreFileWithXHR: (request) => {
        request.upload.addEventListener("progress", (event) => {
          if (event.lengthComputable) {
            this.setStatus(row, `Uploading ${Math.round((event.loaded / event.total) * 100)}%`)
          }
        })
      }
    })

    upload.create((error, blob) => {
      this.setBusy(-1)

      if (error) {
        row.remove()
        this.showMessage(`${file.name} could not be uploaded. Please try again.`)
      } else {
        this.finishRow(row, blob)
      }
    })
  }

  problemWith(file) {
    if (!this.acceptValue.includes(file.type)) {
      return `${file.name}: only JPEG, PNG or WebP images are allowed.`
    }
    if (file.size > this.maxBytesValue) {
      return `${file.name}: images must be smaller than ${Math.round(this.maxBytesValue / 1048576)} MB.`
    }
    if (this.listTarget.children.length >= this.limitValue) {
      return `A post can have at most ${this.limitValue} images.`
    }
    return null
  }

  buildRow(file) {
    const row = this.templateTarget.content.firstElementChild.cloneNode(true)
    row.dataset.filename = file.name
    row.querySelector("[data-role='name']").textContent = file.name
    this.setStatus(row, "Uploading 0%")
    row.querySelectorAll("button").forEach((button) => { button.disabled = true })
    return row
  }

  finishRow(row, blob) {
    row.dataset.blobId = blob.id
    row.querySelector("input[type='hidden']").value = blob.signed_id
    row.querySelector("img").src = `/rails/active_storage/blobs/redirect/${blob.signed_id}/${encodeURIComponent(blob.filename)}`
    row.querySelectorAll("button").forEach((button) => { button.disabled = false })
    this.setStatus(row, "")
  }

  insertAtCursor(markdown) {
    const field = this.bodyTarget
    const start = field.selectionStart ?? field.value.length
    const end = field.selectionEnd ?? start
    const before = field.value.slice(0, start)
    const after = field.value.slice(end)

    // Keep the image on its own paragraph
    const lead = before === "" || before.endsWith("\n\n") ? "" : before.endsWith("\n") ? "\n" : "\n\n"
    const trail = after === "" || after.startsWith("\n\n") ? "" : after.startsWith("\n") ? "\n" : "\n\n"

    field.setRangeText(`${lead}${markdown}${trail}`, start, end, "end")
    field.dispatchEvent(new Event("input", { bubbles: true }))
    field.focus()
  }

  // "my_photo-01.png" becomes "my photo 01", and brackets are removed so they cannot break the Markdown
  altTextFor(filename) {
    return filename
      .replace(/\.[^.]+$/, "")
      .replace(/[_-]+/g, " ")
      .replace(/[\[\]]/g, "")
      .trim()
  }

  setStatus(row, text) {
    row.querySelector("[data-role='status']").textContent = text
  }

  setBusy(change) {
    this.pending += change
    if (this.hasSubmitTarget) this.submitTarget.disabled = this.pending > 0
  }

  showMessage(text) {
    this.messageTarget.textContent = text
    this.messageTarget.classList.remove("hidden")
  }

  clearMessage() {
    this.messageTarget.textContent = ""
    this.messageTarget.classList.add("hidden")
  }
}