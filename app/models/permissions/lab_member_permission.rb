module Permissions
  class LabMemberPermission < BasePermission
    def initialize(user)
      permit(:users, [:new, :create, :edit, :update])
      # permit also accepts a 3rd argument, as a block, which will allow us
      # for instance, to only permit a user to edit a particular topic if
      # they are the creator (i.e. topic.user_id == user.id)
      # permit :topics, [:edit, :update] do |topic|
   #      topic.user_id == user.id
   #    end
      #permit(:apps, [:clik, :dr_engine])
      #permit_param( :apps, [:name])

      permit( :users, [:new, :create, :forgot_password, :welcome, :reset_password_request])
      permit( :sessions, [:new, :create, :destroy])
      permit( :apps, [ :orf_converter, :dissection_reader, :aa_mutator, :data_intersection, :calculate_intersection, :hyper_geometric_calculator, :generate_CDF, :find_GO_terms_or_complexes, :checkValidGenes, :pull_gene_names ])
      permit( :clik, [:index, :update_interactions, :reciprocal_info, :bin_width, :bootstrapping, :noise_reduction, :scoring, :group])
      permit( :feature_requests, [:new, :create])
      permit( :cbio, [:mutual_exclusion, :scores, :getAlterationTypes, :getCaseList, :getCbioScores])
      permit( :network, [:create_graph, :getNodeFeatureData, :buildNetwork, :updateInteractions])
      permit( :screen_troll, [:list, :submission, :externalToolList, :stats, :screenTroll])
      permit( :scerevisiae_hsapien_orthologs, [:list, :search, :submit, :new_pair_submission, :new, :create, :edit, :update])
      permit( :password_resets, [:edit, :update])
      permit( :hsapien_ensembl_genes, [:getEnsemblID])
      permit( :scerevisiae_genes, [:validate])
      permit( :screen_mill, [:dr_engine_setup, :key_file_info, :dr_engine, :log_file_info, :dr_results, :download, :sv_engine, :sv_engine_setup, :cm_engine_names, :cm_engine])
      permit( :donors, [:new, :edit, :update, :create, :list, :show])
      permit( :densities, [:new, :create, :list])
      permit( :replicates, [:new, :create, :list])
      permit( :screen_purposes, [:new, :create, :list])
      permit( :strain_libraries, [:new, :create, :list, :edit, :update])
      permit( :pwj_plasmids, [:new, :create, :list, :edit, :update])
      permit( :experiments, [:show, :associated_data, :list, :my_experiments, :search, :deletion_search, :dr_engine_file_upload, :verify_query, :check_if_experiment_exists, :associate_experiment_with_colony_data, :link_data])
      permit :experiments, [:edit, :update, :destroy] do |experiment|
        experiment.performed_by == user.login
      end
      permit( :experiment_raw_datasets, [:new, :check_if_log_data_exists, :show, :destroy, :index])

    end
  end
end
