module ShopifyServiceBase
  extend ActiveSupport::Concern

  included do
    class_attribute :required_env_vars, default: %w[SHOPIFY_SHOP_NAME SHOPIFY_ACCESS_TOKEN]
  end

  class ShopifyError < StandardError; end
  class ConfigurationError < StandardError; end

  def initialize(*args)
    validate_environment_variables!
    setup_shopify_connection
  end

  private

  def validate_environment_variables!
    missing_vars = self.class.required_env_vars.select { |var| ENV[var].nil? || ENV[var].empty? }
    raise ConfigurationError, "Missing required environment variables: #{missing_vars.join(', ')}" if missing_vars.any?
  end

  def setup_shopify_connection
    @shop = "#{ENV.fetch('SHOPIFY_SHOP_NAME')}.myshopify.com"
    @token = ENV.fetch("SHOPIFY_ACCESS_TOKEN")
    setup_shopify_client
  end

  def setup_shopify_client
    session = ShopifyAPI::Auth::Session.new(shop: @shop, access_token: @token)
    @client = ShopifyAPI::Clients::Graphql::Admin.new(session: session)
  rescue StandardError => e
    raise ShopifyError, "Failed to initialize Shopify client: #{e.message}"
  end

  def client
    @client ||= setup_shopify_client
  end

  def execute_graphql_query(query, variables)
    response = client.query(query: query, variables: variables)
    response.body
  rescue StandardError => e
    raise ShopifyError, "GraphQL query failed: #{e.message}"
  end

  def handle_graphql_errors(response, error_paths = [])
    errors = []

    if response["errors"]
      errors.concat(response["errors"].map { |e| e["message"] })
    end

    error_paths.each do |path|
      if (user_errors = response.dig(*path))&.any?
        errors.concat(user_errors.map { |e| "#{e['field']}: #{e['message']}" })
      end
    end

    raise ShopifyError, "GraphQL errors: #{errors.join(', ')}" if errors.any?
  end
end
