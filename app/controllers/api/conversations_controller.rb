class Api::ConversationsController < ApplicationController
  include Authenticatable

  def index
    members = current_user.conversation_members
                          .joins(:conversation)
                          .includes(conversation: [ :messages, :users ])
                          .order("conversations.updated_at DESC")
                          .limit(30)


    conversations = []
    members.each do |member|
      conversations << member.conversation
    end

    conversation_list = []
    conversations.each do |conversation|
      conversation_list << conversation_list_json(conversation)
    end

    render json: { conversations: conversation_list }
  end

  def create
    recipient = User.find_by(id: params[:recipient_id])

    if recipient.nil?
      return render_not_found
    end

    if recipient.id == current_user.id
      return render_error(
        code: "invalid_request",
        message: "Cannot start a conversation with yourself.",
        status: :unprocessable_entity
      )
    end

    conversation = Conversation.direct_between(current_user, recipient)

    if conversation.nil?
      conversation = Conversation.create!(kind: "direct")
      conversation.conversation_members.create!(user: current_user)
      conversation.conversation_members.create!(user: recipient)
    end

    render json: { conversation: conversation_list_json(conversation) }, status: :created
  end

  def show
    member = current_user.conversation_members
                         .includes(:conversation)
                         .find_by(conversation_id: params[:id])

    if member.nil?
      return render_forbidden
    end

    render json: { conversation: conversation_detail_json(member.conversation, member) }
  end

  def read
    member = current_user.conversation_members.find_by(conversation_id: params[:id])

    if member.nil?
      return render_forbidden
    end

    member.update!(last_read_message_id: params[:last_read_message_id])

    ActionCable.server.broadcast(
      "conversation_#{params[:id]}",
      {
        type: "conversation.read",
        conversation_id: params[:id].to_i,
        user_id: current_user.id,
        last_read_message_id: params[:last_read_message_id],
        created_at: Time.current.iso8601
      }
    )

    render json: {
      conversation_id: params[:id].to_i,
      last_read_message_id: params[:last_read_message_id]
    }
  end

  private

  def conversation_base_json(conversation)
    recipient = conversation.recipient_for(current_user)

    {
      id: conversation.id,
      kind: conversation.kind,
      recipient: user_json(recipient)
    }
  end

  def conversation_list_json(conversation)
    last_message = conversation.last_message

    base = conversation_base_json(conversation)

    if last_message.nil?
      base[:last_message] = nil
    else
      base[:last_message] = message_summary_json(last_message)
    end

    base
  end

  def conversation_detail_json(conversation, member)
    last_message = conversation.last_message

    base = conversation_base_json(conversation)

    if last_message.nil?
      base[:last_message] = nil
    else
      base[:last_message] = message_summary_json(last_message)
    end

    base[:last_read_message_id] = member.last_read_message_id
    base[:created_at] = conversation.created_at.iso8601
    base[:updated_at] = conversation.updated_at.iso8601

    base
  end

  def message_summary_json(message)
    {
      id: message.id,
      sender_id: message.sender_id,
      body: message.body,
      created_at: message.created_at.iso8601
    }
  end

  def user_json(user)
    if user.nil?
      return nil
    end

    {
      id: user.id,
      email: user.email,
      display_name: user.display_name,
      bio: user.bio
    }
  end
end
