module RedmineUndevGit::Patches
  module StringPatch
    extend ActiveSupport::Concern

    def split_by_comma
      downcase.split(',').map(&:strip)
    end
  end
end

unless String.included_modules.include?(RedmineUndevGit::Patches::StringPatch)
  String.send :include, RedmineUndevGit::Patches::StringPatch
end
