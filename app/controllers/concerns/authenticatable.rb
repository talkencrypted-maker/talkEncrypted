module Authenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate!
  end

  private

  def authenticate!
    token = extract_bearer_token
    return render_unauthorized if token.nil?

    session_record = UserSession.find_by_raw_token(token)
    return render_unauthorized if session_record.nil? || !session_record.valid_session?

    session_record.touch(:last_used_at)
    @current_user = session_record.user
    @current_session = session_record
  end

  def current_user
    @current_user
  end

  def current_session
    @current_session
  end

  def extract_bearer_token
    auth_header = request.headers["Authorization"]
    return nil unless auth_header&.start_with?("Bearer ")

    auth_header.split(" ", 2).last
  end

  def render_unauthorized
    render json: {
      error: {
        code: "unauthorized",
        message: "Authentication is required."
      }
    }, status: :unauthorized
  end

  def render_forbidden
    render json: {
      error: {
        code: "forbidden",
        message: "Access denied."
      }
    }, status: :forbidden
  end

  def render_not_found
    render json: {
      error: {
        code: "not_found",
        message: "Resource not found."
      }
    }, status: :not_found
  end
end
