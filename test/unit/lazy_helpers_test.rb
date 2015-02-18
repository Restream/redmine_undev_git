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

  class TestChildController < TestController
  end

  def setup
    TestController.class_eval do
      @lazy_helpers = nil
    end
    TestChildController.class_eval do
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
    TestController.class_eval do
      lazy_helper CustomHelper
    end
    refute @controller._helpers.included_modules.include?(CustomHelper)
  end

  def test_custom_module_included_by_module_name
    TestController.class_eval do
      lazy_helper CustomHelper
    end
    @controller.send :include_lazy_helpers
    assert @controller._helpers.included_modules.include?(CustomHelper)
  end

  def test_custom_module_included_with_true_condition
    TestController.class_eval do
      lazy_helper CustomHelper, if_included: UsualHelper
    end
    @controller.send :include_lazy_helpers
    assert @controller._helpers.included_modules.include?(CustomHelper)
  end

  def test_custom_module_doesnt_included_with_false_condition
    some_module = Module.new
    TestController.class_eval do
      lazy_helper CustomHelper, if_included: some_module
    end
    @controller.send :include_lazy_helpers
    refute @controller._helpers.included_modules.include?(CustomHelper)
  end

  def test_custom_module_included_in_child_classes
    TestController.class_eval do
      lazy_helper CustomHelper
    end
    child_controller = TestChildController.new
    child_controller.send :include_lazy_helpers
    assert child_controller._helpers.included_modules.include?(CustomHelper)
  end

end
