class Conversation < ApplicationRecord
  has_many :conversation_members, dependent: :destroy
  has_many :users, through: :conversation_members
  has_many :messages, dependent: :destroy

  validates :kind, inclusion: { in: %w[direct] }

  def self.direct_between(user_a, user_b)
    joins(:conversation_members)
      .where(kind: "direct", conversation_members: { user_id: user_a.id })
      .joins("INNER JOIN conversation_members cm2 ON cm2.conversation_id = conversations.id AND cm2.user_id = #{user_b.id.to_i}")
      .first
  end

  def recipient_for(current_user)
    users.where.not(id: current_user.id).first
  end

  def last_message
    messages.order(created_at: :desc).first
  end
end
