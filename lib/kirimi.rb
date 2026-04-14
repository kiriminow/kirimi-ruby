# frozen_string_literal: true

require_relative 'kirimi/version'
require_relative 'kirimi/errors'
require_relative 'kirimi/response'
require_relative 'kirimi/client'

# Kirimi Ruby SDK — Official client for the Kirimi WhatsApp API.
#
# Usage:
#   client = Kirimi::Client.new(user_code: 'USER', secret: 'SECRET')
#   resp   = client.send_message(device_id: 'DEV', phone: '628xxx', message: 'Hello!')
#   puts resp.success?   # => true
#   puts resp.data       # => { ... }
module Kirimi
end
