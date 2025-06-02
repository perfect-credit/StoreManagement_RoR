class WebhooksController < ApplicationController
  def orders_paid
    unless webhook_verified?
      Rails.logger.error "Webhook verification failed"
      return head :unauthorized
    end

    begin
      service = OrderDeliveryDateService.new(webhook_params)
      service.process
      head :ok
    rescue OrderDeliveryDateService::ShopifyError => e
      Rails.logger.error "Shopify API Error: #{e.message}"
      head :unprocessable_entity
    rescue JSON::ParserError => e
      Rails.logger.error "Invalid JSON in webhook payload: #{e.message}"
      head :bad_request
    rescue StandardError => e
      Rails.logger.error "Error processing paid order webhook: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      head :internal_server_error
    end
  end

  private

  def webhook_params
    @webhook_params ||= begin
      request.body.rewind
      data = request.body.read
      request.body.rewind
      JSON.parse(data)
    end
  end

  def webhook_verified?
    hmac = request.headers["HTTP_X_SHOPIFY_HMAC_SHA256"]

    unless hmac.present?
      Rails.logger.error "No HMAC signature found in headers"
      return false
    end

    request.body.rewind
    data = request.body.read
    request.body.rewind

    begin
      digest = OpenSSL::HMAC.digest(
        OpenSSL::Digest.new("sha256"),
        ENV.fetch("SHOPIFY_API_SECRET"),
        data
      )

      calculated_hmac = Base64.strict_encode64(digest)
      result = ActiveSupport::SecurityUtils.secure_compare(calculated_hmac, hmac)

      unless result
        Rails.logger.error "HMAC verification failed"
        Rails.logger.error "Expected: #{calculated_hmac}"
        Rails.logger.error "Received: #{hmac}"
      end

      result
    rescue KeyError => e
      Rails.logger.error "Missing SHOPIFY_API_SECRET environment variable"
      false
    rescue StandardError => e
      Rails.logger.error "Error during webhook verification: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      false
    end
  end
end
