ShopifyAPI::Context.setup(
  api_key: ENV["SHOPIFY_API_KEY"],
  api_secret_key: ENV["SHOPIFY_API_SECRET"],
  host_name: "localhost",
  is_embedded: true,
  scope: "write_products,write_metafields",
  api_version: "2025-04",
  is_private: true
)
