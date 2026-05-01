module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      raw_token = request.params[:token]
      return reject_unauthorized_connection if raw_token.blank?

      session = UserSession.find_by_raw_token(raw_token)
      return reject_unauthorized_connection unless session&.valid_session?

      session.touch(:last_used_at)
      session.user
    end
  end
end
