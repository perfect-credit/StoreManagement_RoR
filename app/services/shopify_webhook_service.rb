class ShopifyWebhookService
  include ShopifyServiceBase

  def subscribe_to_paid_orders
    topic = "ORDERS_PAID"
    callback_url = "#{ENV.fetch('APP_HOST')}/webhooks/orders_paid"

    # Check if webhook already exists
    existing_webhook = find_webhook_by_topic_and_url(topic, callback_url)
    if existing_webhook
      Rails.logger.info "Webhook already exists with ID: #{existing_webhook['id']}"
      return existing_webhook["id"]
    end

    variables = {
      topic: topic,
      webhookSubscription: {
        callbackUrl: callback_url,
        format: "JSON"
      }
    }

    response = execute_graphql_query(Mutations::WebhookSubscriptionMutation.set, variables)
    handle_graphql_errors(response, [ [ "data", "webhookSubscriptionCreate", "userErrors" ] ])

    webhook_id = response.dig("data", "webhookSubscriptionCreate", "webhookSubscription", "id")
    Rails.logger.info "Successfully subscribed to ORDERS_PAID webhook with ID: #{webhook_id}"
    webhook_id
  end

  private

  def find_webhook_by_topic_and_url(topic, callback_url)
    response = execute_graphql_query(Queries::WebhookSubscriptionsQuery.get, {})
    webhook = response.dig("data", "webhookSubscriptions", "edges")&.find do |node|
      webhook = node.dig("node")
      webhook["topic"] == topic && webhook.dig("endpoint", "callbackUrl") == callback_url
    end&.dig("node")
  end
end
