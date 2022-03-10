Rails.application.routes.draw do
  post '/validate_addresses', to: 'api_requests#create', defaults: { format: :json }
end
