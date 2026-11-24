# A page only a signed-in user can open: the integration tests use it to tell a live session
# from a refused one.
class ProtectedController < ApplicationController
  before_action :authenticate_user!

  def show
    render plain: "signed in as #{current_user.email}"
  end
end
