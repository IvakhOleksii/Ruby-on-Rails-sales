class Salesperson < ActiveRecord::Base

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

attr_accessor :orders, :total_sales

def self.all_with_shopify_orders(params)
		params = { limit: 250 } if !params
		orders = Shopify::Order.shopify_orders(params)
    mapped_orders = orders.map do |order|
      order.sales_id = ""
      order.note_attributes.each do |note_attr|
        if note_attr.name == "sales_id"
          order.sales_id = note_attr.value
        end
      end
      order
    end
    grouped_orders = mapped_orders.group_by(&:sales_id).select{|id,orders| id != "" }.map do |id, orders|
      c = self.find(id.to_i)
      c.total_sales = orders.inject(0) {|sum,o| sum + o.total_price.to_f.round(2)}
      c.orders = orders
      c
    end
    return grouped_orders
end

def self.all_with_shopify_orders_by_email(params)
    params = { limit: 250 } if !params
    params[:create_at_min] = '2016-06-01T00:00:00-00:00'
    params[:fields] = 'customer,line_items,total_price,subtotal_price,note_attributes,created_at'
    orders = Shopify::Order.shopify_orders(params)
    orders = orders.select do |order|
      order.line_items.any?{|li| li.title.include? 'Deposit' }
    end
    orders.map {|order| 
      if DateTime.parse(order.created_at.to_date) < DateTime.parse("Tue, 7 Jun 2016")
        order.sales_id = 1
      else
        order.note_attributes.each do |note_attr|
          if note_attr.name == "sales_id"
            order.sales_id = note_attr.value
          end
        end
      end
      order
    }
    grouped_orders = orders.group_by(&:sales_id)
    salespeople = grouped_orders.select{|id,orders| id != "" }.map do |id, orders|
      c = self.find(id.to_i)
      c.total_sales = orders.inject(0) {|sum,o| sum + o.total_price.to_f.round(2)}
      c.orders = orders
      c
    end
    return salespeople
end

def self.sales_by_date(params)
	params[:limit] = 250 
	self.all_with_shopify_orders_by_email(params)
end

  def streak_api_key
    decipher = OpenSSL::Cipher::AES.new(128, :CBC)
    decipher.decrypt
    decipher.key = Rails.application.config.streak_api_cipher_random_key
    decipher.iv = Rails.application.config.streak_api_cipher_random_iv

    decipher.update(Base64.decode64(encrypted_streak_api_key)) + decipher.final
  end

  def streak_api_key=(new_key)
    cipher = OpenSSL::Cipher::AES.new(128, :CBC)
    cipher.encrypt
    cipher.key = Rails.application.config.streak_api_cipher_random_key
    cipher.iv = Rails.application.config.streak_api_cipher_random_iv

    self.encrypted_streak_api_key = Base64.encode64( cipher.update(new_key) + cipher.final )
  end

end

require 'openssl'
require 'base64'