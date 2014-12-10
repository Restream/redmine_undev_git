# encoding: utf-8
puts '>> Loading environment...'

ENV[ 'RAILS_ENV' ] = 'test'
require File.expand_path( File.dirname( __FILE__ ) + '/../../../config/environment')

require 'tmpdir'
require 'fileutils'
require 'benchmark'
require 'rubygems'

TEST_REPO = '/Users/danil/code/temp/redmine.git'
#TEST_REPO = 'https://github.com/redmine/redmine.git'
#TEST_REPO = 'https://bitbucket.org/nodecarter/dt_fetch.git'

puts '>> Preparing...'

tmpdir = Dir.mktmpdir
tmpdir_undev = Dir.mktmpdir

at_exit do
  puts '>> Cleaning up...'
  Project.delete_all
  Repository.delete_all
  Changeset.delete_all
  Change.delete_all
  FileUtils.rm_r(tmpdir) if File.exist? tmpdir.to_s
  FileUtils.rm_r(tmpdir_undev) if File.exist? tmpdir_undev.to_s
end

system "git clone --bare #{TEST_REPO} #{tmpdir}"
system "git clone --bare #{TEST_REPO} #{tmpdir_undev}"

project = Project.create! \
  name: 'Benchmark',
  identifier: "benchmark-#{Time.now.to_i}"

Setting.enabled_scm = ['Git', 'UndevGit']

vanilla_repo = Repository::Git.new
vanilla_repo.project = project
vanilla_repo.identifier = 'vanilla_repo'
vanilla_repo.url = tmpdir
vanilla_repo.save!

undev_repo = Repository::UndevGit.new
undev_repo.project = project
undev_repo.identifier = 'undev_repo'
undev_repo.url = TEST_REPO 
undev_repo.root_url = tmpdir_undev
undev_repo.save!

STDERR.reopen('/dev/null', 'w')

puts '>> Benchmarking...'

Benchmark.bm(40) do |b|
  b.report('Repository::Git#fetch_changesets') do
    vanilla_repo.fetch_changesets
  end

  b.report('Repository::UndevGit#fetch_changesets') do
    undev_repo.fetch_changesets
  end
end
