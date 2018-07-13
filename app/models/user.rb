class User < ActiveRecord::Base
  acts_as_token_authenticatable
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  has_many :requests
  has_many :messages, class_name: "Ahoy::Message"

  auto_strip_attributes :email

  def opted_out
    !presales_opt_in || !marketing_opt_in || !crm_opt_in
  end

  def opted_out=(value)
    update(presales_opt_in: !value, marketing_opt_in: !value)
    update(crm_opt_in: !value) unless value
  end
end
