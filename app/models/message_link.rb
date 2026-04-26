class MessageLink < ApplicationRecord
  belongs_to :message

  STATUSES = %w[pending fetched failed].freeze

  validates :url, presence: true
  validates :status, inclusion: { in: STATUSES }
end
