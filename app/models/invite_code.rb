class InviteCode < ApplicationRecord
  belongs_to :used_by_user, class_name: "User", optional: true

  validates :code_digest, presence: true, uniqueness: true

  def self.find_valid_by_raw_code(raw_code)
    return nil if raw_code.blank?

    digest = Digest::SHA256.hexdigest(raw_code.strip)
    where(code_digest: digest, used_at: nil)
      .where("expires_at IS NULL OR expires_at > ?", Time.current)
      .first
  end

  def consume!(user)
    return if reusable?
    update!(used_by_user: user, used_at: Time.current)
  end

  def available?
    used_at.nil? && (expires_at.nil? || expires_at > Time.current)
  end
end
