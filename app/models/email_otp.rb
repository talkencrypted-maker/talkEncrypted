class EmailOtp < ApplicationRecord
  belongs_to :invite_code, optional: true

  MAX_ATTEMPTS = 5

  def self.create_for(email, purpose:, invite_code: nil)
    raw_code = rand(100_000..999_999).to_s
    create!(
      email: email.downcase.strip,
      invite_code: invite_code,
      code_digest: Digest::SHA256.hexdigest(raw_code),
      purpose: purpose,
      expires_at: 10.minutes.from_now
    )
    raw_code
  end

  def self.find_pending_for(email)
    where(email: email.downcase.strip, consumed_at: nil)
      .where("expires_at > ?", Time.current)
      .order(created_at: :desc)
      .first
  end

 def verify!(raw_code)
  return false if consumed? || expired?

  if attempt_count >= MAX_ATTEMPTS
    return false
  end

  if Digest::SHA256.hexdigest(raw_code) == code_digest
    update!(consumed_at: Time.current)
    true
  else
    increment!(:attempt_count)
    false
  end
end


  def consumed?
    consumed_at.present?
  end

  def expired?
    expires_at <= Time.current
  end
end
