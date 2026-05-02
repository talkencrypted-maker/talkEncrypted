class Rack::Attack
  Rack::Attack.cache.store = Rails.cache

  throttle("otp_request/email", limit: 5, period: 1.hour) do |req|
    if req.path == "/api/auth/otp/request" && req.post?
      req.params["email"].to_s.downcase.strip.presence
    end
  end

  throttle("otp_request/ip", limit: 20, period: 1.hour) do |req|
    req.ip if req.path == "/api/auth/otp/request" && req.post?
  end

  throttle("otp_verify/ip", limit: 10, period: 1.hour) do |req|
    req.ip if req.path == "/api/auth/otp/verify" && req.post?
  end

  self.throttled_responder = lambda do |req|
    match_data = req.env["rack.attack.match_data"] || {}
    retry_after = match_data[:period] || 60

    [
      429,
      {
        "Content-Type" => "application/json",
        "Retry-After"  => retry_after.to_s
      },
      [ { error: { code: "rate_limited", message: "Too many requests. Try again later." } }.to_json ]
    ]
  end
end
