import { Controller } from "@hotwired/stimulus"

// Adds a "Copy" button to every code block inside the element.
// The buttons use a Stimulus action attribute, so they keep working when Turbo restores a cached page.
export default class extends Controller {
  static values = { label: { type: String, default: "Copy" } }

  connect() {
    this.element.querySelectorAll("pre").forEach((pre) => {
      if (pre.parentElement.classList.contains("code-block")) return

      const wrapper = document.createElement("div")
      wrapper.className = "code-block"
      pre.replaceWith(wrapper)
      wrapper.append(pre, this.buildButton())
    })
  }

  disconnect() {
    clearTimeout(this.resetTimer)
  }

  async copy(event) {
    const button = event.currentTarget
    const code = button.closest(".code-block").querySelector("pre").textContent.replace(/\n$/, "")

    try {
      await navigator.clipboard.writeText(code)
      this.flash(button, "Copied")
    } catch {
      this.flash(button, "Failed")
    }
  }

  buildButton() {
    const button = document.createElement("button")
    button.type = "button"
    button.className = "code-block__copy"
    button.textContent = this.labelValue
    button.setAttribute("aria-label", "Copy code to clipboard")
    button.dataset.action = "code-copy#copy"
    return button
  }

  flash(button, text) {
    button.textContent = text
    clearTimeout(this.resetTimer)
    this.resetTimer = setTimeout(() => { button.textContent = this.labelValue }, 1500)
  }
}