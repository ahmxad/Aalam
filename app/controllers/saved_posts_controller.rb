# The signed in user's own saved posts, newest save first. There is no way to ask for anyone else's.
class SavedPostsController < ApplicationController
  PER_PAGE = 10

  def index
    scope = Current.session.user.bookmarks.includes(post: { card: :topic }).order(id: :desc)
    scope = scope.where("bookmarks.id < ?", cursor) if cursor

    # One extra row is loaded, only to find out whether another page exists
    page = scope.limit(PER_PAGE + 1).to_a
    @bookmarks = page.first(PER_PAGE)
    @next_cursor = @bookmarks.last.id if page.size > PER_PAGE

    # A "Load more" request only needs the next batch
    render :page if cursor
  end

  private
    # The id of the last bookmark of the previous batch
    def cursor
      params[:cursor].to_s[/\A\d+\z/]&.to_i
    end
end
