
require "openssl"
require "acme-client"
require "socket"
require "logger"
require "fileutils"
require "memoist"

module Rencrypt
  class Certificate
    extend Memoist

    attr_reader :base_path, :common_name, :email, :before_script, :after_script, :logger

    def initialize(base_path:, common_name:, email:, before_script: nil, after_script: nil, logger: Logger.new("/dev/null"))
      @base_path = base_path
      @common_name = common_name
      @email = email
      @before_script = before_script
      @after_script = after_script
      @logger = logger
    end

    def update
      with_scripts { update! }
    end

    def exists?
      File.exists?(certificate_path)
    end

    def write(private_key:, certificate:)
      open(private_key_path, "w") { |stream| stream.write private_key }
      open(certificate_path, "w") { |stream| stream.write certificate }
      open(full_path, "w") { |stream| stream.write [certificate, private_key].join("\n") }
    end

    def not_after
      OpenSSL::X509::Certificate.new(File.read(certificate_path)).not_after
    end

    def read_private_key
      File.read(private_key_path)
    end

    def read_certificate
      File.read(certificate_path)
    end

    private

    def private_key_path
      File.join(base_path, common_name, "key.pem")
    end

    def certificate_path
      File.join(base_path, common_name, "crt.pem")
    end

    def full_path
      File.join(base_path, common_name, "full.pem")
    end

    def with_scripts
      if before_script
        logger.info "executing #{before_script}"

        `#{before_script}`
      end

      begin
        yield
      ensure
        if after_script
          logger.info "executing #{after_script}"

          `#{after_script}`
        end
      end
    end

    def update!
      order = acme_client.new_order(identifiers: [common_name])
      http_challenge = order.authorizations.first.http

      thread = serve(
        path: http_challenge.filename,
        content_type: http_challenge.content_type,
        file_content: http_challenge.file_content
      )

      http_challenge.request_validation

      while http_challenge.status == "pending"
        sleep 1

        http_challenge.reload
      end

      raise("Challenge can't be solved") if http_challenge.status != "valid"

      logger.info "challenge solved"

      order.finalize(csr: Acme::Client::CertificateRequest.new(private_key: private_key, subject: { common_name: common_name }))

      while order.status == "processing"
        sleep 1

        http_challenge.reload
      end

      logger.info "order fulfilled"

      write(private_key: private_key, certificate: order.certificate)

      thread.kill
    end

    def serve(path:, content_type:, file_content:)
      Thread.new do
        begin
          logger.info "starting server"

          server = TCPServer.new(80)

          loop do
            client = server.accept

            logger.info "new connection"

            line = client.gets.strip

            loop { break if client.gets.strip.empty? }

            if line.include?(path)
              client.puts "HTTP/1.1 200 OK"
              client.puts "Content-Type: #{content_type}"
              client.puts
              client.puts file_content
            else
              client.puts "HTTP/1.1 404 Not Found"
              client.puts
            end

            logger.info "response served"

            client.close
          end
        rescue => e
          logger.error(e)
        end
      end
    end

    memoize def acme_client
      Acme::Client.new(private_key: user_key, directory: "https://acme-v02.api.letsencrypt.org/directory").tap do |client|
        client.new_account(contact: "mailto:#{email}", terms_of_service_agreed: true)
      end
    end

    def private_key
      build_key(private_key_path)
    end

    def user_key
      build_key(user_key_path)
    end

    def user_key_path
      File.join(base_path, "user_key.pem")
    end

    def build_key(path)
      if File.exists?(path)
        OpenSSL::PKey::RSA.new(File.read(path))
      else
        OpenSSL::PKey::RSA.new(2048).tap do |key|
          open(path, "w") { |stream| stream.write(key.to_s) }
        end
      end
    end
  end
end
