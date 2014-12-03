require 'action_controller'
require 'action_controller/test_case'
require_relative '../../lib/lazy_helpers'

class LazyControllerTest < ActiveSupport::TestCase

  module UsualHelper
  end

  module CustomHelper
  end

  class TestController < ActionController::Base
    helper UsualHelper
  end

  def setup
    TestController.class_eval do
      @lazy_helpers = nil
    end
    @controller = TestController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_usual_helpers_included
    assert @controller._helpers.included_modules.include?(UsualHelper)
  end

  def test_custom_module_does_not_included_straight
    @controller.class.send :lazy_helper, CustomHelper
    refute @controller._helpers.included_modules.include?(CustomHelper)
  end

  def test_custom_module_included_by_module_name
    @controller.class.send :lazy_helper, CustomHelper
    @controller.send :include_lazy_helpers
    assert @controller._helpers.included_modules.include?(CustomHelper)
  end

  def test_custom_module_included_with_true_condition
    @controller.class.send :lazy_helper, CustomHelper, :if_included => UsualHelper
    @controller.send :include_lazy_helpers
    assert @controller._helpers.included_modules.include?(CustomHelper)
  end

  def test_custom_module_doesnt_included_with_false_condition
    some_module = Module.new
    @controller.class.send :lazy_helper, CustomHelper, :if_included => some_module
    @controller.send :include_lazy_helpers
    refute @controller._helpers.included_modules.include?(CustomHelper)
  end

end
