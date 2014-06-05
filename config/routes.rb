RedmineApp::Application.routes.draw do
  resources :global_hooks, :except => :show, :path => 'hooks'

  resources :projects do
    resources :hooks, :except => :show, :controller => 'project_hooks'
  end

  match 'gitlab_hooks' => 'undev_git_hooks#gitlab_push', :via => :post, :as => :gitlab_hooks
end
