import { Controller } from "@hotwired/stimulus"
import Lenis from "lenis"

// Smooth scrolling for public pages. Turned off for visitors who prefer reduced motion.
// Tune the feel in one place: a lower lerp is floatier, a higher lerp is snappier.
export default class extends Controller {
  connect() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return

    this.lenis = new Lenis({ lerp: 0.1, smoothWheel: true })

    const frame = (time) => {
      this.lenis.raf(time)
      this.frameId = requestAnimationFrame(frame)
    }
    this.frameId = requestAnimationFrame(frame)
  }

  // Runs when Turbo leaves the page, so nothing keeps running in the background
  disconnect() {
    cancelAnimationFrame(this.frameId)
    this.lenis?.destroy()
    this.lenis = null
  }
}