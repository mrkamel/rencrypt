
module Rencrypt
  class RedisStore
    attr_reader :redis

    def initialize(redis)
      @redis = redis
    end

    def write(common_name:, private_key:, certificate:)
      redis.multi do
        redis.hset("rencrypt", "#{common_name}/private_key", private_key)
        redis.hset("rencrypt", "#{common_name}/certificate", certificate)
      end
    end

    def read(common_name)
      private_key = redis.hget("rencrypt", "#{common_name}/private_key")
      certificate = redis.hget("rencrypt", "#{common_name}/certificate")

      return if !private_key || !certificate

      { private_key: private_key, certificate: certificate }
    end

    def with_lock(common_name, ttl:, timeout: 300)
      key = "rencrypt:lock:#{common_name}"

      timeout.times do
        if redis.set(key, 1, nx: true, ex: ttl)
          begin
            return yield
          ensure
            redis.del(key)
          end
        end

        sleep 1
      end
    end
  end
end
