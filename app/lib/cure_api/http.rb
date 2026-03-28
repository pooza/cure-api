require 'httparty'

module CureAPI
  class HTTP
    include Package

    RETRYABLE_ERRORS = [
      Errno::EPIPE,
      Errno::ECONNRESET,
      Errno::ECONNREFUSED,
      Errno::ETIMEDOUT,
      Net::OpenTimeout,
      Net::ReadTimeout,
      OpenSSL::SSL::SSLError,
    ].freeze

    def get(url)
      retries = 0
      begin
        response = HTTParty.get(url, timeout: config['/http/timeout/seconds'])
        raise "Bad response #{response.code}" unless response.code < 400
        return response.parsed_response
      rescue *RETRYABLE_ERRORS
        retries += 1
        raise if retries > config['/http/retry/limit']
        sleep config['/http/retry/seconds']
        retry
      end
    end
  end
end
