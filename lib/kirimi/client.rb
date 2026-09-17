# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'
require 'securerandom'

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

    def send_message(device_id:, receiver:, message:, media_url: nil, file_name: nil,
                     enable_typing_effect: nil, typing_speed_ms: nil, quoted_message_id: nil)
      body = { device_id: device_id, receiver: receiver, message: message }
      body[:media_url]           = media_url           if media_url
      body[:fileName]            = file_name           if file_name
      body[:enableTypingEffect]  = enable_typing_effect unless enable_typing_effect.nil?
      body[:typingSpeedMs]       = typing_speed_ms     if typing_speed_ms
      body[:quotedMessageId]     = quoted_message_id   if quoted_message_id
      post('/v1/send-message', body)
    end

    def send_message_file(device_id:, receiver:, file:, file_name: nil, message: nil, caption: nil,
                          quoted_message_id: nil)
      file_io = file.is_a?(String) ? File.open(file, 'rb') : file
      fields = {
        'user_code' => @user_code,
        'secret'    => @secret,
        'device_id' => device_id,
        'receiver'  => receiver
      }
      fields['fileName']        = file_name        if file_name
      fields['message']         = message          if message
      fields['caption']         = caption          if caption
      fields['quotedMessageId'] = quoted_message_id if quoted_message_id
      post_multipart('/v1/send-message-file', fields, file_io, file_name || 'file')
    ensure
      file_io&.close if file.is_a?(String)
    end

    def send_message_fast(device_id:, receiver:, message:, media_url: nil, file_name: nil,
                          quoted_message_id: nil)
      body = { device_id: device_id, receiver: receiver, message: message }
      body[:media_url]       = media_url         if media_url
      body[:fileName]        = file_name         if file_name
      body[:quotedMessageId] = quoted_message_id if quoted_message_id
      post('/v1/send-message-fast', body)
    end

    # --- Broadcast ---

    def broadcast_message(device_id:, label:, numbers:, message:, delay: nil, delay_min: nil,
                          delay_max: nil, media_url: nil, file_name: nil, started_at: nil,
                          enable_typing_effect: nil, typing_speed_ms: nil)
      body = {
        device_id: device_id,
        label:     label,
        numbers:   Array(numbers),
        message:   message
      }
      body[:delay]              = delay           if delay
      body[:delayMin]           = delay_min       if delay_min
      body[:delayMax]           = delay_max       if delay_max
      body[:media_url]          = media_url       if media_url
      body[:fileName]           = file_name       if file_name
      body[:started_at]         = started_at      if started_at
      body[:enableTypingEffect] = enable_typing_effect unless enable_typing_effect.nil?
      body[:typingSpeedMs]      = typing_speed_ms if typing_speed_ms
      post('/v1/broadcast-message', body)
    end

    # --- WABA (Cloud API) ---

    def send_waba_message(waba_id:, to:, template_name:, variables: nil, header: nil, buttons: nil)
      body = { waba_id: waba_id, to: to, template_name: template_name }
      body[:variables] = variables if variables
      body[:header]    = header    if header
      body[:buttons]   = buttons   if buttons
      post('/v1/waba/send-message', body)
    end

    def waba_reply(waba_id:, to:, message:)
      post('/v1/waba/messages/reply', { waba_id: waba_id, to: to, message: message })
    end

    def waba_conversations(limit: nil, page: nil)
      body = {}
      body[:limit] = limit if limit
      body[:page]  = page  if page
      post('/v1/waba/conversations', body)
    end

    def waba_templates_sync(waba_id:)
      post('/v1/waba/templates/sync', { waba_id: waba_id })
    end

    def waba_send_otp(waba_id:, to:, template_name:)
      post('/v1/waba/send-otp', { waba_id: waba_id, to: to, template_name: template_name })
    end

    def waba_verify_otp(waba_id:, to:, otp_code:)
      post('/v1/waba/verify-otp', { waba_id: waba_id, to: to, otp_code: otp_code })
    end

    # --- Devices ---

    def create_device(package_id:, voucher_code: nil)
      body = { package_id: package_id }
      body[:voucher_code] = voucher_code if voucher_code
      post('/v1/create-device', body)
    end

    def connect_device(device_id:)
      post('/v1/connect-device', { device_id: device_id })
    end

    def renew_device(device_id:, package_id:, voucher_code: nil)
      body = { device_id: device_id, package_id: package_id }
      body[:voucher_code] = voucher_code if voucher_code
      post('/v1/renew-device', body)
    end

    def list_devices(page: nil, limit: nil)
      body = {}
      body[:page]  = page  if page
      body[:limit] = limit if limit
      post('/v1/list-devices', body)
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

    def save_contact(nama:, nomor:, device_id: nil)
      body = { nama: nama, nomor: nomor }
      body[:device_id] = device_id if device_id
      post('/v1/save-contact', body)
    end

    def save_contacts_bulk(contacts:, device_id: nil)
      body = { contacts: contacts }
      body[:device_id] = device_id if device_id
      post('/v1/save-contacts-bulk', body)
    end

    # --- OTP (V1) ---

    def generate_otp(device_id:, phone:, otp_length: nil, otp_type: nil, custom_otp_text: nil,
                     custom_otp_message: nil, enable_typing_effect: nil, typing_speed_ms: nil)
      body = { device_id: device_id, phone: phone }
      body[:otp_length]         = otp_length         if otp_length
      body[:otp_type]           = otp_type           if otp_type
      body[:customOtpText]      = custom_otp_text    if custom_otp_text
      body[:customOtpMessage]   = custom_otp_message if custom_otp_message
      body[:enableTypingEffect] = enable_typing_effect unless enable_typing_effect.nil?
      body[:typingSpeedMs]      = typing_speed_ms    if typing_speed_ms
      post('/v1/generate-otp', body)
    end

    def validate_otp(device_id:, phone:, otp:)
      post('/v1/validate-otp', { device_id: device_id, phone: phone, otp: otp })
    end

    # --- OTP (V2) ---

    def send_otp_v2(phone:, method: nil, app_name: nil, device_id: nil, waba_id: nil,
                    template_name: nil, custom_message: nil)
      body = { phone: phone }
      body[:method]         = method         if method
      body[:app_name]       = app_name       if app_name
      body[:device_id]      = device_id      if device_id
      body[:waba_id]        = waba_id        if waba_id
      body[:template_name]  = template_name  if template_name
      body[:custom_message] = custom_message if custom_message
      post('/v2/otp/send', body)
    end

    def verify_otp_v2(phone:, otp_code:)
      post('/v2/otp/verify', { phone: phone, otp_code: otp_code })
    end

    # --- OTP Reverse ---

    def otp_reverse_create(phone:, device_id:, app_name: nil, callback_url: nil,
                           custom_message: nil, success_message: nil, failure_message: nil)
      body = { phone: phone, device_id: device_id }
      body[:app_name]        = app_name        if app_name
      body[:callback_url]    = callback_url    if callback_url
      body[:custom_message]  = custom_message  if custom_message
      body[:success_message] = success_message if success_message
      body[:failure_message] = failure_message if failure_message
      post('/v2/otp-reverse/create', body)
    end

    def otp_reverse_status(token:)
      post('/v2/otp-reverse/status', { token: token })
    end

    # --- Packages & Deposits ---

    def list_packages
      post('/v1/list-packages', {})
    end

    def create_deposit(nominal:)
      post('/v1/create-deposit', { nominal: nominal })
    end

    def deposit_status(ref:)
      post('/v1/deposit-status', { ref: ref })
    end

    def cancel_deposit(ref:)
      post('/v1/cancel-deposit', { ref: ref })
    end

    def list_deposits(page: nil, limit: nil, status: nil)
      body = {}
      body[:page]   = page   if page
      body[:limit]  = limit  if limit
      body[:status] = status if status
      post('/v1/list-deposits', body)
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
