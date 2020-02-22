
require "http"
require "memoist"

module Rencrypt
  class FloatingIp
    class IpNotFoundError < StandardError; end
    class ServerNotFoundError < StandardError; end

    extend Memoist

    attr_reader :ip, :token

    def initialize(ip:, token:)
      @ip = ip
      @token = token
    end

    memoize def server_name
      response = http.get("#{base_url}/servers/#{server_id}")
      response.parse.dig("server", "name") || raise(ServerNotFound, "Server not found")
    end

    private

    memoize def server_id
      raise(IpNotFoundError, "Floating IP #{ip} not found") unless floating_ip

      floating_ip["server"]
    end

    memoize def floating_ip
      floating_ips.detect { |floating_ip| floating_ip["ip"] == ip }
    end

    memoize def floating_ips
      response = http.get("#{base_url}/floating_ips")
      response.parse["floating_ips"]
    end

    private

    memoize def http
      HTTP.auth("Bearer #{token}")
    end

    def base_url
      "https://api.hetzner.cloud/v1"
    end
  end
end
