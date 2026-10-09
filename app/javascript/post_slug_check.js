document.addEventListener("turbo:load", () => {
  const titleInput = document.querySelector("#admin_post_title")
  const cardInput = document.querySelector("#admin_post_card_id")
  const availability = document.querySelector("#post-slug-availability")

  if (!titleInput || !cardInput || !availability) return

  let timeout

  const checkAvailability = () => {
    clearTimeout(timeout)

    const title = titleInput.value.trim()
    const cardId = cardInput.value

    if (!title || !cardId) {
      availability.replaceChildren()
      return
    }

    availability.textContent = "Checking..."
    availability.className = "text-sm mt-2"

    timeout = setTimeout(async () => {
      try {
        const response = await fetch(
          `/admin/posts/check_slug?title=${encodeURIComponent(title)}&card_id=${encodeURIComponent(cardId)}`
        )

        if (!response.ok) throw new Error("Request failed")

        const data = await response.json()

        // Purane response ko ignore karo agar inputs change ho chuke hon.
        if (
          title !== titleInput.value.trim() ||
          cardId !== cardInput.value
        ) return

        availability.replaceChildren()

        const status = document.createElement("p")
        status.className = data.available ? "text-success" : "text-error"
        status.textContent = data.available
          ? "✓ Name is available in this card"
          : "✗ A post with this title already exists in this card"

        availability.appendChild(status)

        if (data.available && data.existing_cards.length > 0) {
          const suggestion = document.createElement("p")
          suggestion.className = "text-sm mt-1 opacity-80"
          suggestion.textContent =
            `💡 This title already exists in: ${data.existing_cards.join(", ")}. You can still use it in this card.`

          availability.appendChild(suggestion)
        }
      } catch {
        availability.textContent = "Could not check availability"
        availability.className = "text-sm mt-2 text-error"
      }
    }, 400)
  }

  titleInput.addEventListener("input", checkAvailability)
  cardInput.addEventListener("change", checkAvailability)
})