# Converts JPEG and PNG pictures to WebP the moment they are assigned to an attachment.
# Use it after has_one_attached:
#
#   include WebpConvertible
#   has_one_attached :image
#   converts_to_webp :image
module WebpConvertible
  extend ActiveSupport::Concern

  class_methods do
    def converts_to_webp(name)
      define_method("#{name}=") do |attachable|
        super(WebpConverter.convert(attachable))
      end
    end
  end
end
