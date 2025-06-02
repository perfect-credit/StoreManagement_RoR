namespace :webhooks do
  desc "Subscribe to Shopify orders/paid webhook"
  task subscribe: :environment do
    begin
      service = ShopifyWebhookService.new
      webhook_id = service.subscribe_to_paid_orders
      puts "\n✓ Successfully subscribed to orders/paid webhook"
      puts "  Webhook ID: #{webhook_id}"
    rescue StandardError => e
      puts "\n❌ Failed to subscribe to webhook: #{e.message}"
      raise
    end
  end
end
