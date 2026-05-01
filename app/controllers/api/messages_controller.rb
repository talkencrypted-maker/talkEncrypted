class Api::MessagesController < ApplicationController
  include Authenticatable

  before_action :find_conversation

  def index
    limit = [ (params[:limit] || 30).to_i, 100 ].min
    scope = @conversation.messages.includes(:message_links).order(created_at: :desc)
    scope = scope.where("messages.id < ?", params[:before_id].to_i) if params[:before_id].present?
    messages = scope.limit(limit).to_a.reverse

    render json: { messages: messages.map { |m| message_json(m) } }
  end

  def create
    message = @conversation.messages.build(body: params[:body], sender: current_user)

    if message.save
      ActionCable.server.broadcast(
        "conversation_#{@conversation.id}",
        {
          type: "message.created",
          conversation_id: @conversation.id,
          message_id: message.id,
          sender_id: message.sender_id,
          created_at: message.created_at.iso8601
        }
      )
      render json: { message: message_json(message) }, status: :created
    else
      render_error(
        code: "invalid_request",
        message: message.errors.full_messages.to_sentence,
        status: :unprocessable_entity
      )
    end
  end

  private

  def find_conversation
    member = current_user.conversation_members
                         .find_by(conversation_id: params[:conversation_id])
    return render_forbidden if member.nil?

    @conversation = member.conversation
  end

  def message_json(message)
    {
      id: message.id,
      conversation_id: message.conversation_id,
      sender_id: message.sender_id,
      body: message.body,
      created_at: message.created_at.iso8601,
      links: message.message_links.map { |l| link_json(l) }
    }
  end

  def link_json(link)
    {
      id: link.id,
      url: link.url,
      domain: link.domain,
      title: link.title,
      description: link.description,
      status: link.status,
      fetched_at: link.fetched_at&.iso8601
    }
  end
end
