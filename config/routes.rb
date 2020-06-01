Rails4App::Application.routes.draw do
scope "/tools" do


 # scope "/tools" do
    resources :excluded_colonies

    # The priority is based upon order of creation: first created -> highest priority.
    # See how all your routes lay out with "rake routes".

    # You can have  the root of your site routed with "root"
    # root 'welcome#index'
    get 'signup', to: 'users#new', as: 'signup'
    get 'login', to: 'sessions#new', as: 'login'
    get 'logout', to: 'sessions#destroy', as: 'logout'

    post 'user/reset_password_request', to: 'users#reset_password_request', as: 'reset_password_request'
    get 'user/forgot_password', to: 'users#forgot_password', as: 'forgot_password'
    get 'user/reset_password', to: 'users#reset_password', as: 'reset_password'
    get 'user/edit', to: 'users#edit', as: 'edit'

    resources :clik, only: [:index]
    get 'clik/reciprocal_info', to: 'clik#reciprocal_info'
    get 'clik/scoring', to: 'clik#scoring'
    get 'clik/bin_width', to: 'clik#bin_width'
    get 'clik/bootstrapping', to: 'clik#bootstrapping'
    get 'clik/noise_reduction', to: 'clik#noise_reduction'
    get 'clik/update_interactions', to: 'clik#update_interactions'
    get 'clik/group', to: 'clik#group'

    get 'apps/dissection_reader'
    get 'apps/aa_mutator'
    get 'apps/data_intersection'
    post 'apps/calculate_intersection'
    get 'apps/generate_CDF'
    get 'apps/hyper_geometric_calculator'
    get 'apps/find_GO_terms_or_complexes'
    post 'apps/checkValidGenes'
    get 'apps/orf_converter'
    get 'apps/pull_gene_names'

    post 'network/create_graph'
    get 'network/getNodeFeatureData'
    get 'network/updateInteractions'
    get 'network/buildNetwork'

    get 'screen_troll/stats'
    get 'screen_troll/submission'
    get 'screen_troll/list'
    get 'screen_troll/screenTroll'
    get 'screen_troll/externalToolList'
    get 'screenTroll', to: 'screen_troll#screenTroll'

    get 'cbio/mutual_exclusion'
    post 'cbio/mutual_exclusion'
    get 'cbio/scores'
    get 'cbio/getAlterationTypes'
    get 'cbio/getCaseList'
    get 'cbio/getCbioScores'

    get 'densities' => 'densities#list', as: 'densities'
    get 'densities/index' => 'densities#list'

    get 'donors' => 'donors#list', as: 'donors'
    get 'donors/index' => 'donors#list'

    get 'pwj_plasmids' => 'pwj_plasmids#list', as: 'pwj_plasmids'
    get 'pwj_plasmids/index' => 'pwj_plasmids#list'

    get 'replicates' => 'replicates#list', as: 'replicates'
    get 'replicates/index' => 'replicates#list'

    get 'strain_libraries' => 'strain_libraries#list', as: 'strain_libraries'
    get 'strain_libraries/index' => 'strain_libraries#list'

    get 'screen_purposes' => 'screen_purposes#list', as: 'screen_purposes'
    get 'screen_purposes/index' => 'screen_purposes#list'

    get 'experiments' => 'experiments#list', as: 'experiments'
    get 'experiments/index' => 'experiments#list'
    get 'experiments/associated_data'
    get 'experiments/search'
    get 'experiments/dr_engine_file_upload'
    get 'experiments/verify_query'
    get 'experiments/check_if_experiment_exists'
    get 'experiments/my_experiments'
    post 'experiments/update_comments'
    get 'experiments/associate_experiment_with_colony_data'
    post 'experiments/link_data'

    get 'scerevisiae_hsapien_orthologs' => 'scerevisiae_hsapien_orthologs#list', as: 'scerevisiae_hsapien_orthologs'
    get 'scerevisiae_hsapien_orthologs/index' => 'scerevisiae_hsapien_orthologs#list'
    get 'scerevisiae_hsapien_ortholog/submit' => 'scerevisiae_hsapien_orthologs#submit'
    post 'scerevisiae_hsapien_ortholog/new_pair_submission' => 'scerevisiae_hsapien_orthologs#new_pair_submission'
    get 'scerevisiae_hsapien_orthologs/search' => 'scerevisiae_hsapien_orthologs#search'

    get 'hsapien_ensembl_genes/getEnsemblID'

    get 'scerevisiae_genes/validate'

    get 'screen_mill/dr_engine_setup'
    post 'screen_mill/dr_engine'
    post 'screen_mill/dr_results'
    post 'rails4/screen_mill/dr_results' => 'screen_mill#dr_results'
    post 'rails4/screen_mill/dr_engine' => 'screen_mill#dr_engine'
    get 'screen_mill/log_file_info'
    get 'screen_mill/key_file_info'
    get 'screen_mill/cm_engine'
    get 'screen_mill/cm_engine_names'
    get 'screen_mill/sv_engine_setup'
    get 'screen_mill/download/:id'  => 'screen_mill#download'
    get 'rails4/screen_mill/download/:id' => 'screen_mill#download'
    post 'screen_mill/sv_engine'
    post 'rails4/screen_mill/sv_engine' => 'screen_mill#sv_engine'

    get 'experiment_raw_datasets/check_if_log_data_exists'

    resources :donors
    resources :densities
    resources :pwj_plasmids
    resources :strain_libraries
    resources :replicates
    resources :scerevisiae_hsapien_orthologs
    resources :feature_requests
    resources :users
    resources :sessions
    resources :password_resets
    resources :screen_troll
    resources :screen_purposes
    resources :experiments
    resources :experiment_raw_datasets

    root to: 'users#welcome'
  end
#end
end
