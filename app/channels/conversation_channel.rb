class ConversationChannel < ApplicationCable::Channel
  def subscribed
    conversation_id = params[:conversation_id]

    member = current_user.conversation_members.find_by(conversation_id: conversation_id)

    if member.nil?
      reject
      return
    end

    stream_from "conversation_#{conversation_id}"
  end
end
