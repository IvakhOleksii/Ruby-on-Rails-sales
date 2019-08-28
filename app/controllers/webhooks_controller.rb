# frozen_string_literal: true

class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :verify_shopify_webhook, only: [:orders_create], if: -> { Rails.env.production? }

  def calendly
    create_webhook source: "Calendly", source_id: params[:payload][:event][:uuid], params: calendly_params
    head :ok
  end

  def requests_create
    create_webhook source: "WordPress", source_id: nil, params: wpcf7_params
    head :ok
  end

  def orders_create
    create_webhook source: "Shopify", source_id: shopify_params["id"], params: shopify_params
    head :ok
  end

  private

  def create_webhook(args)
    Webhook.create source: args[:source], source_id: args[:source_id], action: action_name.to_s,
                   params: args[:params], referrer: request.referrer.to_s,
                   headers: request.headers.env.select{|k, _| k =~ /^HTTP_/}
  end

  def verify_shopify_webhook
    data = request.body.read
    hmac_header = request.headers['HTTP_X_SHOPIFY_HMAC_SHA256']
    digest = OpenSSL::Digest::Digest.new('sha256')
    calculated_hmac = Base64.encode64(OpenSSL::HMAC.digest(digest, ENV['SHOPIFY_WEB_HOOK_KEY'], data)).strip
    puts hmac_header
    unless hmac_header == calculated_hmac
      head :unauthorized
    end
    request.body.rewind
  end

  def shop_domain
    request.headers['HTTP_X_SHOPIFY_SHOP_DOMAIN']
  end

  def shopify_params
    params.to_unsafe_h.except(:controller, :action, :type)
  end

  def wpcf7_params
    params.except(:controller, :action, :type).permit(
        :client_id, :position, :gender, :has_color, :is_first_time, :first_name, :last_name, :linker_param, :_ga, :art_sample_1, :art_sample_2,
        :art_sample_3, :description, :email, user_attributes: [ :marketing_opt_in, :presales_opt_in, :crm_opt_in ]
    ).to_unsafe_h
  end

  def calendly_params
    params.require(:payload).permit(event: [:uuid, :start_time, :end_time],
                                    invitee: [:uuid, :email, :first_name, :last_name, :text_reminder_number]).to_unsafe_h
  end
end
