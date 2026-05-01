class User < ApplicationRecord
  has_many :user_sessions, dependent: :destroy
  has_many :conversation_members, dependent: :destroy
  has_many :conversations, through: :conversation_members
  has_many :sent_messages, class_name: "Message", foreign_key: :sender_id, dependent: :destroy

  validates :email, presence: true, uniqueness: { case_sensitive: false }

  before_save :set_profile_completed_at

  def profile_completed?
    profile_completed_at?
  end

  private

  def set_profile_completed_at
    if display_name.present? && profile_completed_at.nil?
      self.profile_completed_at = Time.current
    end
  end
end
