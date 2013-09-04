module RedmineUndevGit::Patches
  module CustomFieldPatch
    extend ActiveSupport::Concern

    included do
      alias_method_chain :possible_values_options, :global
    end

    def possible_values_options_with_global(obj=nil)
      if obj.is_a?(GlobalHook) && %w(user version).include?(field_format)
        case field_format
          when 'user'
            User.active.sort.collect {|u| [u.to_s, u.id.to_s]}
          when 'version'
            Version.visible.sort.collect {|u| [u.to_s, u.id.to_s]}
        end
      else
        possible_values_options_without_global(obj)
      end
    end
  end
end

unless CustomField.included_modules.include?(RedmineUndevGit::Patches::CustomFieldPatch)
  CustomField.send :include, RedmineUndevGit::Patches::CustomFieldPatch
end
