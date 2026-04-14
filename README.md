# Kirimi Ruby SDK

[![Gem Version](https://badge.fury.io/rb/kirimi.svg)](https://badge.fury.io/rb/kirimi)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Official Ruby SDK for the [Kirimi WhatsApp API](https://kirimi.id). Zero runtime dependencies — uses only Ruby's built-in `net/http`.

## Installation

Add to your Gemfile:

```ruby
gem 'kirimi'
```

Then run:

```bash
bundle install
```

Or install directly:

```bash
gem install kirimi
```

## Quick Start

```ruby
require 'kirimi'

client = Kirimi::Client.new(
  user_code: 'YOUR_USER_CODE',
  secret:    'YOUR_SECRET'
)

resp = client.send_message(
  device_id: 'YOUR_DEVICE_ID',
  phone:     '628111222333',
  message:   'Hello from Kirimi!'
)

puts resp.success?  # => true
puts resp.message   # => "Message sent"
puts resp.data      # => { ... }
```

## Constructor

```ruby
Kirimi::Client.new(
  user_code: 'YOUR_USER_CODE',   # required
  secret:    'YOUR_SECRET',      # required
  base_url:  'https://api.kirimi.id',  # optional, default
  timeout:   30                  # optional, seconds
)
```

## All Methods

### WhatsApp Unofficial

```ruby
# Send text/media message
client.send_message(device_id:, phone:, message:, media_url: nil)

# Send file via multipart (accepts File, StringIO, or file path string)
client.send_message_file(device_id:, phone:, file:, file_name:, message: nil)

# Send message without typing indicator
client.send_message_fast(device_id:, phone:, message:, media_url: nil)
```

### WABA (WhatsApp Business API)

```ruby
client.send_waba_message(device_id:, phone:, message:)
```

### Devices

```ruby
client.list_devices
client.device_status(device_id:)
client.device_status_enhanced(device_id:)
```

### User

```ruby
client.user_info
```

### Contacts

```ruby
client.save_contact(phone:, name: nil, email: nil)
```

### OTP (V1)

```ruby
# Generate & send OTP
client.generate_otp(
  device_id:,
  phone:,
  otp_length:        6,        # optional
  otp_type:          'numeric', # optional: numeric, alphabetic, alphanumeric
  custom_otp_message: nil      # optional
)

# Validate OTP
client.validate_otp(device_id:, phone:, otp:)
```

### OTP (V2)

```ruby
# Send OTP via WABA template or device
client.send_otp_v2(
  phone:,
  device_id:,
  method:        'device', # optional: device, waba
  app_name:      'MyApp',  # optional
  template_code: nil,      # optional, for waba method
  custom_message: nil      # optional, for device method
)

# Verify OTP
client.verify_otp_v2(phone:, otp_code:)
```

### Broadcast

```ruby
# phones accepts String or Array (Array auto-joined with comma)
client.broadcast_message(
  device_id:,
  phones:   ['628111', '628222', '628333'],
  message:  'Promo!',
  delay:    2  # optional, seconds between messages
)
```

### Deposits

```ruby
client.list_deposits(status: nil)  # status: nil, 'paid', 'unpaid', 'expired'
client.list_packages
```

## Response Object

All methods return a `Kirimi::Response` instance:

```ruby
resp = client.send_message(device_id: 'DEV', phone: '628xxx', message: 'hi')

resp.success?  # => true / false (boolean method)
resp.success   # => true / false (raw value)
resp.data      # => Hash or nil
resp.message   # => String
resp.raw       # => full parsed Hash
```

## Error Handling

```ruby
begin
  resp = client.send_message(device_id: 'DEV', phone: '628xxx', message: 'hi')
rescue Kirimi::ApiError => e
  puts e.status_code    # => 401
  puts e.message        # => "Unauthorized"
  puts e.response_data  # => parsed response body
rescue Kirimi::NetworkError => e
  puts "Network problem: #{e.message}"
rescue Kirimi::Error => e
  puts "SDK error: #{e.message}"
end
```

## Rails Integration

### Application configuration

```ruby
# config/initializers/kirimi.rb
KIRIMI_CLIENT = Kirimi::Client.new(
  user_code: ENV.fetch('KIRIMI_USER_CODE'),
  secret:    ENV.fetch('KIRIMI_SECRET')
)
```

### Controller example

```ruby
class NotificationsController < ApplicationController
  def send_otp
    resp = KIRIMI_CLIENT.generate_otp(
      device_id: params[:device_id],
      phone:     params[:phone],
      otp_length: 6,
      otp_type:   'numeric'
    )

    if resp.success?
      render json: { sent: true }
    else
      render json: { sent: false, error: resp.message }, status: :unprocessable_entity
    end
  rescue Kirimi::ApiError => e
    render json: { error: e.message }, status: e.status_code
  end
end
```

### Background Job example

```ruby
class SendWhatsAppJob < ApplicationJob
  queue_as :default

  def perform(device_id, phone, message)
    KIRIMI_CLIENT.send_message(device_id: device_id, phone: phone, message: message)
  rescue Kirimi::ApiError, Kirimi::NetworkError => e
    Rails.logger.error "[Kirimi] #{e.class}: #{e.message}"
    raise  # re-raise to trigger job retry
  end
end
```

## License

MIT — see [LICENSE](LICENSE).
