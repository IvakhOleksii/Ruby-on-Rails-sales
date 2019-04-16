class SalespersonPolicy < ApplicationPolicy
  def index?
    active_salesperson?
  end

  def create?
    active_salesperson? && @user.admin?
  end

  def update?
    active_salesperson? && @user.admin?
  end

  def destroy?
    active_salesperson? && @user.admin?
  end

  class Scope < Scope
    def resolve
      if @user
        @user.admin? ? scope.all.order("is_active DESC, admin, sign_in_count DESC")
            : scope.where("EMAIL ILIKE '%customtattoodesign.ca'").where.not(email: "sales@customtattoodesign.ca").order("admin, email")
      else
        scope.none
      end
    end
  end
end
