class Api::SessionsController < ApplicationController
  include Authenticatable

  def destroy
    current_session.destroy
    render json: { message: "Logged out." }
  end
end
