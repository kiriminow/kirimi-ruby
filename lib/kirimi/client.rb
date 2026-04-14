# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

module Kirimi
  class Client
    DEFAULT_BASE_URL = 'https://api.kirimi.id'
    DEFAULT_TIMEOUT  = 30

    def initialize(user_code:, secret:, base_url: DEFAULT_BASE_URL, timeout: DEFAULT_TIMEOUT)
      @user_code = user_code
      @secret    = secret
      @base_url  = base_url.chomp('/')
      @timeout   = timeout
    end

    # --- WhatsApp Unofficial ---

    def send_message(device_id:, phone:, message:, media_url: nil)
      body = { device_id: device_id, phone: phone, message: message }
      body[:media_url] = media_url if media_url
      post('/v1/send-message', body)
    end

    def send_message_file(device_id:, phone:, file:, file_name:, message: nil)
      file_io = file.is_a?(String) ? File.open(file, 'rb') : file
      fields = {
        'user_code' => @user_code,
        'secret'    => @secret,
        'device_id' => device_id,
        'phone'     => phone,
        'fileName'  => file_name
      }
      fields['message'] = message if message
      post_multipart('/v1/send-message-file', fields, file_io, file_name)
    ensure
      file_io&.close if file.is_a?(String)
    end

    def send_message_fast(device_id:, phone:, message:, media_url: nil)
      body = { device_id: device_id, phone: phone, message: message }
      body[:media_url] = media_url if media_url
      post('/v1/send-message-fast', body)
    end

    # --- WABA ---

    def send_waba_message(device_id:, phone:, message:)
      post('/v1/waba/send-message', { device_id: device_id, phone: phone, message: message })
    end

    # --- Devices ---

    def list_devices
      post('/v1/list-devices', {})
    end

    def device_status(device_id:)
      post('/v1/device-status', { device_id: device_id })
    end

    def device_status_enhanced(device_id:)
      post('/v1/device-status-enhanced', { device_id: device_id })
    end

    # --- User ---

    def user_info
      post('/v1/user-info', {})
    end

    # --- Contacts ---

    def save_contact(phone:, name: nil, email: nil)
      body = { phone: phone }
      body[:name]  = name  if name
      body[:email] = email if email
      post('/v1/save-contact', body)
    end

    # --- OTP ---

    def generate_otp(device_id:, phone:, otp_length: nil, otp_type: nil, custom_otp_message: nil)
      body = { device_id: device_id, phone: phone }
      body[:otp_length]       = otp_length        if otp_length
      body[:otp_type]         = otp_type           if otp_type
      body[:customOtpMessage] = custom_otp_message if custom_otp_message
      post('/v1/generate-otp', body)
    end

    def validate_otp(device_id:, phone:, otp:)
      post('/v1/validate-otp', { device_id: device_id, phone: phone, otp: otp })
    end

    # --- OTP V2 ---

    def send_otp_v2(phone:, device_id:, method: nil, app_name: nil, template_code: nil, custom_message: nil)
      body = { phone: phone, device_id: device_id }
      body[:method]        = method        if method
      body[:app_name]      = app_name      if app_name
      body[:template_code] = template_code if template_code
      body[:custom_message] = custom_message if custom_message
      post('/v2/otp/send', body)
    end

    def verify_otp_v2(phone:, otp_code:)
      post('/v2/otp/verify', { phone: phone, otp_code: otp_code })
    end

    # --- Broadcast ---

    def broadcast_message(device_id:, phones:, message:, delay: nil)
      phones_str = phones.is_a?(Array) ? phones.join(',') : phones
      body = { device_id: device_id, phones: phones_str, message: message }
      body[:delay] = delay if delay
      post('/v1/broadcast-message', body)
    end

    # --- Deposits ---

    def list_deposits(status: nil)
      body = {}
      body[:status] = status if status
      post('/v1/list-deposits', body)
    end

    def list_packages
      post('/v1/list-packages', {})
    end

    private

    def auth_params
      { user_code: @user_code, secret: @secret }
    end

    def post(path, body)
      uri = URI("#{@base_url}#{path}")
      http = build_http(uri)

      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request['Accept']       = 'application/json'
      request.body = JSON.generate(auth_params.merge(body))

      execute(http, request)
    end

    def post_multipart(path, fields, file_io, file_name)
      uri      = URI("#{@base_url}#{path}")
      http     = build_http(uri)
      boundary = "KirimiRubySDK#{SecureRandom.hex(8)}"

      body_parts = []
      fields.each do |key, value|
        body_parts << "--#{boundary}\r\n"
        body_parts << "Content-Disposition: form-data; name=\"#{key}\"\r\n\r\n"
        body_parts << "#{value}\r\n"
      end

      # File part
      file_data = file_io.read
      body_parts << "--#{boundary}\r\n"
      body_parts << "Content-Disposition: form-data; name=\"file\"; filename=\"#{file_name}\"\r\n"
      body_parts << "Content-Type: application/octet-stream\r\n\r\n"
      body_parts << file_data
      body_parts << "\r\n--#{boundary}--\r\n"

      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = "multipart/form-data; boundary=#{boundary}"
      request['Accept']       = 'application/json'
      request.body = body_parts.join

      execute(http, request)
    end

    def build_http(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl     = (uri.scheme == 'https')
      http.read_timeout  = @timeout
      http.open_timeout  = @timeout
      http
    end

    def execute(http, request)
      response = http.request(request)
      parse_response(response)
    rescue Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::ETIMEDOUT,
           Net::OpenTimeout, Net::ReadTimeout, SocketError => e
      raise Kirimi::NetworkError, "Network error: #{e.message}"
    end

    def parse_response(response)
      status = response.code.to_i
      body   = parse_body(response.body)

      unless (200..299).cover?(status)
        msg = body.is_a?(Hash) ? (body['message'] || response.message) : response.message
        raise Kirimi::ApiError.new(status, msg, body)
      end

      Kirimi::Response.new(body)
    end

    def parse_body(body)
      return {} if body.nil? || body.empty?

      JSON.parse(body)
    rescue JSON::ParserError
      { 'message' => body }
    end
  end
end

# Lazy require SecureRandom (part of stdlib, always available)
require 'securerandom'
