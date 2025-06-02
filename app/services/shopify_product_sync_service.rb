class ShopifyProductSyncService
  include ShopifyServiceBase

  BATCH_SIZE = 250
  REQUIRED_FIELDS = [ "Title", "Variant SKU", "Variant Price" ].freeze

  def sync(csv_path, namespace: nil)
    @csv_path = csv_path
    @namespace = namespace
    stats = { created: 0, updated: 0, errors: 0 }
    total_rows = count_csv_rows

    Rails.logger.info "Starting product sync for #{total_rows} products..."

    CSV.foreach(@csv_path, headers: true).with_index(1) do |row, index|
      begin
        validate_row!(row)
        sync_product(row)
        stats[:created] += 1 if @product_created
        stats[:updated] += 1 if @product_updated
        log_progress(index, total_rows)
      rescue StandardError => e
        handle_error(e, row, stats)
      end
    end

    log_final_stats(stats)
    stats
  end

  private

  def count_csv_rows
    CSV.read(@csv_path, headers: true).count
  end

  def sync_product(row)
    @product_created = @product_updated = false
    product = find_product_by_sku(row["Variant SKU"])
    input = build_product_input(row)

    identifier = product&.dig("id").present? ? { id: product["id"] } : nil
    response = execute_graphql_query(Mutations::ProductMutation.set, { identifier: identifier, input: input })
    handle_graphql_errors(response, [ [ "data", "productSet", "userErrors" ] ])

    product_id = response.dig("data", "productSet", "product", "id")
    if product_id
      @product_updated = product.present?
      @product_created = !product.present?
      set_metafield(product_id, row["Estimated Delivery Date in Days"])
    end
  end

  def log_progress(current, total)
    return unless (current % 10).zero?

    percentage = ((current.to_f / total) * 100).round(2)
    Rails.logger.info "Progress: #{percentage}% (#{current}/#{total} products processed)"
  end

  def handle_error(error, row, stats)
    stats[:errors] += 1
    error_message = "Error processing row #{row['Variant SKU']}: #{error.message}"
    Rails.logger.error error_message
  end

  def log_final_stats(stats)
    summary = [
      "\n========== Product Sync Summary ==========",
      "✓ Successfully processed #{stats[:created] + stats[:updated]} products",
      "  • #{stats[:created]} products created",
      "  • #{stats[:updated]} products updated",
      stats[:errors] > 0 ? "⚠ #{stats[:errors]} errors encountered" : "✓ No errors encountered",
      "======================================\n"
    ]

    summary.each do |line|
      puts line
      Rails.logger.info line
    end
  end

  # Product Operations
  def find_product_by_sku(sku)
    variables = { query: "sku:#{sku}" }
    response = execute_graphql_query(Queries::ProductQuery.find_by_sku, variables)
    response.dig("data", "products", "edges", 0, "node")
  end

  def set_metafield(product_id, delivery_days)
    return unless delivery_days.present?

    variables = {
      metafields: [ {
        ownerId: product_id,
        namespace: @namespace,
        key: "estimated_delivery",
        type: "number_integer",
        value: delivery_days.to_i.to_s
      } ]
    }

    response = execute_graphql_query(Mutations::MetafieldMutation.set, variables)
    handle_graphql_errors(response, [ [ "data", "metafieldsSet", "userErrors" ] ])
  end

  def execute_graphql_query(query, variables)
    response = @client.query(query: query, variables: variables)
    response.body
  rescue StandardError => e
    raise SyncError, "GraphQL query failed: #{e.message}"
  end

  def handle_graphql_errors(response, allowed_errors)
    errors = []

    if response["errors"]
      errors.concat(response["errors"].map { |e| e["message"] })
    end

    if response.dig("data", "productSet", "userErrors")&.any?
      errors.concat(response.dig("data", "productSet", "userErrors").map { |e| "#{e['field']}: #{e['message']}" })
    end

    if response.dig("data", "metafieldsSet", "userErrors")&.any?
      errors.concat(response.dig("data", "metafieldsSet", "userErrors").map { |e| "#{e['field']}: #{e['message']}" })
    end

    raise SyncError, "GraphQL errors: #{errors.join(', ')}" if errors.any?
  end

  def build_product_input(row)
    {
      title: row["Title"],
      descriptionHtml: row["Body (HTML)"],
      vendor: row["Vendor"],
      productType: row["Type"],
      tags: row["Tags"]&.split(",")&.map(&:strip),
      seo: build_seo_input(row),
      variants: [ build_variant_input(row) ],
      productOptions: build_product_options(row),
      status: row["Status"]&.upcase || "DRAFT"
    }.compact
  end

  def build_product_options(row)
    options = []

    if row["Option1 Name"].present? && row["Option1 Value"].present?
      options << {
        name: row["Option1 Name"],
        values: [ { name: row["Option1 Value"] } ]
      }
    end

    if row["Option2 Name"].present? && row["Option2 Value"].present?
      options << {
        name: row["Option2 Name"],
        values: [ { name: row["Option2 Value"] } ]
      }
    end

    options.presence
  end

  def build_seo_input(row)
    return unless row["SEO Title"].present? || row["SEO Description"].present?

    {
      title: row["SEO Title"],
      description: row["SEO Description"]
    }.compact
  end

  def build_images_input(row)
    return [] unless row["Image Src"].present?

    [ {
      src: row["Image Src"],
      altText: row["Image Alt Text"]
    }.compact ]
  end

  def build_variant_input(row)
    {
      price: row["Variant Price"],
      sku: row["Variant SKU"],
      taxable: row["Variant Taxable"]&.upcase == "TRUE",
      barcode: row["Variant Barcode"],
      optionValues: build_option_values(row)
    }.compact
  end

  def build_option_values(row)
    values = []

    if row["Option1 Name"].present? && row["Option1 Value"].present?
      values << { name: row["Option1 Value"], optionName: row["Option1 Name"] }
    end

    if row["Option2 Name"].present? && row["Option2 Value"].present?
      values << { name: row["Option2 Value"], optionName: row["Option2 Name"] }
    end

    values.presence
  end

  def validate_row!(row)
    missing_fields = REQUIRED_FIELDS.select { |field| row[field].blank? }
    if missing_fields.any?
      raise ArgumentError, "Missing required fields: #{missing_fields.join(', ')}"
    end

    validate_price!(row["Variant Price"])
    validate_delivery_date!(row["Estimated Delivery Date in Days"])
  end

  def validate_price!(price)
    return if price.to_s.match?(/\A\d+(\.\d{1,2})?\z/)
    raise ArgumentError, "Invalid price format: #{price}. Expected format: 0.00"
  end

  def validate_delivery_date!(days)
    return if days.blank?
    return if days.to_s.match?(/\A\d+\z/)
    raise ArgumentError, "Invalid delivery days format: #{days}. Expected format: positive integer"
  end
end
