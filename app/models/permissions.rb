module Permissions
  def self.permission_for(user)
    if user.nil?
      GuestPermission.new
    elsif user.permissions == 'admin'
      AdminPermission.new(user)
    elsif user.permissions == 'labMember'
    	LabMemberPermission.new(user)
  	else
      MemberPermission.new(user)
    end
  end
end


