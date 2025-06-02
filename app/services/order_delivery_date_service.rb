require "tempfile"

class OrderDeliveryDateService
  include ShopifyServiceBase

  class ShopifyError < StandardError; end

  METAFIELD_NAMESPACE = "max_mustermann".freeze
  METAFIELD_DELIVERY_KEY = "estimated_delivery".freeze
  METAFIELD_FILE_KEY = "delivery_dates".freeze
  JSON_MIME_TYPE = "application/json".freeze
  BATCH_SIZE = 50

  attr_reader :order

  class << self
    def process_batch(orders)
      Rails.logger.info "Processing batch of #{orders.size} orders"

      orders.each_slice(BATCH_SIZE) do |batch|
        batch.each do |order_data|
          begin
            new(order_data).process
          rescue StandardError => e
            Rails.logger.error "Failed to process order #{order_data['id']}: #{e.message}"
          end
        end
      end
    end
  end

  def initialize(order_data)
    super()
    @order = order_data
  end

  def process
    Rails.logger.tagged("Order##{order['order_number']}") do
      Rails.logger.info "Starting order processing"

      unless valid_order?
        Rails.logger.error "Invalid order data"
        return nil
      end

      delivery_dates = collect_delivery_dates
      return log_no_delivery_dates if delivery_dates.empty?

      Rails.logger.info "Found delivery dates for #{delivery_dates.length} line items"
      json_data = generate_json_data(delivery_dates)

      Rails.logger.info "Uploading JSON file"
      if (file_gid = upload_json_file(json_data))
        Rails.logger.info "Attaching metafield"
        attach_metafield(file_gid)
        Rails.logger.info "Successfully processed order"
      end
    end
  rescue StandardError => e
    Rails.logger.error "Processing failed: #{e.message}"
    raise ShopifyError, "Order processing failed: #{e.message}"
  end

  private

  def valid_order?
    return false unless order.is_a?(Hash)
    return false unless order["id"].present?
    return false unless order["order_number"].present?
    return false unless order["line_items"].is_a?(Array)
    true
  end

  def collect_delivery_dates
    delivery_dates = []

    order["line_items"].each do |item|
      delivery_date = fetch_delivery_date_for_item(item)
      delivery_dates << delivery_date if delivery_date
    end

    delivery_dates
  end

  def fetch_delivery_date_for_item(item)
    Rails.logger.info "Fetching delivery date for product #{item['product_id']} (#{item['title']})"
    delivery_date = fetch_delivery_date(item["product_id"])

    if delivery_date
      Rails.logger.info "Found delivery date: #{delivery_date} days for product #{item['product_id']}"
      {
        line_item_id: item["id"],
        product_id: item["product_id"],
        title: item["title"],
        quantity: item["quantity"],
        estimated_delivery_days: delivery_date
      }
    else
      Rails.logger.warn "No delivery date found for product #{item['product_id']} (#{item['title']})"
      nil
    end
  rescue StandardError => e
    Rails.logger.error "Error fetching delivery date for product #{item['product_id']}: #{e.message}"
    nil
  end

  def fetch_delivery_date(product_id)
    response = execute_graphql_query(Queries::ProductQuery.get_metafield, {
      namespace: METAFIELD_NAMESPACE,
      key: METAFIELD_DELIVERY_KEY,
      id: "gid://shopify/Product/#{product_id}"
    })
    response.dig("data", "product", "metafield", "value")&.to_i
  end

  def generate_json_data(delivery_dates)
    {
      order_id: order["id"],
      order_number: order["order_number"],
      created_at: order["created_at"],
      customer: {
        email: order["email"],
        name: "#{order['customer']['first_name']} #{order['customer']['last_name']}".strip
      },
      line_items: delivery_dates
    }
  end

  def upload_json_file(json_data)
    json_string = JSON.pretty_generate(json_data)
    filename = generate_filename
    # Step 1: Create staged upload
    staged_upload_variables = {
      input: [ {
        filename: filename,
        mimeType: JSON_MIME_TYPE,
        resource: "FILE",
        fileSize: json_string.bytesize.to_s
      } ]
    }
    staged_response = execute_graphql_query(Mutations::StagedUploadsCreateMutation.set, staged_upload_variables)
    handle_graphql_errors(staged_response, [ [ "data", "stagedUploadsCreate", "userErrors" ] ])
    staged_target = staged_response.dig("data", "stagedUploadsCreate", "stagedTargets", 0)

    unless staged_target
      raise ShopifyError, "Failed to get staged upload URL"
    end
    # Step 2: Create file record
    file_create_variables = {
      files: [ {
        originalSource: staged_target["resourceUrl"],
        filename: filename,
        contentType: "FILE"
      } ]
    }
    file_response = execute_graphql_query(Mutations::FileCreateMutation.set, file_create_variables)
    handle_graphql_errors(file_response, [ [ "data", "fileCreate", "userErrors" ] ])

    file_response.dig("data", "fileCreate", "files", 0, "id")
  end

  def generate_filename
    "estimated_delivery_#{order['id']}_#{Time.current.to_i}.json"
  end

  def attach_metafield(file_gid)
    variables = {
      metafields: [ {
        ownerId: order["admin_graphql_api_id"],
        namespace: METAFIELD_NAMESPACE,
        key: METAFIELD_FILE_KEY,
        type: "file_reference",
        value: file_gid
      } ]
    }

    response = execute_graphql_query(Mutations::MetafieldMutation.set, variables)
    handle_graphql_errors(response, [ [ "data", "metafieldsSet", "userErrors" ] ])
  end

  def log_no_delivery_dates
    Rails.logger.info "No delivery dates found for any line items"
    nil
  end
end
