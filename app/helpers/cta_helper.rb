module CtaHelper
  # A link styled as a call-to-action button
  def cta_link_to(label, path, size: nil, variant: nil, icon: true, **options)
    html_options = options.merge(class: cta_classes(size, variant, options[:class]))

    link_to(path, html_options) { cta_inner(label, icon) }
  end

  # A form button, used for DELETE and other non-GET actions
  def cta_button_to(label, path, size: nil, variant: nil, icon: true, **options)
    html_options = options.merge(class: cta_classes(size, variant, options[:class]))

    button_to(path, html_options) { cta_inner(label, icon) }
  end

  # A submit button for form builders: cta_submit(form, "Save")
  def cta_submit(form, label, size: nil, variant: nil, icon: false)
    form.button(type: "submit", class: cta_classes(size, variant)) { cta_inner(label, icon) }
  end

  private

  def cta_classes(size, variant, extra = nil)
    [ "cta-btn", ("cta-btn--#{size}" if size), ("cta-btn--#{variant}" if variant), extra ].compact.join(" ")
  end

  def cta_inner(label, icon)
    content_tag(:span, class: "cta-btn__surface") do
      content_tag(:span, class: "cta-btn__label") do
        parts = []
        if icon
          parts << content_tag(:span, "✧", class: "cta-btn__icon cta-btn__icon--default", "aria-hidden": true)
          parts << content_tag(:span, "✦", class: "cta-btn__icon cta-btn__icon--hover", "aria-hidden": true)
        end
        parts << label
        safe_join(parts)
      end
    end
  end
end
