
require "openssl"
require "acme-client"
require "logger"
require "fileutils"
require "memoist"

require "rencrypt/http_solver"
require "rencrypt/dns_solver"

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

    def update_dns(aws_settings)
      with_scripts { update_dns!(aws_settings) }
    end

    def update_http
      with_scripts { update_http! }
    end

    def exists?
      File.exists?(certificate_path)
    end

    def write(private_key:, certificate:)
      write_file(private_key_path, private_key)
      write_file(certificate_path, certificate)
      write_file(full_path, [certificate, private_key].join("\n"))
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

    def update_http!
      order = new_order
      challenge = order.authorizations.first.http

      solver = HttpSolver.new(
        path: challenge.filename,
        content_type: challenge.content_type,
        file_content: challenge.file_content,
        logger: logger
      )

      solver.solve

      begin
        checkout(challenge, order)
      ensure
        solver.cleanup
      end
    end

    def update_dns!(aws_region:, aws_access_key:, aws_secret_key:)
      order = new_order
      challenge = order.authorizations.first.dns

      solver = DnsSolver.new(
        aws_region: aws_region,
        aws_access_key: aws_access_key,
        aws_secret_key: aws_secret_key,
        common_name: common_name,
        record_name: challenge.record_name,
        record_type: challenge.record_type,
        record_content: challenge.record_content,
        logger: logger
      )

      solver.solve

      begin
        checkout(challenge, order)
      ensure
        solver.cleanup
      end
    end

    def new_order
      acme_client.new_order(identifiers: [common_name])
    end

    def checkout(challenge, order)
      challenge.request_validation

      while challenge.status == "pending"
        sleep 1

        challenge.reload
      end

      raise("Challenge can't be solved") if challenge.status != "valid"

      logger.info "challenge solved"

      order.finalize(csr: Acme::Client::CertificateRequest.new(private_key: private_key, subject: { common_name: common_name }))

      while order.status == "processing"
        sleep 1

        challenge.reload
      end

      logger.info "order fulfilled"

      write(private_key: private_key, certificate: order.certificate)
    end

    memoize def acme_client
      Acme::Client.new(private_key: user_key, directory: "https://acme-staging-v02.api.letsencrypt.org/directory").tap do |client|
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
          write_file(path, key.to_s)
        end
      end
    end

    def write_file(path, content)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, content)
    end
  end
end
