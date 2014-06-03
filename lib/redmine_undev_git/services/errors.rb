module RedmineUndevGit::Services
  class ServiceError < StandardError
  end

  class WrongRepoUrl < ServiceError
  end

end
