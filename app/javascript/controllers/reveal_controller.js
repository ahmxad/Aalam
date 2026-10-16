import { Controller } from "@hotwired/stimulus"
import { gsap } from "gsap"

// Fades and lifts the children marked with data-reveal-item, one after another.
//
//   data-controller="reveal"                      reveal each item when it scrolls into view
//   data-reveal-trigger-value="load"              reveal right away (for hero areas)
//   data-reveal-stagger-value="0.08"              seconds between items
//   data-reveal-distance-value="24"               pixels the items travel
//
// Visitors who prefer reduced motion see everything immediately.
export default class extends Controller {
  static values = {
    trigger: { type: String, default: "scroll" },
    stagger: { type: Number, default: 0.08 },
    distance: { type: Number, default: 24 },
    delay: { type: Number, default: 0.15 }
  }

  connect() {
    this.items = Array.from(this.element.querySelectorAll("[data-reveal-item]"))
    if (this.items.length === 0) return
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return

    // A CSS transition on transform would fight with the animation, so pause it
    this.items.forEach((item) => { item.style.transition = "none" })
    gsap.set(this.items, { opacity: 0, y: this.distanceValue })

    if (this.triggerValue === "load") {
      this.play(this.items, this.delayValue)
    } else {
      this.observe()
    }
  }

  // Runs when Turbo leaves the page
  disconnect() {
    this.observer?.disconnect()
    if (!this.items?.length) return

    gsap.killTweensOf(this.items)
    gsap.set(this.items, { clearProps: "opacity,transform" })
    this.items.forEach((item) => item.style.removeProperty("transition"))
  }

  observe() {
    this.observer = new IntersectionObserver((entries) => {
      const visible = entries.filter((entry) => entry.isIntersecting).map((entry) => entry.target)
      if (visible.length === 0) return

      visible.forEach((item) => this.observer.unobserve(item))
      // Items that appear together are staggered as one group
      this.play(visible, 0)
    }, { rootMargin: "0px 0px -8% 0px", threshold: 0.1 })

    this.items.forEach((item) => this.observer.observe(item))
  }

  play(targets, delay) {
    gsap.to(targets, {
      opacity: 1,
      y: 0,
      delay,
      duration: 0.7,
      ease: "power3.out",
      stagger: this.staggerValue,
      // Remove the inline styles, so hover effects work normally afterwards
      clearProps: "opacity,transform",
      onComplete: () => targets.forEach((item) => item.style.removeProperty("transition"))
    })
  }
}