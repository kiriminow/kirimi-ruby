# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/pride'
require 'json'
require 'ostruct'

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'kirimi'

# Minimal HTTP response stub
FakeResponse = Struct.new(:code, :body, :message) do
  def [](key); nil; end
end

# Captures the last request body sent via Net::HTTP
module NetHTTPStub
  @stub_status   = 200
  @stub_body     = {}
  @last_body     = nil
  @last_path     = nil

  class << self
    attr_accessor :stub_status, :stub_body, :last_body, :last_path

    def setup(status:, body:)
      @stub_status = status
      @stub_body   = body
      @last_body   = nil
      @last_path   = nil
    end
  end
end

# Monkey-patch Net::HTTP for tests only
module Net
  class HTTP
    def request(req)
      NetHTTPStub.last_body = JSON.parse(req.body) rescue req.body
      NetHTTPStub.last_path = req.path
      FakeResponse.new(
        NetHTTPStub.stub_status.to_s,
        NetHTTPStub.stub_body.to_json,
        'OK'
      )
    end
  end
end

class ClientTest < Minitest::Test
  def setup
    @client = Kirimi::Client.new(user_code: 'USER', secret: 'SECRET')
  end

  def stub(status: 200, body: { 'success' => true, 'data' => nil, 'message' => 'ok' })
    NetHTTPStub.setup(status: status, body: body)
  end

  # ---- send_message ----

  def test_send_message_correct_body
    stub(body: { 'success' => true, 'data' => { 'id' => 'msg_1' }, 'message' => 'sent' })

    resp = @client.send_message(device_id: 'DEV1', phone: '628111', message: 'Hello!')

    assert_equal 'USER',   NetHTTPStub.last_body['user_code']
    assert_equal 'SECRET', NetHTTPStub.last_body['secret']
    assert_equal 'DEV1',   NetHTTPStub.last_body['device_id']
    assert_equal '628111', NetHTTPStub.last_body['phone']
    assert_equal 'Hello!', NetHTTPStub.last_body['message']
    assert_instance_of Kirimi::Response, resp
    assert resp.success?
    assert_equal 'msg_1', resp.data['id']
  end

  def test_send_message_includes_media_url
    stub
    @client.send_message(device_id: 'DEV1', phone: '628111', message: 'pic', media_url: 'https://img.example.com/a.jpg')
    assert_equal 'https://img.example.com/a.jpg', NetHTTPStub.last_body['media_url']
  end

  def test_send_message_omits_media_url_when_nil
    stub
    @client.send_message(device_id: 'DEV1', phone: '628111', message: 'hi')
    refute NetHTTPStub.last_body.key?('media_url')
  end

  # ---- generate_otp ----

  def test_generate_otp_with_optional_params
    stub(body: { 'success' => true, 'data' => { 'otp' => '123456' }, 'message' => 'OTP sent' })

    resp = @client.generate_otp(
      device_id:          'DEV1',
      phone:              '628111',
      otp_length:         6,
      otp_type:           'numeric',
      custom_otp_message: 'Your code is {otp}'
    )

    assert_equal 6,                   NetHTTPStub.last_body['otp_length']
    assert_equal 'numeric',           NetHTTPStub.last_body['otp_type']
    assert_equal 'Your code is {otp}', NetHTTPStub.last_body['customOtpMessage']
    assert resp.success?
    assert_equal '123456', resp.data['otp']
  end

  def test_generate_otp_omits_optional_when_nil
    stub
    @client.generate_otp(device_id: 'DEV1', phone: '628111')
    refute NetHTTPStub.last_body.key?('otp_length')
    refute NetHTTPStub.last_body.key?('customOtpMessage')
  end

  # ---- error handling ----

  def test_raises_api_error_on_401
    stub(status: 401, body: { 'success' => false, 'message' => 'Unauthorized' })

    err = assert_raises(Kirimi::ApiError) { @client.user_info }
    assert_equal 401,            err.status_code
    assert_equal 'Unauthorized', err.message
  end

  def test_raises_api_error_on_500
    stub(status: 500, body: { 'success' => false, 'message' => 'Server Error' })

    err = assert_raises(Kirimi::ApiError) { @client.list_devices }
    assert_equal 500, err.status_code
  end

  # ---- response wrapping ----

  def test_response_wraps_data_correctly
    stub(body: { 'success' => true, 'data' => { 'name' => 'John' }, 'message' => 'OK' })

    resp = @client.user_info

    assert_instance_of Kirimi::Response, resp
    assert resp.success?
    assert_equal true,   resp.success
    assert_equal 'John', resp.data['name']
    assert_equal 'OK',   resp.message
    assert_instance_of Hash, resp.raw
  end

  # ---- broadcast phones array ----

  def test_broadcast_joins_phones_array
    stub
    @client.broadcast_message(device_id: 'DEV1', phones: %w[628111 628222 628333], message: 'Promo!')
    assert_equal '628111,628222,628333', NetHTTPStub.last_body['phones']
  end

  def test_broadcast_accepts_phones_string
    stub
    @client.broadcast_message(device_id: 'DEV1', phones: '628111,628222', message: 'Hi')
    assert_equal '628111,628222', NetHTTPStub.last_body['phones']
  end
end
