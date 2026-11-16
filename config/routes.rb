Rails.application.routes.draw do
  resources :study_plans, only: %i[new create show]

  root 'study_plans#new'
  
end
