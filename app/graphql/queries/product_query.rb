module Queries
  class ProductQuery
    class << self
      def find_by_sku
        <<~GRAPHQL
          query($query: String!) {
            products(first: 1, query: $query) {
              edges {
                node {
                  id
                  title
                  handle
                  variants(first: 1) {
                    edges {
                      node {
                        id
                        sku
                      }
                    }
                  }
                }
              }
            }
          }
        GRAPHQL
      end
      def get_metafield
        <<~GRAPHQL
          query($namespace: String!, $key: String!, $id: ID!) {
            product(id: $id) {
              metafield(namespace: $namespace, key: $key) {
                value
              }
            }
          }
        GRAPHQL
      end
    end
  end
end
