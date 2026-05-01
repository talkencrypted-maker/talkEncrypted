class ApplicationController < ActionController::API
  private

  def render_error(code:, message:, status:)
    render json: { error: { code: code, message: message } }, status: status
  end
end
