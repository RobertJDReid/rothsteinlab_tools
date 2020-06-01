module Permissions
  class MemberPermission < BasePermission
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
      #
      permit( :users, [:new, :create, :forgot_password, :welcome, :reset_password_request])
      permit( :sessions, [:new, :create, :destroy])
      permit( :apps, [:orf_converter, :dissection_reader, :aa_mutator, :data_intersection, :calculate_intersection, :hyper_geometric_calculator, :generate_CDF, :find_GO_terms_or_complexes, :checkValidGenes, :pull_gene_names ])
      permit( :feature_requests, [:new, :create])
      permit( :clik, [:index, :update_interactions, :reciprocal_info, :bin_width, :bootstrapping, :noise_reduction, :scoring, :group])
      permit( :cbio, [])
      permit( :network, [:create_graph, :getNodeFeatureData, :buildNetwork, :updateInteractions])
      permit( :screen_troll, [:list, :submission, :externalToolList, :stats, :screenTroll])
      permit( :scerevisiae_hsapien_orthologs, [:list, :search, :submit, :new_pair_submission])
      permit( :password_resets, [:edit, :update])
      permit( :hsapien_ensembl_genes, [:getEnsemblID])
      permit( :scerevisiae_genes, [:validate])
      permit( :screen_mill, [:dr_engine_setup, :key_file_info, :dr_engine, :log_file_info, :dr_results, :download, :sv_engine, :sv_engine_setup, :cm_engine_names, :cm_engine])
    end
  end
end
