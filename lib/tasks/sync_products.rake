namespace :sync do
  desc "Synchronize products from CSV file to Shopify store"
  task products: :environment do
    begin
      csv_path = Rails.root.join("data", "import", "products.csv")
      namespace = "max_mustermann"

      unless File.exist?(csv_path)
        message = "CSV file not found at #{csv_path}. Please ensure the file exists."
        puts "\n⚠ #{message}"
        Rails.logger.error message
        raise message
      end

      puts "\nStarting product synchronization from #{csv_path}"
      Rails.logger.info "Starting product synchronization from #{csv_path}"

      service = ShopifyProductSyncService.new
      stats = service.sync(csv_path, namespace: namespace)

      Rails.logger.info "Synchronization completed successfully!"
      Rails.logger.info "Summary:"
      Rails.logger.info "  Created: #{stats[:created]} products"
      Rails.logger.info "  Updated: #{stats[:updated]} products"
      Rails.logger.info "  Errors: #{stats[:errors]} products"
    rescue StandardError => e
      message = "Synchronization failed: #{e.message}"
      puts "\n❌ #{message}"
      Rails.logger.error message
      Rails.logger.error e.backtrace.join("\n") if e.backtrace
      raise
    end
  end
end
