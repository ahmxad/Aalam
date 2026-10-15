# One row per old slug of a record, so old public URLs can redirect to the new ones
class SlugHistory < ApplicationRecord
  belongs_to :sluggable, polymorphic: true
end
