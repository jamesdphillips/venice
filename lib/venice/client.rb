require 'json'
require 'net/https'
require 'uri'

module Venice
  ITUNES_PRODUCTION_RECEIPT_VERIFICATION_ENDPOINT = "https://buy.itunes.apple.com/verifyReceipt"
  ITUNES_DEVELOPMENT_RECEIPT_VERIFICATION_ENDPOINT = "https://sandbox.itunes.apple.com/verifyReceipt"

  class Client
    attr_accessor :verification_url
    attr_writer :shared_secret

    class << self
      def development(options = {})
        client = self.new(options.merge(production: false))
        client
      end

      def production(options = {})
        client = self.new(options.merge(production: true))
        client
      end
    end

    def initialize(options = {})
      options[:production] = Venice.production? unless options.key?(:production)
      
      @shared_secret = options[:secret] || Venice.shared_secret
      @verification_url = ENV['IAP_VERIFICATION_ENDPOINT']
      @verification_url ||= options[:production] ? ITUNES_PRODUCTION_RECEIPT_VERIFICATION_ENDPOINT : ITUNES_DEVELOPMENT_RECEIPT_VERIFICATION_ENDPOINT
    end

    def verify!(data, options = {})
      json = json_response_from_verifying_data(data)
      status, receipt_attributes = json['status'].to_i, json['receipt']

      case status
      when 0, 21006
        receipt = Receipt.new(receipt_attributes)
        receipt.subscription_expired = (status == 21006)
        receipt.receipt_data = data

        if latest_receipt_attributes = json['latest_receipt_info']
          receipt.latest = Receipt.new(latest_receipt_attributes)
          receipt.latest.receipt_data = json['latest_receipt']
        end

        if latest_expired_receipt_attributes = json['latest_expired_receipt_info']
          receipt.latest_expired = Receipt.new(latest_expired_receipt_attributes)
        end

        return receipt
      else
        raise Receipt::VerificationError.new(status)
      end
    end

    private

    def json_response_from_verifying_data(data)
      parameters = {
        'receipt-data' => data
      }

      parameters['password'] = @shared_secret if @shared_secret

      uri = URI(@verification_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE

      request = Net::HTTP::Post.new(uri.request_uri)
      request['Accept'] = "application/json"
      request['Content-Type'] = "application/json"
      request.body = parameters.to_json

      response = http.request(request)

      JSON.parse(response.body)
    end
  end
end
