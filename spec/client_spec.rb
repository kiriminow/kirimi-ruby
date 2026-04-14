# frozen_string_literal: true

RSpec.describe Kirimi::Client do
  let(:user_code) { 'TEST_USER' }
  let(:secret)    { 'TEST_SECRET' }
  let(:client)    { described_class.new(user_code: user_code, secret: secret) }
  let(:base_url)  { 'https://api.kirimi.id' }

  def stub_post(path, request_body: {}, response_body: {}, status: 200)
    stub_request(:post, "#{base_url}#{path}")
      .with(
        body: hash_including(request_body),
        headers: { 'Content-Type' => 'application/json' }
      )
      .to_return(
        status: status,
        body:   response_body.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  describe '#send_message' do
    it 'sends correct body and returns a Response' do
      stub_post(
        '/v1/send-message',
        request_body: {
          'user_code' => user_code,
          'secret'    => secret,
          'device_id' => 'DEV1',
          'phone'     => '628111222333',
          'message'   => 'Hello!'
        },
        response_body: { 'success' => true, 'data' => { 'id' => 'msg_1' }, 'message' => 'Message sent' }
      )

      resp = client.send_message(device_id: 'DEV1', phone: '628111222333', message: 'Hello!')

      expect(resp).to be_a(Kirimi::Response)
      expect(resp.success?).to be true
      expect(resp.data).to eq('id' => 'msg_1')
      expect(resp.message).to eq('Message sent')
    end

    it 'includes media_url when provided' do
      stub_post(
        '/v1/send-message',
        request_body: { 'media_url' => 'https://example.com/img.jpg' },
        response_body: { 'success' => true, 'data' => nil, 'message' => 'ok' }
      )

      resp = client.send_message(
        device_id: 'DEV1',
        phone:     '628111222333',
        message:   'Check this',
        media_url: 'https://example.com/img.jpg'
      )

      expect(resp.success?).to be true
    end
  end

  describe '#generate_otp' do
    it 'sends correct body with optional params' do
      stub_post(
        '/v1/generate-otp',
        request_body: {
          'user_code'       => user_code,
          'secret'          => secret,
          'device_id'       => 'DEV1',
          'phone'           => '628111222333',
          'otp_length'      => 6,
          'otp_type'        => 'numeric',
          'customOtpMessage' => 'Your OTP is {otp}'
        },
        response_body: { 'success' => true, 'data' => { 'otp' => '123456' }, 'message' => 'OTP sent' }
      )

      resp = client.generate_otp(
        device_id:         'DEV1',
        phone:             '628111222333',
        otp_length:        6,
        otp_type:          'numeric',
        custom_otp_message: 'Your OTP is {otp}'
      )

      expect(resp.success?).to be true
      expect(resp.data['otp']).to eq('123456')
    end

    it 'does not include optional fields when nil' do
      stub_request(:post, "#{base_url}/v1/generate-otp")
        .with do |req|
          body = JSON.parse(req.body)
          !body.key?('otp_length') && !body.key?('customOtpMessage')
        end
        .to_return(status: 200, body: { 'success' => true, 'data' => nil, 'message' => 'ok' }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      resp = client.generate_otp(device_id: 'DEV1', phone: '628111222333')
      expect(resp.success?).to be true
    end
  end

  describe 'error handling' do
    it 'raises ApiError on 401' do
      stub_post(
        '/v1/user-info',
        request_body: {},
        response_body: { 'success' => false, 'message' => 'Unauthorized' },
        status: 401
      )

      expect { client.user_info }.to raise_error(Kirimi::ApiError) do |err|
        expect(err.status_code).to eq(401)
        expect(err.message).to eq('Unauthorized')
      end
    end

    it 'raises ApiError on 500' do
      stub_post(
        '/v1/list-devices',
        request_body: {},
        response_body: { 'success' => false, 'message' => 'Internal Server Error' },
        status: 500
      )

      expect { client.list_devices }.to raise_error(Kirimi::ApiError) do |err|
        expect(err.status_code).to eq(500)
      end
    end
  end

  describe 'Response wrapper' do
    it 'wraps response data correctly' do
      stub_post(
        '/v1/user-info',
        request_body: {},
        response_body: {
          'success' => true,
          'data'    => { 'name' => 'John Doe', 'email' => 'john@example.com' },
          'message' => 'OK'
        }
      )

      resp = client.user_info

      expect(resp).to be_a(Kirimi::Response)
      expect(resp.success).to be true
      expect(resp.success?).to be true
      expect(resp.data['name']).to eq('John Doe')
      expect(resp.raw).to be_a(Hash)
      expect(resp.raw['success']).to be true
    end
  end

  describe '#broadcast_message' do
    it 'joins phones array with comma' do
      stub_request(:post, "#{base_url}/v1/broadcast-message")
        .with do |req|
          body = JSON.parse(req.body)
          body['phones'] == '628111,628222,628333'
        end
        .to_return(status: 200, body: { 'success' => true, 'data' => nil, 'message' => 'ok' }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      resp = client.broadcast_message(
        device_id: 'DEV1',
        phones:    %w[628111 628222 628333],
        message:   'Promo!'
      )
      expect(resp.success?).to be true
    end
  end
end
