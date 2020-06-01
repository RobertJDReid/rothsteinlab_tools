module Permissions
  class GuestPermission < BasePermission
    def initialize
    	permit( :users, [:new, :create, :forgot_password, :welcome, :reset_password_request])
    	permit( :sessions, [:new, :create, :destroy])
    	permit( :feature_requests, [:new, :create])
    	permit( :apps, [:orf_converter, :checkValidGenes, :dissection_reader, :aa_mutator, :data_intersection, :calculate_intersection, :hyper_geometric_calculator, :generate_CDF, :find_GO_terms_or_complexes ])
    	permit( :cbio, [])
    	permit( :network, [])
    	permit( :screen_troll, [:list, :submission, :externalToolList, :stats, :screenTroll])
      permit( :scerevisiae_hsapien_orthologs, [:list, :search])
      permit( :password_resets, [:edit, :update])
      permit( :hsapien_ensembl_genes, [:getEnsemblID])
      permit( :scerevisiae_genes, [:validate])
    end
  end
end
