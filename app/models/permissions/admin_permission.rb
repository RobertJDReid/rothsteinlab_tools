module Permissions
  class AdminPermission < BasePermission
    def initialize(user)
      permit_all
    end
  end
end
