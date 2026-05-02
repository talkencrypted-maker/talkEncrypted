class EmailOtp < ApplicationRecord
  belongs_to :invite_code, optional: true

  MAX_ATTEMPTS_PER_OTP = 5
  EMAIL_LOCKOUT_LIMIT  = 10
  EMAIL_LOCKOUT_WINDOW = 1.hour

  def self.create_for(email, purpose:, invite_code: nil)
    normalized_email = email.downcase.strip

    # Invalidate prior pending OTPs so an email never has two live codes
    # and so the email-level attempt total is meaningful.
    where(email: normalized_email, consumed_at: nil)
      .update_all(consumed_at: Time.current)

    raw_code = rand(100_000..999_999).to_s
    create!(
      email: normalized_email,
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

  def self.email_locked_out?(email)
    recent_failures_for(email) >= EMAIL_LOCKOUT_LIMIT
  end

  def self.attempts_remaining_for(email)
    [ EMAIL_LOCKOUT_LIMIT - recent_failures_for(email), 0 ].max
  end

  def self.recent_failures_for(email)
    where(email: email.downcase.strip)
      .where("created_at > ?", EMAIL_LOCKOUT_WINDOW.ago)
      .sum(:attempt_count)
  end

  # Returns: :ok | :invalid_code | :expired
  # Email-level lockout is checked by the controller before this is called.
  def verify(raw_code)
    return :expired if consumed? || expired?
    return :expired if attempt_count >= MAX_ATTEMPTS_PER_OTP

    if Digest::SHA256.hexdigest(raw_code) == code_digest
      update!(consumed_at: Time.current)
      :ok
    else
      increment!(:attempt_count)
      :invalid_code
    end
  end

  def consumed?
    consumed_at.present?
  end

  def expired?
    expires_at <= Time.current
  end
end
