ActionController::Routing::Routes.draw do |map|
  map.resources :single_values


  map.resources :sysconfigs

  # The priority is based upon order of creation: first created -> highest priority.

  # Sample of regular route:
  #   map.connect 'products/:id', :controller => 'catalog', :action => 'view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   map.purchase 'products/:id/purchase', :controller => 'catalog', :action => 'purchase'
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   map.resources :products

  # Sample resource route with options:
  #   map.resources :products, :member => { :short => :get, :toggle => :post }, :collection => { :sold => :get }

  # Sample resource route with sub-resources:
  #   map.resources :products, :has_many => [ :comments, :sales ], :has_one => :seller

  # Sample resource route with more complex sub-resources
  #   map.resources :products do |products|
  #     products.resources :comments
  #     products.resources :sales, :collection => { :recent => :get }
  #   end

  # Sample resource route within a namespace:
  #   map.namespace :admin do |admin|
  #     # Directs /admin/products/* to Admin::ProductsController (app/controllers/admin/products_controller.rb)
  #     admin.resources :products
  #   end

  map.resource :config, :controller => 'config_ntp', :path_prefix => "/services/ntp"
  map.connect "/services/ntp/config/:id", :controller => 'config_ntp', :action => 'singleValue'
  map.connect "/services/ntp/config/:id.xml", :controller => 'config_ntp', :action => 'singleValue', :format =>'xml'
  map.connect "/services/ntp/config/:id.html", :controller => 'config_ntp', :action => 'singleValue', :format =>'html'
  map.connect "/services/ntp/config/:id.json", :controller => 'config_ntp', :action => 'singleValue', :format =>'json'

  map.namespace :services do |service|
      service.resource :dummy
  end

  map.resources :services do |service|
     service.resources :commands
  end

  map.namespace :system do |system|
    system.resource :systemtime, :controller => 'systemtime'
  end

  # You can have the root of your site routed with map.root -- just remember to delete public/index.html.
  # map.root :controller => "welcome"

  # See how all your routes lay out with "rake routes"

  # Install the default routes as the lowest priority.
  map.connect ':controller/:action.:format'
  map.connect ':controller/:action/:id'
  map.connect ':controller/:action/:id.:format'

  map.root :controller => "yast"
end
