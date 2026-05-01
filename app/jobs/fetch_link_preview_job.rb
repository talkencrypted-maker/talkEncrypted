require "net/http"

class FetchLinkPreviewJob < ApplicationJob
  queue_as :default

  def perform(link_id)
    link = MessageLink.find_by(id: link_id)
    return unless link

    uri = URI.parse(link.url)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 10) do |http|
      http.get(uri.request_uri, "User-Agent" => "TalkEncrypted/1.0")
    end

    if response.is_a?(Net::HTTPSuccess)
      html = response.body.force_encoding("UTF-8").encode("UTF-8", invalid: :replace, undef: :replace)
      title = html.match(/<title[^>]*>([^<]+)<\/title>/i)&.captures&.first&.strip&.slice(0, 255)
      description = html.match(/<meta[^>]+name=["']description["'][^>]+content=["']([^"']+)["']/i)&.captures&.first&.strip ||
                    html.match(/<meta[^>]+content=["']([^"']+)["'][^>]+name=["']description["']/i)&.captures&.first&.strip
      description = description&.slice(0, 500)

      link.update!(title: title, description: description, status: "fetched", fetched_at: Time.current)
    else
      link.update!(status: "failed")
    end

    ActionCable.server.broadcast(
      "conversation_#{link.message.conversation_id}",
      {
        type: "link_preview.updated",
        conversation_id: link.message.conversation_id,
        message_id: link.message_id,
        link_id: link.id,
        status: link.status,
        updated_at: Time.current.iso8601
      }
    )
  rescue => e
    Rails.logger.error "[FetchLinkPreviewJob] Failed for link #{link_id}: #{e.message}"
    link&.update!(status: "failed")
  end
end
