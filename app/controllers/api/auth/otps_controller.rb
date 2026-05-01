class Api::Auth::OtpsController < ApplicationController
  def request_otp
    email = params[:email]&.downcase&.strip
    invite_code_raw = params[:invite_code]&.strip

    if email.blank?
      return render_error(code: "invalid_request", message: "Email is required.", status: :bad_request)
    end

    if invite_code_raw.present?
      invite_code = InviteCode.find_valid_by_raw_code(invite_code_raw)

      if invite_code.nil?
        return render json: {
          error: {
            code: "invalid_invite_code",
            message: "Invite code is invalid or unavailable."
          }
        }, status: :unprocessable_entity
      end

      raw_code = EmailOtp.create_for(email, purpose: "signup", invite_code: invite_code)
      Rails.logger.info "[OTP] Signup code for #{email}: #{raw_code}"
    else
      user = User.find_by(email: email)

      if user
        raw_code = EmailOtp.create_for(email, purpose: "login")
        Rails.logger.info "[OTP] Login code for #{email}: #{raw_code}"
      end
      # Silent fail if user not found — prevents email enumeration
    end

    render json: { message: "If this request is valid, a code has been sent." }
  end

  def verify_otp
    email = params[:email]&.downcase&.strip
    code = params[:code]&.strip

    if email.blank? || code.blank?
      return render_error(code: "invalid_request", message: "Email and code are required.", status: :bad_request)
    end

    otp = EmailOtp.find_pending_for(email)

    if otp.nil? || !otp.verify!(code)
      return render json: {
        error: {
          code: "invalid_otp",
          message: "Code is invalid or expired."
        }
      }, status: :unprocessable_entity
    end

    if otp.purpose == "signup"
      user = User.create!(email: email)
      otp.invite_code&.consume!(user)
    else
      user = User.find_by(email: email)

      if user.nil?
        return render json: {
          error: { code: "invalid_otp", message: "Code is invalid or expired." }
        }, status: :unprocessable_entity
      end
    end

    _session, raw_token = UserSession.create_for(user)

    render json: {
      token: raw_token,
      profile_required: !user.profile_completed?,
      user: user_json(user)
    }
  end

  private

  def user_json(user)
    {
      id: user.id,
      email: user.email,
      display_name: user.display_name,
      bio: user.bio
    }
  end
end
