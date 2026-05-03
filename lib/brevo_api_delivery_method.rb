require "sib-api-v3-sdk"

class BrevoApiDeliveryMethod
  def initialize(settings)
    @api_key = settings[:api_key]
  end

  def deliver!(mail)
    SibApiV3Sdk.configure do |config|
      config.api_key["api-key"] = @api_key
    end

    api_instance = SibApiV3Sdk::TransactionalEmailsApi.new
    send_smtp_email = SibApiV3Sdk::SendSmtpEmail.new(build_payload(mail))
    api_instance.send_transac_email(send_smtp_email)
  end

  private

  def build_payload(mail)
    sender = { email: mail.from.first }
    from_name = mail[:from].display_names&.first
    sender[:name] = from_name if from_name

    payload = {
      sender: sender,
      to: mail.to.map { |email| { email: email } },
      subject: mail.subject
    }

    if mail.multipart?
      html = mail.html_part&.body&.to_s
      text = mail.text_part&.body&.to_s
      payload[:htmlContent] = html if html
      payload[:textContent] = text if text
    elsif mail.content_type&.start_with?("text/html")
      payload[:htmlContent] = mail.body.to_s
    else
      payload[:textContent] = mail.body.to_s
    end

    payload
  end
end
