class GlobalHook < HookBase
  acts_as_list

  # Users/groups issues can be assigned to
  def assignable_users
    assignable = Setting.issue_group_assignment? ? Principal.active : User.active
    assignable.sort
  end

end
