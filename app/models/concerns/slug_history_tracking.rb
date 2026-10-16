# Remembers the old slugs of a record, so old public URLs can redirect to the current one.
#
# A model overrides .slug_scope_attribute when its slug is only unique inside a parent
# (for example a card's slug is unique inside its topic).
module SlugHistoryTracking
  extend ActiveSupport::Concern

  included do
    has_many :slug_histories, as: :sluggable, dependent: :destroy

    after_update :record_slug_history, if: :slug_location_changed?
  end

  class_methods do
    # The attribute that scopes the slug, or nil when the slug is unique on its own
    def slug_scope_attribute
      nil
    end

    # Finds a record by its current slug, falling back to old slugs.
    # Returns [record, found_by_old_slug]; the record is nil when nothing matches.
    def find_by_slug_or_history(slug, scope_id: nil)
      conditions = { slug: slug }
      conditions[slug_scope_attribute] = scope_id if slug_scope_attribute

      current = find_by(conditions)
      return [ current, false ] if current

      old = SlugHistory.where(sluggable_type: base_class.name, slug: slug, scope_id: scope_id)
                       .order(created_at: :desc, id: :desc)
                       .first
      [ old&.sluggable, old.present? ]
    end
  end

  private

  def slug_scope_value(old: false)
    attribute = self.class.slug_scope_attribute
    return nil unless attribute

    old ? public_send("#{attribute}_before_last_save") : public_send(attribute)
  end

  # The public URL changes when the slug changes, or when the record moves to another parent
  def slug_location_changed?
    attribute = self.class.slug_scope_attribute
    saved_change_to_slug? || (attribute.present? && saved_change_to_attribute?(attribute))
  end

  def record_slug_history
    old_slug = slug_before_last_save
    return if old_slug.blank?

    slug_histories.find_or_create_by!(slug: old_slug, scope_id: slug_scope_value(old: true))
    # A record never needs a redirect to itself
    slug_histories.where(slug: slug, scope_id: slug_scope_value).destroy_all
  end
end
