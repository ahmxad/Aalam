import { gsap } from "gsap"

// Page transition for Turbo navigation. The marked area fades out before the next page
// renders and fades in after it, while the navbar and footer stay in place.
// Tune the feel here, or mark a different area with data-page-transition in the layout.
const TARGET = "[data-page-transition]"
const FADE_OUT = { duration: 0.22, ease: "power2.in" }
const FADE_IN = { duration: 0.4, ease: "power2.out" }
const OFFSET = 14 // pixels the content travels

const prefersReducedMotion = () => window.matchMedia("(prefers-reduced-motion: reduce)").matches

// Resolves when the fade out of the current visit has finished
let leaving = null

document.addEventListener("turbo:visit", () => {
  const current = document.querySelector(TARGET)
  if (!current || prefersReducedMotion()) {
    leaving = null
    return
  }

  gsap.killTweensOf(current)
  leaving = new Promise((resolve) => {
    gsap.to(current, { opacity: 0, y: -OFFSET, ...FADE_OUT, onComplete: resolve })
  })
})

// Pause rendering until the fade out is done
document.addEventListener("turbo:before-render", async (event) => {
  if (!leaving) return
  event.preventDefault()

  // Hide the incoming content before it appears, so it never flashes
  const incoming = event.detail.newBody.querySelector(TARGET)
  if (incoming) gsap.set(incoming, { opacity: 0, y: OFFSET })

  await leaving
  event.detail.resume()
})

document.addEventListener("turbo:render", () => {
  if (!leaving) return
  leaving = null

  const target = document.querySelector(TARGET)
  if (!target) return

  // clearProps removes the leftover inline styles, so no transform stays on the page
  gsap.fromTo(
    target,
    { opacity: 0, y: OFFSET },
    { opacity: 1, y: 0, ...FADE_IN, clearProps: "opacity,transform" }
  )
})