module Mutations
  class StagedUploadsCreateMutation
    class << self
      def set
        <<~GRAPHQL
          mutation stagedUploadsCreate($input: [StagedUploadInput!]!) {
            stagedUploadsCreate(input: $input) {
              stagedTargets {
                resourceUrl
                url
                parameters {
                  name
                  value
                }
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
