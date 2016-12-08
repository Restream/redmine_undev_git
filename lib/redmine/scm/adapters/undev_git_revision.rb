module Redmine::Scm::Adapters
  class UndevGitRevision < Revision
    attr_accessor :patch_id
    attr_accessor :authored_on
    attr_accessor :branches

    def initialize(attributes)
      super
      self.patch_id    = attributes[:patch_id]
      self.authored_on = attributes[:authored_on]
      self.branches    = attributes[:branches]
    end

    # return false if no branches was added otherwise return branches
    def add_branches(b, append = true)
      new_branches = b - branches
      return false if new_branches.empty?
      self.branches = append ? branches + new_branches : new_branches + branches
    end

    def format_identifier
      identifier[0, 8]
    end

    def looks_like_rebased?
      time != authored_on
    end
  end

  class UndevGitRevisions < Hash
    def initialize(*args)
      super
      @delayed_drags = []
    end

    def drag_branches_to_parents!(rev)
      return nil if rev.parents.empty?

      # for merge commit insert branches to the parent on the same branch
      # and append to others
      if rev.parents.length > 1

        # parent on same branch
        apply_branches!(rev.parents[0], rev.branches, false)

        parents = rev.parents[1..-1]
        parents.each do |parent_sha|
          # parents from merged branches
          apply_branches!(parent_sha, rev.branches, true)
        end

      else

        # just append branches to parent commit
        apply_branches!(rev.parents[0], rev.branches, true)
      end
    end

    def delayed_drags?
      @delayed_drags.any?
    end

    def delayed_drags
      delayed_drags? ? @delayed_drags.dup : nil
    end

    def apply_delayed_drags!(_delayed_drags)
      _delayed_drags.each { |p| apply_branches!(*p) }
    end

    private

    def apply_branches!(sha, branches, append)
      rev = self[sha]
      if rev
        # if revision does not contain applied branches then drag them to rev's parents
        drag_branches_to_parents!(rev) if rev.add_branches(branches, append)
      else
        # revision is out of boundary - store operation
        @delayed_drags << [sha, branches, append]
      end
    end
  end
end
