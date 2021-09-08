# frozen_string_literal: true

require 'services/campaign_monitor'

class User < ApplicationRecord
  acts_as_token_authenticatable

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable,
         :registerable,
         :recoverable,
         :rememberable,
         :trackable,
         :validatable

  scope :fuzzy_matching_email, (->(email) { where("levenshtein(email, ?) <= 2", email) })
  scope :subscribed_to_marketing, -> { where(marketing_opt_in: true) }

  has_many :requests, dependent: :destroy
  has_many :events
  has_many :messages, class_name: "Ahoy::Message"

  auto_strip_attributes :email, :first_name, :last_name
  phony_normalize :phone_number, default_country_code: "US"

  before_validation :initialize_password
  validates_presence_of :email
  validates_length_of :email, minimum: 5

  after_create :process_cm_on_create
  after_update :process_cm_on_update

  def ransackable_attributes(_auth_object = nil)
    [:email, :marketing_opt_in, :crm_opt_in, :presales_opt_in]
  end

  def email=(value)
    self[:email] = value&.downcase
  end

  def opted_out
    !presales_opt_in && !marketing_opt_in
  end

  def opted_out=(value)
    assign_attributes(presales_opt_in: !value, marketing_opt_in: !value)
    assign_attributes(crm_opt_in: !value) unless value
  end

  def initialize_password
    return unless password.blank?

    self.password = SecureRandom.base64(12)
  end

  def identifies_as
    requests.take.gender
  end

  protected

  # scenarios:

  # -- User creates a request, with marketing: true
  # -- User created a request, with marketing: false
  # -- After receiving a marketing email, user decides to unsubscribe

  def process_cm_on_create
    CampaignMonitorActionJob.perform_later(user: self, method: "add_user_to_all_list")

    CampaignMonitorActionJob.perform_later(user: self, method: "add_user_to_marketing_list") if marketing_opt_in?
  end

  def process_cm_on_update
    if saved_change_to_marketing_opt_in? || saved_change_to_presales_opt_in?
      if saved_change_to_marketing_opt_in?
        if marketing_opt_in?
          CampaignMonitorActionJob.perform_later(user: self, method: "add_user_to_marketing_list")
        else
          CampaignMonitorActionJob.perform_later(user: self, method: "remove_user_from_marketing_list")
        end
      end

      if saved_change_to_presales_opt_in?
        if presales_opt_in?
          CampaignMonitorActionJob.perform_later(user: self, method: "add_user_to_all_list")
        else
          CampaignMonitorActionJob.perform_later(user: self, method: "remove_user_from_all_list")
        end
      end
    else
      CampaignMonitorActionJob.perform_later(user: self, method: "update_user_to_all_list")
    end
  end
end
