module RedmineUndevGit::Includes::RepoHooks
  extend ActiveSupport::Concern

  def initial_apply_hooks(changeset, issue, keywords)
    all_hooks = all_applicable_hooks

    hooks               = []

    # hook for any branch have the less priority then hook for specific branch
    hook_for_any_branch = all_hooks.detect { |h| h.any_branch? && h.applicable_for?(keywords, changeset.branches) }

    # find hook for every branch
    changeset.branches.each do |branch|
      specific_hook = all_hooks.detect { |h| !h.any_branch? && h.applicable_for?(keywords, [branch]) }
      hooks << specific_hook if specific_hook
    end

    # execute hook for any branch only if specific hooks not found
    hooks << hook_for_any_branch if hook_for_any_branch && hooks.empty?

    hooks.each do |hook|
      apply_for_issue_by_changeset(hook, issue, changeset)
    end
  end

  def apply_for_issue_by_changeset(hook, issue, changeset)
    hook.apply_for_issue_by_changeset(issue, changeset)
  end

  def apply_hooks_for_branch(changeset, branch)
    ref_keywords = Setting.commit_ref_keywords
    all_hooks    = all_applicable_hooks
    fix_keywords = all_hooks.map(&:keywords).join(',')

    parsed = changeset.parse_comment_for_issues(ref_keywords, fix_keywords)

    # update changeset only if
    # changeset was not rebased
    # initialization done or using hooks for initialization is allowed
    if changeset.rebased_from.nil? && (initialization_done? || use_init_hooks?)

      # change issues by hooks
      parsed[:fix_issues].each do |issue, keywords|

        # ignore closed issues
        next if issue.closed?

        hook = all_hooks.detect do |h|
          !h.any_branch? && h.applicable_for?(keywords, [branch])
        end
        apply_for_issue_by_changeset(hook, issue, changeset) if hook
      end
    end
  end

  def apply_hooks_for_merged_commits(prev_branches, repo_branches)
    return unless initialization_done? || use_init_hooks?

    all_hooks     = all_applicable_hooks.find_all { |b| !b.any_branch? }
    hook_branches = all_hooks.map(&:branches).flatten.uniq
    hook_branches.each do |hook_branch|

      repo_branch = repo_branches.find { |b| b.to_s == hook_branch }
      prev_branch = prev_branches[hook_branch]
      next unless repo_branch

      opts            = {}
      opts[:reverse]  = true
      opts[:excludes] = [prev_branch] if prev_branch.present?
      opts[:includes] = [repo_branch.scmid]

      revisions = scm.revisions('', nil, nil, opts)
      next if revisions.blank?

      limit  = 300
      offset = 0
      while offset < revisions.size
        scmids = revisions.slice(offset, limit).map { |r| r.scmid }
        cs     = changesets.where('scmid IN (?)', scmids).order(committed_on: :desc)
        cs.each do |changeset|

          # branches added to changeset at the first save
          # for all these branches hooks was already applied
          next if changeset.branches.include?(hook_branch)

          apply_hooks_for_branch(changeset, hook_branch)
        end
        offset += limit
      end
    end
  end

end
