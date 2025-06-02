module Mutations
  class ProductMutation
    class << self
      def set
        <<~GRAPHQL
          mutation($identifier: ProductSetIdentifiers, $input: ProductSetInput!) {
            productSet(identifier: $identifier, input: $input) {
              product {
                id
                title
                handle
              }
              userErrors {
                field
                message
              }
            }
          }
        GRAPHQL
      end
    end
  end
end
