class Message < ApplicationRecord
  belongs_to :conversation
  belongs_to :sender, class_name: "User"
  has_many :message_links, dependent: :destroy

  validates :body, presence: true

  after_create :extract_links

  private

  def extract_links
    urls = URI.extract(body, %w[http https]).uniq
    urls.each do |url|
      domain = URI.parse(url).host
      link = message_links.create!(url: url, domain: domain, status: "pending")
      FetchLinkPreviewJob.perform_later(link.id)
    end
  end
end
