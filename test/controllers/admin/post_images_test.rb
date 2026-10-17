require "test_helper"

class Admin::PostImagesTest < ActionDispatch::IntegrationTest
  setup do
    admin = User.create!(email_address: "images-admin@test.com", password: "password123!", admin: true)
    sign_in_as(admin)
    @card = admin_cards(:one)
  end

  def uploaded_blob(name = "photo.png")
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(File.binread(Rails.root.join("test/fixtures/files/test.png"))),
      filename: name,
      content_type: "image/png"
    )
  end

  # The form always sends the complete list of images the post should have afterwards,
  # because assigning images replaces everything that is not in the list.

  test "creating a post attaches the uploaded images" do
    blob = uploaded_blob

    assert_difference("Admin::Post.count", 1) do
      post admin_posts_url, params: {
        admin_post: {
          card_id: @card.id, title: "Illustrated", summary: "A summary",
          body: "![x](/images/#{blob.id})", images: [ "", blob.signed_id ]
        }
      }
    end

    assert_equal [ blob.id ], Admin::Post.find_by!(title: "Illustrated").images.blobs.map(&:id)
  end

  test "sending the full list keeps the old images and adds the new one" do
    post_record = admin_posts(:one)
    first = uploaded_blob("first.png")
    post_record.images.attach(first)
    second = uploaded_blob("second.png")

    patch admin_post_url(post_record), params: {
      admin_post: { title: post_record.title, images: [ "", first.signed_id, second.signed_id ] }
    }

    assert_equal [ first.id, second.id ].sort, post_record.reload.images.blobs.map(&:id).sort
  end

  test "an image left out of the list is removed" do
    post_record = admin_posts(:one)
    first = uploaded_blob("first.png")
    second = uploaded_blob("second.png")
    post_record.images.attach(first, second)

    patch admin_post_url(post_record), params: {
      admin_post: { title: post_record.title, images: [ "", second.signed_id ] }
    }

    assert_equal [ second.id ], post_record.reload.images.blobs.map(&:id)
  end

  test "an empty list removes every image" do
    post_record = admin_posts(:one)
    post_record.images.attach(uploaded_blob)

    patch admin_post_url(post_record), params: {
      admin_post: { title: post_record.title, images: [ "" ] }
    }

    assert_equal 0, post_record.reload.images.count
  end

  test "an update that does not mention images leaves them alone" do
    post_record = admin_posts(:one)
    post_record.images.attach(uploaded_blob)

    patch admin_post_url(post_record), params: { admin_post: { title: post_record.title } }

    assert_equal 1, post_record.reload.images.count
  end

  test "the post page shows an uploaded image where the body places it" do
    blob = uploaded_blob
    post_record = Admin::Post.create!(
      card: @card, title: "With a picture", summary: "A summary",
      body: "Before\n\n![A picture](/images/#{blob.id})\n\nAfter"
    )
    post_record.images.attach(blob)

    get topic_card_post_path(@card.topic.slug, @card.slug, post_record.slug)

    assert_response :success
    assert_select ".article-body img[src^='/rails/active_storage/representations']", count: 1
  end
    test "the new post form has the image manager" do
    get new_admin_post_url

    assert_response :success
    assert_select "form[data-controller~='post-images']"
    assert_select "input[type='hidden'][name='admin_post[images][]'][value='']"
    assert_select "input[type='file'][multiple]:not([name])"
  end

  test "the edit form lists the images the post already has" do
    post_record = admin_posts(:one)
    blob = uploaded_blob("existing.png")
    post_record.images.attach(blob)

    get edit_admin_post_url(post_record)

    assert_select "[data-blob-id='#{blob.id}'] input[name='admin_post[images][]'][value='#{blob.signed_id}']"
  end
end
