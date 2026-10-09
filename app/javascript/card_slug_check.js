
document.addEventListener("turbo:load", () => {
  const titleInput = document.querySelector("#admin_card_title")
  const topicInput = document.querySelector("#admin_card_topic_id")
  const availability = document.querySelector("#slug-availability")

  if (!titleInput || !topicInput || !availability) return

  let timeout

  const checkAvailability = () => {
    clearTimeout(timeout)

    const title = titleInput.value.trim()
    const topicId = topicInput.value

    if (!title || !topicId) {
      availability.replaceChildren()
      return
    }

    availability.textContent = "Checking..."
    availability.className = "text-sm mt-2"

    timeout = setTimeout(async () => {
      try {
        const response = await fetch(
          `/admin/cards/check_slug?title=${encodeURIComponent(title)}&topic_id=${encodeURIComponent(topicId)}`
        )

        const data = await response.json()

        // Ignore stale results if the user has changed the inputs.
        if (
          title !== titleInput.value.trim() ||
          topicId !== topicInput.value
        ) return

        availability.replaceChildren()

        const status = document.createElement("p")
        status.className = data.available
          ? "text-success"
          : "text-error"
        status.textContent = data.available
          ? "✓ Name is available in this topic"
          : "✗ A card with this name already exists in this topic"

        availability.appendChild(status)

        if (data.available && data.existing_topics.length > 0) {
          const suggestion = document.createElement("p")
          suggestion.className = "text-sm mt-1 opacity-80"
          suggestion.textContent =
            `💡 A card with this name already exists in: ${data.existing_topics.join(", ")}. You can still use this name here.`

          availability.appendChild(suggestion)
        }
      } catch {
        availability.textContent = "Could not check availability"
        availability.className = "text-sm mt-2 text-error"
      }
    }, 400)
  }

  titleInput.addEventListener("input", checkAvailability)
  topicInput.addEventListener("change", checkAvailability)
})