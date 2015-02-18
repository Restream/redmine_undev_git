require 'active_support/concern'

module LazyHelpers
  extend ActiveSupport::Concern

  included do
    before_filter :include_lazy_helpers
  end

  module ClassMethods
    def lazy_helper(helper_module, options = {})
      @lazy_helpers ||= []
      @lazy_helpers << [helper_module, options]
    end

    def lazy_helpers
      all_lazy_helpers = @lazy_helpers || []
      superclass.respond_to?(:lazy_helpers) ? superclass.lazy_helpers + all_lazy_helpers : all_lazy_helpers
    end
  end

  private

  def include_lazy_helpers
    self.class.lazy_helpers.each do |args|
      include_lazy_helper(*args)
    end
    true
  end

  def include_lazy_helper(helper_module, options)
    if options[:if_included]
      return unless _helpers.included_modules.include?(options[:if_included])
    end
    self.class.send :helper, helper_module
  end

end

unless ActionController::Base.included_modules.include?(LazyHelpers)
  ActionController::Base.send :include, LazyHelpers
end
