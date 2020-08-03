# frozen_string_literal: true

require "shopify_api"

# Updates a Request based on Shopify order web hook data
class CommitShopifyOrderJob < WebhookJob
  def perform(args)
    super
    source_order = ShopifyAPI::Session.temp(domain: ShopifyAPI::Base.site.to_s, api_version: "2020-01", token: nil) do
      ShopifyAPI::Order.new(params)
    end
    order = MostlyShopify::Order.new source_order
    order.update_request!
    @webhook.commit!(order.request_id)
  end
end