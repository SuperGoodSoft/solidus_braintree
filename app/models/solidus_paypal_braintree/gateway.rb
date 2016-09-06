require 'braintree'

module SolidusPaypalBraintree
  class Gateway < ::Spree::PaymentMethod
    TOKEN_GENERATION_DISABLED_MESSAGE = 'Token generation is disabled.' \
      ' To re-enable set the `token_generation_enabled` preference on the' \
      ' gateway to `true`.'.freeze

    PAYPAL_OPTIONS = {
      store_in_vault_on_success: true,
      submit_for_settlement: true
    }.freeze

    PAYPAL_AUTHORIZE_OPTIONS = {
      store_in_vault_on_success: true
    }.freeze

    # This is useful in feature tests to avoid rate limited requests from
    # Braintree
    preference(:client_sdk_enabled, :boolean, default: true)

    preference(:token_generation_enabled, :boolean, default: true)

    preference(:merchant_id, :string, default: nil)

    def payment_source_class
      Source
    end

    # Create a payment and submit it for settlement all at once.
    #
    # @api public
    # @param money_cents [Number, String] amount to authorize
    # @param source [Source] payment source
    # @return [Response]
    def purchase(money_cents, source, _gateway_options)
      result = ::Braintree::Transaction.sale(
        amount: dollars(money_cents),
        payment_method_nonce: source.nonce,
        options: PAYPAL_OPTIONS
      )

      Response.build(result)
    end

    # Authorize a payment to be captured later.
    #
    # @api public
    # @param money_cents [Number, String] amount to authorize
    # @param source [Source] payment source
    # @return [Response]
    def authorize(money_cents, source, _gateway_options)
      result = ::Braintree::Transaction.sale(
        amount: dollars(money_cents),
        payment_method_nonce: source.nonce,
        options: PAYPAL_AUTHORIZE_OPTIONS
      )

      Response.build(result)
    end

    # Collect funds from an authorized payment.
    #
    # @api public
    # @param money_cents [Number, String]
    #   amount to capture (partial settlements are supported by the gateway)
    # @param response_code [String] the transaction id of the payment to capture
    # @return [Response]
    def capture(money_cents, response_code, _gateway_options)
      result = Braintree::Transaction.submit_for_settlement(
        response_code,
        dollars(money_cents)
      )
      Response.build(result)
    end

    # Used to refeund a customer for an already settled transaction.
    #
    # @api public
    # @param money_cents [Number, String] amount to refund
    # @param response_code [String] the transaction id of the payment to refund
    # @return [Response]
    def credit(money_cents, _source, response_code, _gateway_options)
      result = Braintree::Transaction.refund(
        response_code,
        dollars(money_cents)
      )
      Response.build(result)
    end

    # Used to cancel a transaction before it is settled.
    #
    # @api public
    # @param response_code [String] the transaction id of the payment to void
    # @return [Response]
    def void(response_code, _source, _gateway_options)
      result = Braintree::Transaction.void(response_code)
      Response.build(result)
    end

    def create_profile(_payment)
    end

    # @return [String]
    #   The token that should be used along with the Braintree js-client sdk.
    #
    #   returns an error message if `preferred_token_generation_enabled` is
    #   set to false.
    #
    # @example
    #   <script>
    #     var token = #{Spree::Braintree::Gateway.first!.generate_token}
    #
    #     braintree.client.create(
    #       {
    #         authorization: token
    #       },
    #       function(clientError, clientInstance) {
    #         ...
    #       }
    #     );
    #   </script>
    def generate_token
      return TOKEN_GENERATION_DISABLED_MESSAGE unless preferred_token_generation_enabled
      ::Braintree::ClientToken.generate
    end

    def payment_profiles_supported?
      true
    end

    private

    def dollars(cents)
      Money.new(cents).dollars
    end
  end
end
