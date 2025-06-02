module Mutations
  class FileCreateMutation
    class << self
      def set
        <<~GRAPHQL
          mutation fileCreate($files: [FileCreateInput!]!) {
            fileCreate(files: $files) {
              files {
                ... on GenericFile {
                  id
                  url
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
