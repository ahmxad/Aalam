document.addEventListener("turbo:load", () => {
  const titleInput = document.querySelector("#admin_topic_title")
  const availability = document.querySelector("#slug-availability")

  if (!titleInput || !availability) return

  let timeout

  titleInput.addEventListener("input", () => {
    clearTimeout(timeout)

    const title = titleInput.value.trim()

    if (!title) {
      availability.textContent = ""
      return
    }

    // The slug is made by stripping everything except Latin letters, digits and dashes,
    // so a title without any of those can never be saved.
    if (!/[a-z0-9]/i.test(title)) {
      availability.textContent =
        "Include at least one Latin letter or digit in the title"
      availability.className = "text-sm mt-2 text-error"
      return
    }

    availability.textContent = "Checking..."
    availability.className = "text-sm mt-2"

    timeout = setTimeout(async () => {
      const response = await fetch(
        `/admin/topics/check_slug?title=${encodeURIComponent(title)}`
      )

      const data = await response.json()

      if (data.available) {
        availability.textContent = "✓ Name is available"
        availability.className = "text-sm mt-2 text-success"
      } else {
        availability.textContent = "✗ A topic with this name already exists"
        availability.className = "text-sm mt-2 text-error"
      }
    }, 400)
  })
})