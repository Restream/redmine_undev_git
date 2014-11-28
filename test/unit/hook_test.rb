require File.expand_path('../../test_helper', __FILE__)

class HookTest < ActiveSupport::TestCase

  def test_applied_for
    samples = [
        {
            :hook => { :keywords => 'refs, fixes', :branches => '*' },
            true => [
                [%w{refs fixes}, %w{master}],
                [%w{fixes refs closes}, %w{master}],
                [%w{refs closes}, %w{master}],
                [%w{refs}, %w{master}],
                [%w{fixes closes}, %w{master}],
                [%w{fixes}, %w{master}]
            ],
            false => [
                [%w{closes}, %w{master}],
                [%w{closes other}, %w{master}],
                [%w{}, %w{master}]
            ]
        },
        {
            :hook => { :keywords => 'refs', :branches => 'master' },
            true => [
                [%w{refs}, %w{master}]
            ],
            false => [
                [%w{refs}, %w{staging}]
            ]
        },
        {
            :hook => { :keywords => 'refs', :branches => 'master, develop' },
            true => [
                [%w{refs}, %w{master}],
                [%w{refs}, %w{master other}],
                [%w{refs}, %w{master develop}],
                [%w{refs}, %w{master develop other}],
                [%w{refs}, %w{develop other master}],
                [%w{refs}, %w{develop other}],
                [%w{refs}, %w{develop}]
            ],
            false => [
                [%w{refs}, %w{staging}],
                [%w{refs}, %w{feature staging}]
            ]
        }
    ]
    samples.each do |sample|
      hook = GlobalHook.new(sample[:hook])
      [true, false].each do |result|
        sample[result].each do |args|
          assert_equal result,
                       hook.applicable_for?(*args),
                       "GlobalHook.new(#{sample[:hook]}).applied_for?(#{args[0]}, #{args[1]}) should return #{result}"
        end
      end
    end
  end

end
