import { Controller } from "@hotwired/stimulus"

const WIDE_SCREEN = "(min-width: 64rem)"
const COOKIE = "sidebar"
const ONE_YEAR = 60 * 60 * 24 * 365

// Controls the topics sidebar. The sidebar lives in the layout and is kept across Turbo visits
// (data-turbo-permanent), so nothing re-renders it when the page changes. This controller does that work:
//
// - Open and close: on a wide screen the choice is saved in a cookie, so the server renders the same state
//   on the next full page load. On a narrow screen the sidebar is a drawer, which is never saved.
// - Dropdowns: each topic has a button that shows or hides its cards. Only the topic of the current page
//   stays open, the others close whenever another topic or card is chosen.
// - Current page: marks the link of the page being viewed (aria-current). A click marks its link at once,
//   without waiting for the next page to load.
// - Navbar height: measures the floating navbar so the sidebar can stick right below it.
export default class extends Controller {
  static targets = ["panel", "toggle"]

  connect() {
    this.root = document.documentElement
    this.header = document.getElementById("site-header")

    this.listeners = {
      "turbo:visit": () => this.closeDrawer(),
      "turbo:load": () => this.markCurrent(),
      keydown: (event) => { if (event.key === "Escape") this.closeDrawer() }
    }
    Object.entries(this.listeners).forEach(([name, listener]) => document.addEventListener(name, listener))

    this.handleResize = () => {
      if (this.isWide) delete this.root.dataset.sidebarDrawer
      this.syncButtons()
      this.measureHeader()
    }
    window.addEventListener("resize", this.handleResize)

    if (this.header && "ResizeObserver" in window) {
      this.headerObserver = new ResizeObserver(() => this.measureHeader())
      this.headerObserver.observe(this.header)
    }

    this.measureHeader()
    this.syncButtons()
    this.markCurrent()
  }

  disconnect() {
    Object.entries(this.listeners).forEach(([name, listener]) => document.removeEventListener(name, listener))
    window.removeEventListener("resize", this.handleResize)
    this.headerObserver?.disconnect()
  }

  // Opens or closes the whole sidebar
  toggle() {
    if (this.isWide) {
      this.saveWideState(!this.isOpen)
    } else if (this.isOpen) {
      delete this.root.dataset.sidebarDrawer
    } else {
      this.root.dataset.sidebarDrawer = "open"
    }

    this.syncButtons()
    if (this.isOpen) this.markCurrent()
  }

  closeDrawer() {
    delete this.root.dataset.sidebarDrawer
    this.syncButtons()
  }

  // The button next to a topic shows or hides the cards of that topic
  toggleGroup(event) {
    const button = event.currentTarget
    this.setGroup(button, button.getAttribute("aria-expanded") !== "true")
  }

  // A click on a topic or card marks it at once and closes the dropdown of the previous one.
  // The click itself goes on, and Turbo loads the page.
  select(event) {
    const plainClick = event.button === 0 && !(event.metaKey || event.ctrlKey || event.shiftKey || event.altKey)
    if (event.defaultPrevented || !plainClick) return

    const link = event.target.closest(".sidebar__link, .sidebar__card")
    if (link && this.panelTarget.contains(link)) this.markLink(link)
  }

  setGroup(button, expanded) {
    button.setAttribute("aria-expanded", String(expanded))

    const list = document.getElementById(button.getAttribute("aria-controls"))
    if (list) list.hidden = !expanded
  }

  // The topic and card links of the sidebar
  get links() {
    return this.hasPanelTarget ? Array.from(this.panelTarget.querySelectorAll(".sidebar__link, .sidebar__card")) : []
  }

  // Marks the link of the page being viewed. A post page marks its card, because posts are not in the sidebar.
  markCurrent() {
    const path = this.normalize(location.pathname)
    let best = null

    for (const link of this.links) {
      const href = this.normalize(new URL(link.href).pathname)
      const matches = path === href || path.startsWith(`${href}/`)
      if (matches && (!best || href.length > best.href.length)) best = { link, href }
    }

    this.markLink(best ? best.link : null)
  }

  // Makes one link current (or none), and leaves only its topic open
  markLink(link) {
    this.links.forEach((other) => other.removeAttribute("aria-current"))
    link?.setAttribute("aria-current", "page")

    const current = link?.closest(".sidebar__group")
    this.panelTarget.querySelectorAll(".sidebar__group").forEach((group) => {
      const button = group.querySelector(".sidebar__toggle")
      if (button) this.setGroup(button, group === current)
    })

    if (link) this.scrollIntoSidebarView(link)
  }

  // Scrolls only the sidebar list, never the page itself
  scrollIntoSidebarView(link) {
    const scroller = this.panelTarget.querySelector(".sidebar__scroll")
    if (!scroller || scroller.clientHeight === 0) return

    const area = scroller.getBoundingClientRect()
    const rect = link.getBoundingClientRect()

    if (rect.top < area.top) {
      scroller.scrollTop -= area.top - rect.top + 8
    } else if (rect.bottom > area.bottom) {
      scroller.scrollTop += rect.bottom - area.bottom + 8
    }
  }

  // Remembers the choice on a wide screen, in a cookie the server can read
  saveWideState(open) {
    const value = open ? "open" : "closed"
    const secure = location.protocol === "https:" ? "; secure" : ""

    this.root.dataset.sidebar = value
    document.cookie = `${COOKIE}=${value}; path=/; max-age=${ONE_YEAR}; samesite=lax${secure}`
  }

  syncButtons() {
    this.toggleTargets.forEach((button) => button.setAttribute("aria-expanded", String(this.isOpen)))
  }

  // The stylesheet places the sidebar below the navbar using this number
  measureHeader() {
    if (this.header) this.root.style.setProperty("--navbar-height", `${this.header.offsetHeight}px`)
  }

  normalize(path) {
    return path.replace(/\/+$/, "") || "/"
  }

  get isWide() {
    return window.matchMedia(WIDE_SCREEN).matches
  }

  // Read from the state the stylesheet works with, not from what is on screen, because the sidebar
  // is still visible for a moment while it closes
  get isOpen() {
    if (this.isWide) return this.root.dataset.sidebar !== "closed"
    return this.root.dataset.sidebarDrawer === "open"
  }
}