
require File.expand_path("../spec_helper", __dir__)
require "redis"

RSpec.describe Rencrypt::RedisStore do
  subject { described_class.new(redis) }

  let(:redis) { Redis.new }

  after { redis.flushdb }

  describe "#write" do
    it "writes the private key and certficate at the correct keys" do
      subject.write(common_name: "example.com", private_key: "some private key", certificate: "some certificate")

      expect(redis.hgetall("letsencrypt")).to eq({
        "example.com/private_key" => "some private key",
        "example.com/certificate" => "some certificate"
      })
    end
  end

  describe "#read_private_key" do
    it "returns the private key" do
      subject.write(common_name: "example.com", private_key: "some private key", certificate: "some certificate")

      expect(subject.read_private_key("example.com")).to eq("some private key")
    end

    it "raises if the private key is missing" do
      expect { subject.read_private_key("example.com") }.to raise_error(described_class::PrivateKeyMissingError)
    end
  end

  describe "#read_certificate" do
    it "returns the certificate" do
      subject.write(common_name: "example.com", private_key: "some private key", certificate: "some certificate")

      expect(subject.read_certificate("example.com")).to eq("some certificate")
    end

    it "raises if the certifiate is missing" do
      expect { subject.read_certificate("example.com") }.to raise_error(described_class::CertificateMissingError)
    end
  end
end
