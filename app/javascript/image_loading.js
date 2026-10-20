// Gives every image a loading state, so the stylesheet can show a throbber in the image's
// place while it loads and an error box (with the alt text) if it fails.
//
//   data-load-state="loading"   the image is still being fetched
//   data-load-state="error"     the image could not be loaded
//   (no attribute)              the image is ready
const STATE = "data-load-state"
const ERROR_TEXT = "Loading error"

const markReady = (img) => {
  img.removeAttribute(STATE)

  // Put back the alt text that was replaced by the error message
  if (img.dataset.originalAlt !== undefined) {
    img.setAttribute("alt", img.dataset.originalAlt)
    delete img.dataset.originalAlt
  }
}

const markError = (img) => {
  if (img.dataset.originalAlt === undefined) img.dataset.originalAlt = img.getAttribute("alt") || ""

  const original = img.dataset.originalAlt
  img.setAttribute("alt", original ? `${ERROR_TEXT}: ${original}` : ERROR_TEXT)
  img.setAttribute(STATE, "error")
}

const inspect = (img) => {
  if (!img.getAttribute("src")) return

  if (img.complete) {
    // Already finished before this script ran: decode() fails only for a broken image
    img.decode().then(() => markReady(img), () => markError(img))
  } else {
    img.setAttribute(STATE, "loading")
  }
}

// load and error do not bubble, so they are caught on the way down (capture)
document.addEventListener("load", (event) => {
  if (event.target instanceof HTMLImageElement) markReady(event.target)
}, true)

document.addEventListener("error", (event) => {
  if (event.target instanceof HTMLImageElement) markError(event.target)
}, true)

document.addEventListener("turbo:load", () => {
  document.querySelectorAll("img").forEach(inspect)
})

// Turbo keeps a copy of each page for the back button, so store it without stale states
document.addEventListener("turbo:before-cache", () => {
  document.querySelectorAll(`img[${STATE}]`).forEach(markReady)
})