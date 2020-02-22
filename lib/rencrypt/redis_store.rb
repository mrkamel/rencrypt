
module Rencrypt
  class RedisStore
    class PrivateKeyMissingError < StandardError; end
    class CertificateMissingError < StandardError; end

    attr_reader :redis

    def initialize(redis)
      @redis = redis
    end

    def write(common_name:, private_key:, certificate:)
      redis.multi do
        redis.hset("letsencrypt", "#{common_name}/private_key", private_key)
        redis.hset("letsencrypt", "#{common_name}/certificate", certificate)
      end
    end

    def read_private_key(common_name)
      redis.hget("letsencrypt", "#{common_name}/private_key") || raise(PrivateKeyMissingError)
    end

    def read_certificate(common_name)
      redis.hget("letsencrypt", "#{common_name}/certificate") || raise(CertificateMissingError)
    end
  end
end
