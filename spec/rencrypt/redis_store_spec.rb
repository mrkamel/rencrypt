
require File.expand_path("../spec_helper", __dir__)
require "redis"

module Rencrypt
  RSpec.describe RedisStore do
    subject { described_class.new(redis) }

    let(:redis) { Redis.new }

    after { redis.flushdb }

    describe "#write" do
      it "writes the private key and certficate at the correct keys" do
        subject.write(common_name: "example.com", private_key: "some private key", certificate: "some certificate")

        expect(redis.hgetall("rencrypt")).to eq({
          "example.com/private_key" => "some private key",
          "example.com/certificate" => "some certificate"
        })
      end
    end

    describe "#read" do
      it "returns the private key and certificate" do
        subject.write(common_name: "example.com", private_key: "some private key", certificate: "some certificate")

        expect(subject.read("example.com")).to eq({
          private_key: "some private key",
          certificate: "some certificate"
        })
      end

      it "returns nil if private key or certificate is missing" do
        expect(subject.read("example.com")).to be_nil
      end
    end

    describe "#with_lock" do
      it "acquires the lock and yields" do
        subject.with_lock("example.com", ttl: 10) do
          expect(redis.get("rencrypt:lock:example.com")).to eq("1")
        end
      end

      it "removes the lock afterwards" do
        subject.with_lock("example.com", ttl: 10) do
          # nothing
        end

        expect(redis.get("rencrypt:lock:example.com")).to be_nil
      end

      it "sets expiry on the key" do
        allow(redis).to receive(:set).and_return(true)

        subject.with_lock("example.com", ttl: 10) do
          # nothing
        end

        expect(redis).to have_received(:set).with("rencrypt:lock:example.com", 1, nx: true, ex: 10)
      end
    end
  end
end
