// Shows the loading indicator when a Turbo visit takes longer than a short delay,
// so fast navigation never flashes it. The indicator itself is the .throbber element
// in the layout, which the stylesheet shows while <html> has the is-loading class.
const SHOW_AFTER_MS = 250

let timer = null

const show = () => document.documentElement.classList.add("is-loading")

const hide = () => {
  clearTimeout(timer)
  timer = null
  document.documentElement.classList.remove("is-loading")
}

document.addEventListener("turbo:visit", () => {
  hide()
  timer = setTimeout(show, SHOW_AFTER_MS)
})

// The next page has arrived (or the visit failed), so stop waiting
;["turbo:before-render", "turbo:load", "turbo:before-cache", "turbo:fetch-request-error"].forEach((name) => {
  document.addEventListener(name, hide)
})