import { Controller } from "@hotwired/stimulus"

// Fills the post text from a Markdown file chosen on the admin's computer.
// The file is only read in the browser. Nothing is uploaded or stored: its text goes into the form field.
export default class extends Controller {
  static targets = ["input", "body", "message"]
  static values = { maxChars: Number }

  async load() {
    const file = this.inputTarget.files[0]
    this.inputTarget.value = ""
    this.clearMessage()
    if (!file) return

    if (!/\.(md|markdown)$/i.test(file.name)) {
      return this.showMessage(`${file.name}: please choose a .md or .markdown file.`)
    }

    // A character takes at most 4 bytes, so a bigger file can never fit under the limit
    if (file.size > this.maxCharsValue * 4) {
      return this.showMessage(`${file.name} is too large.`)
    }

    const text = (await file.text()).replace(/^\uFEFF/, "").replace(/\r\n?/g, "\n")
    if (text.length > this.maxCharsValue) {
      return this.showMessage(`${file.name} is too long (limit ${this.maxCharsValue} characters).`)
    }

    const current = this.bodyTarget.value.trim()
    if (current !== "" && !window.confirm("Replace the current text with the contents of this file?")) return

    this.bodyTarget.value = text
    this.bodyTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.warnAboutOutsideImages(text)
  }

  // Images are only shown when they were uploaded in the Images section of this form
  warnAboutOutsideImages(text) {
    const outside = text.match(/!\[[^\]]*\]\((?!\/images\/\d+\))[^)]*\)/g) || []
    if (outside.length === 0) return

    this.showMessage(
      `${outside.length} image reference(s) in this file do not point to images uploaded here, so they will not be shown. ` +
      "Upload those images in the Images section and press Insert."
    )
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