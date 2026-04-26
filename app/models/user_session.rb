class UserSession < ApplicationRecord
  belongs_to :user

  def self.create_for(user)
    raw_token = SecureRandom.hex(32)
    session = create!(
      user: user,
      token_digest: Digest::SHA256.hexdigest(raw_token),
      expires_at: 30.days.from_now
    )
    [ session, raw_token ]
  end

  def self.find_by_raw_token(raw_token)
    return nil if raw_token.blank?

    find_by(token_digest: Digest::SHA256.hexdigest(raw_token))
  end

  def valid_session?
    expires_at > Time.current
  end
end
