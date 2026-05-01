class Api::UsersController < ApplicationController
  include Authenticatable

  def me
    render json: { user: full_user_json(current_user) }
  end

  def update_me
    if current_user.update(me_params)
      render json: { user: full_user_json(current_user) }
    else
      render_error(
        code: "invalid_request",
        message: current_user.errors.full_messages.to_sentence,
        status: :unprocessable_entity
      )
    end
  end

  def search
    query = params[:query]&.strip

    if query.blank?
      return render json: { users: [] }
    end

    users = User.where.not(id: current_user.id)
                .where.not(profile_completed_at: nil)
                .where("email ILIKE ? OR display_name ILIKE ?", "%#{query}%", "%#{query}%")
                .limit(20)

    render json: { users: users.map { |u| search_user_json(u) } }
  end

  private

  def me_params
    params.permit(:display_name, :bio)
  end

  def full_user_json(user)
    {
      id: user.id,
      email: user.email,
      display_name: user.display_name,
      bio: user.bio,
      profile_completed_at: user.profile_completed_at&.iso8601
    }
  end

  def search_user_json(user)
    {
      id: user.id,
      email: user.email,
      display_name: user.display_name,
      bio: user.bio
    }
  end
end
