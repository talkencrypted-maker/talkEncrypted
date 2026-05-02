class Api::Auth::OtpsController < ApplicationController
  def request_otp
    email = params[:email]&.downcase&.strip
    invite_code_raw = params[:invite_code]&.strip

    if email.blank?
      return render_error(code: "invalid_request", message: "Email is required.", status: :bad_request)
    end

    if EmailOtp.email_locked_out?(email)
      return render_locked_out
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
      OtpMailer.signup_otp(email, raw_code).deliver_later
    else
      user = User.find_by(email: email)

      if user
        raw_code = EmailOtp.create_for(email, purpose: "login")
        Rails.logger.info "[OTP] Login code for #{email}: #{raw_code}"
        OtpMailer.login_otp(email, raw_code).deliver_later

      end
      # Silent fail if user not found — prevents email enumeration
    end

    render json: { message: "A code has been sent to your email." }
  end

  def verify_otp
    email = params[:email]&.downcase&.strip
    code = params[:code]&.strip

    if email.blank? || code.blank?
      return render_error(code: "invalid_request", message: "Email and code are required.", status: :bad_request)
    end

    if EmailOtp.email_locked_out?(email)
      return render_locked_out
    end

    otp = EmailOtp.find_pending_for(email)

    if otp.nil?
      return render_invalid_otp(email)
    end

    case otp.verify(code)
    when :expired
      return render_invalid_otp(email)
    when :invalid_code
      # The increment may have just crossed the lockout threshold.
      return EmailOtp.email_locked_out?(email) ? render_locked_out : render_invalid_otp(email)
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

  def render_locked_out
    render json: {
      error: {
        code: "otp_locked_out",
        message: "Too many attempts. Try again in an hour."
      }
    }, status: :unprocessable_entity
  end

  def render_invalid_otp(email)
    render json: {
      error: {
        code: "invalid_otp",
        message: "Code is invalid or expired.",
        attempts_remaining: EmailOtp.attempts_remaining_for(email)
      }
    }, status: :unprocessable_entity
  end

  def user_json(user)
    {
      id: user.id,
      email: user.email,
      display_name: user.display_name,
      bio: user.bio
    }
  end
end
