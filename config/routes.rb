RedmineApp::Application.routes.draw do
  resources :global_hooks, :except => :show, :path => 'hooks'

  resources :projects do
    resources :hooks, :except => :show, :controller => 'project_hooks'
  end
end
