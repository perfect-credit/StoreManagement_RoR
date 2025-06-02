module Queries
  class WebhookSubscriptionsQuery
    class << self
      def get
        <<~GRAPHQL
          query {
            webhookSubscriptions(first: 5) {
              edges {
                node {
                  id
                  topic
                  endpoint {
                    __typename
                    ... on WebhookHttpEndpoint {
                      callbackUrl
                    }
                    ... on WebhookEventBridgeEndpoint {
                      arn
                    }
                    ... on WebhookPubSubEndpoint {
                      pubSubProject
                      pubSubTopic
                    }
                  }
                }
              }
            }
          }
        GRAPHQL
      end
    end
  end
end
