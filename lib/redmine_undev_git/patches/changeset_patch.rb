require_dependency 'changeset'

module RedmineUndevGit::Patches
  module ChangesetPatch
    extend ActiveSupport::Concern

    included do
      MAX_LENGTH_BRANCHES_IN_TITLE = 120

      serialize :branches, Array
      serialize :meta, Hash

      #scope :scan_pending, :conditions => { :scan_pending => true }
    end

    #def event_title
    #  [title, format_branches].compact.join(' ')
    #end
    #
    #def format_branches
    #  if branches.any?
    #    branches_s = branches.join('; ')
    #    if branches_s.length > MAX_LENGTH_BRANCHES_IN_TITLE
    #      "(#{branches[0...MAX_LENGTH_BRANCHES_IN_TITLE]}...)"
    #    else
    #      "(#{branches_s})"
    #    end
    #  end
    #end

  end
end

unless Changeset.included_modules.include?(RedmineUndevGit::Patches::ChangesetPatch)
  Changeset.send :include, RedmineUndevGit::Patches::ChangesetPatch
end
