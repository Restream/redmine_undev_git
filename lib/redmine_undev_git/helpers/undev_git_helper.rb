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

    def link_to_revision_wb(revision, repository, &block)
      if repository.is_a?(Project)
        repository = repository.repository
      end
      rev = revision.respond_to?(:identifier) ? revision.identifier : revision
      link_to(
          {
              :controller => 'repositories',
              :action => 'revision',
              :id => repository.project,
              :repository_id => repository.identifier_param,
              :rev => rev
          },
          :title => l(:label_revision_id, format_revision(revision)),
          &block
      )
    end
  end
end
