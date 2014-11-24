# RedmineUndevGit

[![Build Status](https://travis-ci.org/Undev/redmine_undev_git.png)](https://travis-ci.org/Undev/redmine_undev_git)
[![Code Climate](https://codeclimate.com/github/Undev/redmine_undev_git.png)](https://codeclimate.com/github/Undev/redmine_undev_git)

## Description

The UndevGit plugin adds the UndevGit repository type to Redmine.
UndevGit has all standard functions of a Git repository, as well as other features:
possibility to work with remote repositories;
hooks for UndevGit repositories.

When accessing a remote or local repository, UndevGit clones it 
and then works with the created copy.

## Setup and configuration

### Setup

 1. Copy the plugin directory into plugins
 2. bundle exec rake redmine:plugins:migrate
 3. bundle install in the Redmine root directory
 4. Restart Redmine

### Configuration

Go to the project settings > *Repositories* tab > *Enabled SCM* section
to enable UndevGit.

The plugin settings allow you to specify the maximum number of branches to be displayed on 
the ticket page in the *Associated Revisions* section.
An empty field or 0 means no restrictions.
For details of hook configuration, see the corresponding section below.

In the Redmine settings, `config/configuration.yml` file, you can specify
the directory for storing local repository copies
by setting a value for the `scm_repo_storage_dir` key. By default, the `repos` directory is used
(in the Redmine root directory).
Local repository copies are stored in the `repos\[projectidentifier]\[repository_id]` directory.
When you remove a repository, the corresponding directory is deleted.

## Hooks

Hooks are used to flexibly configure how and when a ticket can be changed.
You can configure hooks to be run for certain branches, a project or even a specific repository.
Thus, there are global hooks that are run for all repositories, 
project hooks that are run for all project repositories, and repository hooks.

If "*" is specified as a branch for the hook, it means that this hook is applied only once when a commit is added to the repository;
if branch names are specified, the hook is applied each time a commit is added to a branch (once per branch).

### Настройка

Hooks implement the Redmine feature of closing tickets
using keywords. Therefore, the keywords specified
at the *Repository* tab of the Redmine settings (*Fixing keywords* attribute)
are not used. You should define a set of keywords for each hook.

Hooks can be configured in the following windows. Global hooks are managed from the Redmine settings window
(*Global hooks* menu item, above *Plugins*).
Project and repository hooks are available on the *Hooks* tab of the project settings menu.

TODO: Configuring how repositories are read when accessed (why it should be disabled)

### Hook priorities

Hook priorities are determined as follows: the repository hooks have the highest priority,
then go the project hooks, while global hooks have the lowest priority.
There are also different priorities within each hook type, which can be changed if needed.
If there are several hooks applicable to a commit,
only the hook with the highest priority will be run.

Hooks applied to all branches have a lower priority
than hooks with branch names specified explicitly.

### Logging

All changes in a ticked are recorded in its log. If no changes have been made,
the log will have no entries.

### Examples

#### Example 1

A commit is pushed to 2 branches (feature, develop) of a repository.
There are 2 configured hooks:
Hook1 for branch '*'
Hook2 for branch 'feature'
In this case, only hook2 will be run.

#### Example 2

There is commit A with the text 'fix #1' and the following hooks:
Hook1 global, branch '*'
Hook2 global, branch 'master'
Hook3, project, branch 'develop,staging'
Hook4 for a repository, branch 'staging'
Hook5 for a repository, branch 'feature'

First push: commit A to branch feature: Hook5 is run.
Second push: merge feature to staging: Hook4 is run.
Third push: merge feature to develop: Hook3 is run.
Fourth push: merge feature to master: Hook2 is run.

Hook1 is used only if commit B is pushed to branch featureX.

## Linking commits to tickets

To link a commit to a ticket, specify the keyword and the ticket number starting with #,
for example: `refs #124`.
Keywords are set on the *Repository* tab of the Redmine settings window
(*Referencing keywords* attribute).
If you set '*' as a keyword, specifying only the ticket number with #
will be enough to link a commit to a ticket.

## Moving of commits (rebase)

UndevGit enables you to determine which commits have be moved by using `git rebase`.
Old references to commits are not removed from the changeset list; instead, they are marked with a special icon
with a link to a new commit reference. Similarly, new commits are marked with an icon
with a link to old commit references.
This mark is available when viewing the list of commits or a specific commit.
Using rebase does not cause new changes of tickets; however, the links in the Associated Revisions are changed.
Using rebase also does not affect timelogs.

## Repository updates by a webhook

TODO

### Global settings

### Settings of a specific repository

### Updating from Cron

Repository.fetch_changeset skips the repositories that are updated by the webhook.

## Testing

Unpack the test repositories
    rake test:scm:setup:undev_git

Create a database
    rake RAILS_ENV=test db:drop db:create db:migrate redmine:plugins:migrate

Launch tests for the redmine_undev_plugin plugin@@@
    rake RAILS_ENV=test NAME=redmine_undev_git redmine:plugins:test

## TODO:

Rake tasks: moving Git repositories to UndevGit
Additional fields in changesets
Reading the sequence (in detail)
Specifics of first access to huge repositories (configuring chunk_size)
