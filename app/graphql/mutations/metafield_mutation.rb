module Mutations
  class MetafieldMutation
    class << self
      def set
        <<~GRAPHQL
          mutation($metafields: [MetafieldsSetInput!]!) {
            metafieldsSet(metafields: $metafields) {
              metafields {
                id
                key
                namespace
                value
              }
              userErrors {
                field
                message
                code
              }
            }
          }
        GRAPHQL
      end
    end
  end
end
