class OtpMailer< ApplicationMailer
  def signup_otp(email, code)
    @code = code
    mail(to: email, subject: "Your Signup OTP for talkencrypted")
  end

  def login_otp(email, code)
    @code = code
    mail(to: email, subject: "Your Login OTP for talkencrypted")
  end
end
