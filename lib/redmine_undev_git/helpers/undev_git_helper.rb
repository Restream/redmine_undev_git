module RedmineUndevGit::Helpers
  module UndevGitHelper
    def changeset_branches(changeset, max_branches = nil)
      max = max_branches.to_i
      brs = max > 0 ? changeset.branches[0...max] : changeset.branches
      links = brs.map do |branch|
        link_to_branch(branch, changeset.repository, changeset.scmid)
      end
      links << '...' if changeset.branches.length > brs.length
      "(#{links.join('; ')})".html_safe
    end

    def link_to_branch(branch, repository, revision = nil)
      link_to(h(branch), url_for(
          :controller => 'repositories',
          :action => 'show',
          :id => repository.project,
          :repository_id => repository.identifier_param,
          :path => nil,
          :params => {
              :branch => branch,
              :rev => revision
          },
          :trailing_slash => false)
      )
    end
  end
end
