# frozen_string_literal: true

RSpec.describe Kirimi::Client do
  let(:user_code) { 'TEST_USER' }
  let(:secret)    { 'TEST_SECRET' }
  let(:client)    { described_class.new(user_code: user_code, secret: secret) }
  let(:base_url)  { 'https://api.kirimi.id' }

  OK = { 'success' => true, 'data' => nil, 'message' => 'ok' }.freeze

  # Stub a POST and assert the exact JSON body sent on the wire.
  def stub_post_exact(path, expected_body, response_body: OK, status: 200)
    stub_request(:post, "#{base_url}#{path}")
      .with(
        body: expected_body,
        headers: {
          'Content-Type' => 'application/json',
          'Accept'       => 'application/json'
        }
      )
      .to_return(
        status: status,
        body:   response_body.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  def auth
    { 'user_code' => user_code, 'secret' => secret }
  end

  # Stub a POST; the returned holder's #body holds the parsed JSON body sent.
  def capture_post(path, response_body: OK, status: 200)
    holder = Struct.new(:body).new(nil)
    stub_request(:post, "#{base_url}#{path}")
      .with do |req|
        holder.body = JSON.parse(req.body)
        true
      end
      .to_return(
        status: status,
        body:   response_body.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    holder
  end

  # --- WhatsApp Unofficial ---

  describe '#send_message' do
    it 'sends receiver (never phone) and returns a Response' do
      stub_post_exact(
        '/v1/send-message',
        auth.merge(
          'device_id' => 'DEV1',
          'receiver'  => '628111222333',
          'message'   => 'Hello!'
        ),
        response_body: { 'success' => true, 'data' => { 'id' => 'msg_1' }, 'message' => 'Message sent' }
      )

      resp = client.send_message(device_id: 'DEV1', receiver: '628111222333', message: 'Hello!')

      expect(resp).to be_a(Kirimi::Response)
      expect(resp.success?).to be true
      expect(resp.data).to eq('id' => 'msg_1')
      expect(resp.message).to eq('Message sent')
    end

    it 'never sends a phone key' do
      captured = capture_post('/v1/send-message')

      client.send_message(device_id: 'DEV1', receiver: '628111222333', message: 'Hi')

      expect(captured.body).not_to have_key('phone')
      expect(captured.body['receiver']).to eq('628111222333')
    end

    it 'includes all optional params when provided' do
      stub_post_exact(
        '/v1/send-message',
        auth.merge(
          'device_id'          => 'DEV1',
          'receiver'           => '628111',
          'message'            => 'Check this',
          'media_url'          => 'https://example.com/img.jpg',
          'fileName'           => 'img.jpg',
          'enableTypingEffect' => true,
          'typingSpeedMs'      => 350,
          'quotedMessageId'    => 'wamid.1'
        )
      )

      resp = client.send_message(
        device_id:            'DEV1',
        receiver:             '628111',
        message:              'Check this',
        media_url:            'https://example.com/img.jpg',
        file_name:            'img.jpg',
        enable_typing_effect: true,
        typing_speed_ms:      350,
        quoted_message_id:    'wamid.1'
      )

      expect(resp.success?).to be true
    end

    it 'omits optional params when nil' do
      captured = capture_post('/v1/send-message')

      client.send_message(device_id: 'DEV1', receiver: '628111', message: 'Hi')

      expect(captured.body).to eq(
        auth.merge('device_id' => 'DEV1', 'receiver' => '628111', 'message' => 'Hi')
      )
    end

    it 'keeps enableTypingEffect false rather than dropping it' do
      captured = capture_post('/v1/send-message')

      client.send_message(device_id: 'DEV1', receiver: '628111', message: 'Hi',
                          enable_typing_effect: false)

      expect(captured.body).to have_key('enableTypingEffect')
      expect(captured.body['enableTypingEffect']).to be false
    end
  end

  describe '#send_message_fast' do
    it 'sends receiver and omits typing-effect params' do
      captured = capture_post('/v1/send-message-fast')

      client.send_message_fast(
        device_id: 'DEV1',
        receiver:  '628111',
        message:   'Fast',
        media_url: 'https://example.com/a.jpg',
        file_name: 'a.jpg',
        quoted_message_id: 'wamid.2'
      )

      expect(captured.body).to eq(
        auth.merge(
          'device_id'       => 'DEV1',
          'receiver'        => '628111',
          'message'         => 'Fast',
          'media_url'       => 'https://example.com/a.jpg',
          'fileName'        => 'a.jpg',
          'quotedMessageId' => 'wamid.2'
        )
      )
      expect(captured.body).not_to have_key('phone')
      expect(captured.body).not_to have_key('enableTypingEffect')
    end
  end

  describe '#send_message_file' do
    let(:tmpfile) { Tempfile.new(['kirimi', '.txt']) }

    after { tmpfile.close! }

    it 'sends receiver instead of phone in the multipart body' do
      stub_request(:post, "#{base_url}/v1/send-message-file").to_return(
        status: 200,
        body:   OK.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

      resp = client.send_message_file(
        device_id: 'DEV1',
        receiver:  '628111',
        file:      tmpfile.path,
        file_name: 'notes.txt',
        message:   'caption text'
      )

      expect(resp.success?).to be true
      expect(
        a_request(:post, "#{base_url}/v1/send-message-file")
          .with { |req| req.body.include?('name="receiver"') && !req.body.include?('name="phone"') }
      ).to have_been_made.once
    end
  end

  describe '#broadcast_message' do
    it 'sends numbers as an Array and requires label' do
      captured = capture_post('/v1/broadcast-message')

      client.broadcast_message(
        device_id: 'DEV1',
        label:     'promo-juli',
        numbers:   %w[628111 628222 628333],
        message:   'Promo!'
      )

      expect(captured.body).to eq(
        auth.merge(
          'device_id' => 'DEV1',
          'label'     => 'promo-juli',
          'numbers'   => %w[628111 628222 628333],
          'message'   => 'Promo!'
        )
      )
      expect(captured.body['numbers']).to be_an(Array)
      expect(captured.body).not_to have_key('phones')
    end

    it 'does not join numbers into a comma string' do
      captured = capture_post('/v1/broadcast-message')

      client.broadcast_message(device_id: 'DEV1', label: 'x', numbers: %w[628111 628222], message: 'Hi')

      expect(captured.body['numbers']).to eq(%w[628111 628222])
    end

    it 'includes optional scheduling params' do
      captured = capture_post('/v1/broadcast-message')

      client.broadcast_message(
        device_id:            'DEV1',
        label:                'sched',
        numbers:              %w[628111],
        message:              'Later',
        delay:                60,
        delay_min:            30,
        delay_max:            3600,
        media_url:            'https://example.com/p.jpg',
        file_name:            'p.jpg',
        started_at:           '2026-01-01T00:00:00Z',
        enable_typing_effect: true,
        typing_speed_ms:      200
      )

      expect(captured.body).to include(
        'delay'              => 60,
        'delayMin'           => 30,
        'delayMax'           => 3600,
        'media_url'          => 'https://example.com/p.jpg',
        'fileName'           => 'p.jpg',
        'started_at'         => '2026-01-01T00:00:00Z',
        'enableTypingEffect' => true,
        'typingSpeedMs'      => 200
      )
    end
  end

  # --- WABA ---

  describe '#send_waba_message' do
    it 'sends waba_id, to and template_name' do
      captured = capture_post('/v1/waba/send-message')

      client.send_waba_message(
        waba_id:       'WABA1',
        to:            '628111',
        template_name: 'order_confirmation'
      )

      expect(captured.body).to eq(
        auth.merge('waba_id' => 'WABA1', 'to' => '628111', 'template_name' => 'order_confirmation')
      )
      expect(captured.body).not_to have_key('device_id')
      expect(captured.body).not_to have_key('phone')
    end

    it 'includes variables, header and buttons' do
      captured = capture_post('/v1/waba/send-message')

      client.send_waba_message(
        waba_id:       'WABA1',
        to:            '628111',
        template_name: 'promo',
        variables:     %w[Alice 100],
        header:        { 'type' => 'text', 'text' => 'Hi' },
        buttons:       [{ 'type' => 'url', 'url' => 'https://x.test' }]
      )

      expect(captured.body['variables']).to eq(%w[Alice 100])
      expect(captured.body['header']).to eq('type' => 'text', 'text' => 'Hi')
      expect(captured.body['buttons']).to eq([{ 'type' => 'url', 'url' => 'https://x.test' }])
    end

    it 'omits optional fields when nil' do
      captured = capture_post('/v1/waba/send-message')

      client.send_waba_message(waba_id: 'WABA1', to: '628111', template_name: 't')

      expect(captured.body.keys).to contain_exactly('user_code', 'secret', 'waba_id', 'to', 'template_name')
    end
  end

  describe '#waba_reply' do
    it 'sends waba_id, to and the message object' do
      captured = capture_post('/v1/waba/messages/reply')

      client.waba_reply(waba_id: 'WABA1', to: '628111', message: { 'type' => 'text', 'text' => 'halo' })

      expect(captured.body).to eq(
        auth.merge('waba_id' => 'WABA1', 'to' => '628111',
                   'message' => { 'type' => 'text', 'text' => 'halo' })
      )
    end
  end

  describe '#waba_conversations' do
    it 'sends no pagination params when omitted' do
      captured = capture_post('/v1/waba/conversations')

      client.waba_conversations

      expect(captured.body).to eq(auth)
    end

    it 'sends limit and page when provided' do
      captured = capture_post('/v1/waba/conversations')

      client.waba_conversations(limit: 25, page: 2)

      expect(captured.body).to eq(auth.merge('limit' => 25, 'page' => 2))
    end
  end

  describe '#waba_templates_sync' do
    it 'sends waba_id' do
      captured = capture_post('/v1/waba/templates/sync')

      client.waba_templates_sync(waba_id: 'WABA1')

      expect(captured.body).to eq(auth.merge('waba_id' => 'WABA1'))
    end
  end

  describe '#waba_send_otp' do
    it 'sends waba_id, to and template_name' do
      captured = capture_post('/v1/waba/send-otp')

      client.waba_send_otp(waba_id: 'WABA1', to: '628111', template_name: 'auth_otp')

      expect(captured.body).to eq(
        auth.merge('waba_id' => 'WABA1', 'to' => '628111', 'template_name' => 'auth_otp')
      )
    end
  end

  describe '#waba_verify_otp' do
    it 'sends waba_id, to and otp_code' do
      captured = capture_post('/v1/waba/verify-otp')

      client.waba_verify_otp(waba_id: 'WABA1', to: '628111', otp_code: '123456')

      expect(captured.body).to eq(
        auth.merge('waba_id' => 'WABA1', 'to' => '628111', 'otp_code' => '123456')
      )
    end
  end

  # --- Devices ---

  describe '#create_device' do
    it 'sends package_id only' do
      captured = capture_post('/v1/create-device')

      client.create_device(package_id: 'PKG1')

      expect(captured.body).to eq(auth.merge('package_id' => 'PKG1'))
    end

    it 'sends voucher_code when provided' do
      captured = capture_post('/v1/create-device')

      client.create_device(package_id: 7, voucher_code: 'PROMO10')

      expect(captured.body).to eq(auth.merge('package_id' => 7, 'voucher_code' => 'PROMO10'))
    end
  end

  describe '#connect_device' do
    it 'sends device_id' do
      captured = capture_post('/v1/connect-device')

      client.connect_device(device_id: 'DEV1')

      expect(captured.body).to eq(auth.merge('device_id' => 'DEV1'))
    end
  end

  describe '#renew_device' do
    it 'sends device_id and package_id' do
      captured = capture_post('/v1/renew-device')

      client.renew_device(device_id: 'DEV1', package_id: 'PKG1')

      expect(captured.body).to eq(auth.merge('device_id' => 'DEV1', 'package_id' => 'PKG1'))
    end

    it 'sends voucher_code when provided' do
      captured = capture_post('/v1/renew-device')

      client.renew_device(device_id: 'DEV1', package_id: 'PKG1', voucher_code: 'VOUCH')

      expect(captured.body).to eq(
        auth.merge('device_id' => 'DEV1', 'package_id' => 'PKG1', 'voucher_code' => 'VOUCH')
      )
    end
  end

  describe '#list_devices' do
    it 'sends no pagination params when omitted' do
      captured = capture_post('/v1/list-devices')

      client.list_devices

      expect(captured.body).to eq(auth)
    end

    it 'sends page and limit when provided' do
      captured = capture_post('/v1/list-devices')

      client.list_devices(page: 3, limit: 50)

      expect(captured.body).to eq(auth.merge('page' => 3, 'limit' => 50))
    end
  end

  describe '#device_status' do
    it 'sends device_id' do
      captured = capture_post('/v1/device-status')

      client.device_status(device_id: 'DEV1')

      expect(captured.body).to eq(auth.merge('device_id' => 'DEV1'))
    end
  end

  describe '#device_status_enhanced' do
    it 'sends device_id' do
      captured = capture_post('/v1/device-status-enhanced')

      client.device_status_enhanced(device_id: 'DEV1')

      expect(captured.body).to eq(auth.merge('device_id' => 'DEV1'))
    end
  end

  # --- Contacts ---

  describe '#save_contact' do
    it 'sends nama and nomor (never name/phone)' do
      captured = capture_post('/v1/save-contact')

      client.save_contact(nama: 'Budi', nomor: '628111')

      expect(captured.body).to eq(auth.merge('nama' => 'Budi', 'nomor' => '628111'))
      expect(captured.body).not_to have_key('name')
      expect(captured.body).not_to have_key('phone')
    end

    it 'sends device_id when provided' do
      captured = capture_post('/v1/save-contact')

      client.save_contact(nama: 'Budi', nomor: '628111', device_id: 'DEV1')

      expect(captured.body).to eq(
        auth.merge('nama' => 'Budi', 'nomor' => '628111', 'device_id' => 'DEV1')
      )
    end
  end

  describe '#save_contacts_bulk' do
    it 'sends contacts as an array of nama/nomor' do
      captured = capture_post('/v1/save-contacts-bulk')

      client.save_contacts_bulk(
        contacts: [{ nama: 'Budi', nomor: '628111' }, { nama: 'Ani', nomor: '628222' }]
      )

      expect(captured.body).to eq(
        auth.merge(
          'contacts' => [{ 'nama' => 'Budi', 'nomor' => '628111' },
                         { 'nama' => 'Ani', 'nomor' => '628222' }]
        )
      )
      expect(captured.body['contacts']).to be_an(Array)
    end

    it 'sends device_id when provided' do
      captured = capture_post('/v1/save-contacts-bulk')

      client.save_contacts_bulk(contacts: [{ nama: 'Budi', nomor: '628111' }], device_id: 'DEV1')

      expect(captured.body['device_id']).to eq('DEV1')
    end
  end

  # --- OTP v1 ---

  describe '#generate_otp' do
    it 'sends snake_case otp_length/otp_type plus camelCase custom text fields' do
      captured = capture_post('/v1/generate-otp')

      client.generate_otp(
        device_id:          'DEV1',
        phone:              '628111',
        otp_length:         6,
        otp_type:           'numeric',
        custom_otp_text:    'Kirimi',
        custom_otp_message: 'Your OTP is {otp}'
      )

      expect(captured.body).to eq(
        auth.merge(
          'device_id'        => 'DEV1',
          'phone'            => '628111',
          'otp_length'       => 6,
          'otp_type'         => 'numeric',
          'customOtpText'    => 'Kirimi',
          'customOtpMessage' => 'Your OTP is {otp}'
        )
      )
      expect(captured.body).not_to have_key('otpLength')
      expect(captured.body).not_to have_key('otpType')
    end

    it 'includes typing effect params when provided' do
      captured = capture_post('/v1/generate-otp')

      client.generate_otp(device_id: 'DEV1', phone: '628111',
                          enable_typing_effect: true, typing_speed_ms: 300)

      expect(captured.body).to include('enableTypingEffect' => true, 'typingSpeedMs' => 300)
    end

    it 'omits optional fields when nil' do
      captured = capture_post('/v1/generate-otp')

      client.generate_otp(device_id: 'DEV1', phone: '628111')

      expect(captured.body).to eq(auth.merge('device_id' => 'DEV1', 'phone' => '628111'))
    end
  end

  describe '#validate_otp' do
    it 'sends device_id, phone and otp' do
      captured = capture_post('/v1/validate-otp')

      client.validate_otp(device_id: 'DEV1', phone: '628111', otp: '123456')

      expect(captured.body).to eq(
        auth.merge('device_id' => 'DEV1', 'phone' => '628111', 'otp' => '123456')
      )
    end
  end

  # --- OTP v2 ---

  describe '#send_otp_v2' do
    it 'supports method whatsapp with app_name only' do
      captured = capture_post('/v2/otp/send')

      client.send_otp_v2(phone: '628111', method: 'whatsapp', app_name: 'MyApp')

      expect(captured.body).to eq(
        auth.merge('phone' => '628111', 'method' => 'whatsapp', 'app_name' => 'MyApp')
      )
    end

    it 'supports method device with device_id and custom_message' do
      captured = capture_post('/v2/otp/send')

      client.send_otp_v2(
        phone:          '628111',
        method:         'device',
        device_id:      'DEV1',
        custom_message: 'Your OTP is {{otp}}'
      )

      expect(captured.body).to eq(
        auth.merge('phone' => '628111', 'method' => 'device', 'device_id' => 'DEV1',
                   'custom_message' => 'Your OTP is {{otp}}')
      )
      expect(captured.body).not_to have_key('waba_id')
    end

    it 'supports method waba_user with waba_id and template_name' do
      captured = capture_post('/v2/otp/send')

      client.send_otp_v2(
        phone:         '628111',
        method:        'waba_user',
        waba_id:       'WABA1',
        template_name: 'auth_otp'
      )

      expect(captured.body).to eq(
        auth.merge('phone' => '628111', 'method' => 'waba_user', 'waba_id' => 'WABA1',
                   'template_name' => 'auth_otp')
      )
      expect(captured.body).not_to have_key('device_id')
      expect(captured.body).not_to have_key('template_code')
    end

    it 'sends only phone when method is omitted' do
      captured = capture_post('/v2/otp/send')

      client.send_otp_v2(phone: '628111')

      expect(captured.body).to eq(auth.merge('phone' => '628111'))
    end
  end

  describe '#verify_otp_v2' do
    it 'sends phone and otp_code' do
      captured = capture_post('/v2/otp/verify')

      client.verify_otp_v2(phone: '628111', otp_code: '123456')

      expect(captured.body).to eq(auth.merge('phone' => '628111', 'otp_code' => '123456'))
    end
  end

  # --- OTP Reverse ---

  describe '#otp_reverse_create' do
    it 'sends required phone and device_id' do
      captured = capture_post('/v2/otp-reverse/create')

      client.otp_reverse_create(phone: '628111', device_id: 'DEV1')

      expect(captured.body).to eq(auth.merge('phone' => '628111', 'device_id' => 'DEV1'))
    end

    it 'sends every optional field when provided' do
      captured = capture_post('/v2/otp-reverse/create')

      client.otp_reverse_create(
        phone:           '628111',
        device_id:       'DEV1',
        app_name:        'MyApp',
        callback_url:    'https://cb.test/hook',
        custom_message:  'Kirim {{token}} dari {{phone}}',
        success_message: 'Berhasil',
        failure_message: 'Gagal'
      )

      expect(captured.body).to eq(
        auth.merge(
          'phone'           => '628111',
          'device_id'       => 'DEV1',
          'app_name'        => 'MyApp',
          'callback_url'    => 'https://cb.test/hook',
          'custom_message'  => 'Kirim {{token}} dari {{phone}}',
          'success_message' => 'Berhasil',
          'failure_message' => 'Gagal'
        )
      )
    end
  end

  describe '#otp_reverse_status' do
    it 'sends token' do
      captured = capture_post('/v2/otp-reverse/status')

      client.otp_reverse_status(token: '01HZZTOKEN')

      expect(captured.body).to eq(auth.merge('token' => '01HZZTOKEN'))
    end
  end

  # --- Packages & Deposits ---

  describe '#list_packages' do
    it 'sends only auth' do
      captured = capture_post('/v1/list-packages')

      resp = client.list_packages

      expect(captured.body).to eq(auth)
      expect(resp.success?).to be true
    end
  end

  describe '#create_deposit' do
    it 'sends nominal' do
      captured = capture_post('/v1/create-deposit')

      client.create_deposit(nominal: 50_000)

      expect(captured.body).to eq(auth.merge('nominal' => 50_000))
    end
  end

  describe '#deposit_status' do
    it 'sends ref' do
      captured = capture_post('/v1/deposit-status')

      client.deposit_status(ref: 'DEP123')

      expect(captured.body).to eq(auth.merge('ref' => 'DEP123'))
    end
  end

  describe '#cancel_deposit' do
    it 'sends ref' do
      captured = capture_post('/v1/cancel-deposit')

      client.cancel_deposit(ref: 'DEP123')

      expect(captured.body).to eq(auth.merge('ref' => 'DEP123'))
    end
  end

  describe '#list_deposits' do
    it 'sends no params when omitted' do
      captured = capture_post('/v1/list-deposits')

      client.list_deposits

      expect(captured.body).to eq(auth)
    end

    it 'sends page, limit and status when provided' do
      captured = capture_post('/v1/list-deposits')

      client.list_deposits(page: 1, limit: 10, status: 'unpaid')

      expect(captured.body).to eq(auth.merge('page' => 1, 'limit' => 10, 'status' => 'unpaid'))
    end
  end

  # --- User ---

  describe '#user_info' do
    it 'sends only auth and wraps the response' do
      captured = capture_post(
        '/v1/user-info',
        response_body: {
          'success' => true,
          'data'    => { 'name' => 'John Doe', 'email' => 'john@example.com' },
          'message' => 'OK'
        }
      )

      resp = client.user_info

      expect(captured.body).to eq(auth)
      expect(resp).to be_a(Kirimi::Response)
      expect(resp.success).to be true
      expect(resp.success?).to be true
      expect(resp.data['name']).to eq('John Doe')
      expect(resp.raw).to be_a(Hash)
      expect(resp.raw['success']).to be true
    end
  end

  # --- Error handling ---

  describe 'error handling' do
    it 'raises ApiError with status_code 401 on 401' do
      stub_post_exact(
        '/v1/user-info',
        auth,
        response_body: { 'success' => false, 'message' => 'Unauthorized' },
        status: 401
      )

      expect { client.user_info }.to raise_error(Kirimi::ApiError) do |err|
        expect(err.status_code).to eq(401)
        expect(err.message).to eq('Unauthorized')
        expect(err).to be_a(Kirimi::Error)
      end
    end

    it 'raises ApiError with status_code 402 when balance is insufficient' do
      stub_post_exact(
        '/v2/otp/send',
        auth.merge('phone' => '628111', 'method' => 'whatsapp'),
        response_body: { 'success' => false, 'message' => 'Insufficient balance' },
        status: 402
      )

      expect { client.send_otp_v2(phone: '628111', method: 'whatsapp') }
        .to raise_error(Kirimi::ApiError) { |err| expect(err.status_code).to eq(402) }
    end

    it 'raises ApiError with status_code 500 on server error' do
      stub_post_exact(
        '/v1/list-devices',
        auth,
        response_body: { 'success' => false, 'message' => 'Internal Server Error' },
        status: 500
      )

      expect { client.list_devices }.to raise_error(Kirimi::ApiError) do |err|
        expect(err.status_code).to eq(500)
      end
    end

    it 'exposes the parsed body on the error' do
      stub_post_exact(
        '/v1/user-info',
        auth,
        response_body: { 'success' => false, 'message' => 'Unauthorized' },
        status: 401
      )

      expect { client.user_info }.to raise_error(Kirimi::ApiError) do |err|
        expect(err.response_data).to eq('success' => false, 'message' => 'Unauthorized')
      end
    end

    it 'raises NetworkError when the connection fails' do
      stub_request(:post, "#{base_url}/v1/user-info").to_raise(SocketError.new('getaddrinfo failed'))

      expect { client.user_info }.to raise_error(Kirimi::NetworkError, /Network error/)
    end
  end
end
