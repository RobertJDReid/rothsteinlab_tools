require "spec_helper"

describe Permissions::LabMemberPermission do

  let(:user) { FactoryGirl.create(:user, permissions: 'labMember') }
  let(:user_experiment) { FactoryGirl.build(:experiment, performed_by: user.login) }

  let(:other_user) { FactoryGirl.create(:user, permissions: 'labMember', login: 'tester') }
  let(:other_experiment) { FactoryGirl.build(:experiment, performed_by: other_user.login) }

  subject { Permissions.permission_for(user) }

  it "allows sessions" do
    should permit(:sessions, :new)
    should permit(:sessions, :create)
    should permit(:sessions, :destroy)
  end

  it "allows users" do
    should permit(:users, :new)
    should permit(:users, :create)
    should permit(:users, :edit)
    should permit(:users, :update)
  end

  it "allows password reset" do
    should permit(:password_resets, :edit)
    should permit(:password_resets, :update)
  end

  it "allows apps" do
    should permit(:clik, :index)
    should permit(:clik, :updateInteractions)
    should permit(:apps, :dissection_reader)
    should permit(:apps, :aa_mutator)
    should permit(:apps, :data_intersection)
    should permit(:apps, :calculate_intersection)
    should permit(:apps, :generate_CDF)
    should permit(:apps, :hyper_geometric_calculator)
    should permit(:apps, :find_GO_terms_or_complexes)
    should permit(:apps, :checkValidGenes)
    should permit(:apps, :orf_converter)
    should permit(:apps, :pull_gene_names)
  end

  it "allows feature request" do
    should permit(:feature_requests, :new)
    should permit(:feature_requests, :create)
  end

  it "does not allow network graphs" do
    should permit(:network, :create_graph)
    should permit(:network, :getNodeFeatureData)
    should permit(:network, :buildNetwork)
    should permit(:network, :updateInteractions)
  end

  it "does allow screenTroll" do
    should permit(:screen_troll, :stats)
    should permit(:screen_troll, :submission)
    should permit(:screen_troll, :list)
    should permit(:screen_troll, :screenTroll)
    should permit(:screen_troll, :externalToolList)
  end

  it "does not allow cbio" do
    should permit(:cbio, :mutual_exclusion)
    should permit(:cbio, :scores)
    should permit(:cbio, :getAlterationTypes)
    should permit(:cbio, :getCaseList)
    should permit(:cbio, :getCbioScores)
  end

  it "does allow viewing and suggesting of orthologs" do
    should permit(:scerevisiae_hsapien_orthologs, :list)
    should permit(:scerevisiae_hsapien_orthologs, :search)
    should permit(:scerevisiae_hsapien_orthologs, :new_pair_submission)
    should permit(:scerevisiae_hsapien_orthologs, :submit)
    should permit(:scerevisiae_hsapien_orthologs, :new)
    should permit(:scerevisiae_hsapien_orthologs, :create)
    should permit(:scerevisiae_hsapien_orthologs, :edit)
    should permit(:scerevisiae_hsapien_orthologs, :update)
  end

  it "allows misc" do
    should permit(:hsapien_ensembl_genes, :getEnsemblID)
    should permit(:scerevisiae_genes, :validate)
  end

  it "allows donors" do
    should permit(:donors, :list)
    should permit(:donors, :edit)
    should permit(:donors, :update)
    should permit(:donors, :create)
    should permit(:donors, :new)
  end

  it "allows densities" do
    should permit(:densities, :list)
    should permit(:densities, :create)
    should permit(:densities, :new)
  end

  it "allows pwj_plasmids" do
    should permit(:pwj_plasmids, :list)
    should permit(:pwj_plasmids, :edit)
    should permit(:pwj_plasmids, :update)
    should permit(:pwj_plasmids, :create)
    should permit(:pwj_plasmids, :new)
  end

  it "allows replicates" do
    should permit(:replicates, :list)
    should permit(:replicates, :create)
    should permit(:replicates, :new)
  end

  it "allows strain_libraries" do
    should permit(:strain_libraries, :list)
    should permit(:strain_libraries, :edit)
    should permit(:strain_libraries, :update)
    should permit(:strain_libraries, :create)
    should permit(:strain_libraries, :new)
  end

  it "allows screen_purposes" do
    should permit(:screen_purposes, :list)
    should permit(:screen_purposes, :create)
    should permit(:screen_purposes, :new)
  end

  it "allows experiment stuff" do

    should permit(:experiments, :list)
    should permit(:experiments, :edit, user_experiment)
    should permit(:experiments, :update, user_experiment)
    should permit(:experiments, :destroy, user_experiment)
    # should permit(:experiments, :link_data, user_experiment)

    should_not permit(:experiments, :update, other_experiment)
    should_not permit(:experiments, :edit, other_experiment)
    should_not permit(:experiments, :destroy, other_experiment)

    # should_not permit(:experiments, :link_data, other_experiment)

    should permit(:experiments, :associated_data)
    should permit(:experiments, :my_experiments)

    should permit(:experiments, :search)
    should permit(:experiments, :deletion_search)
    should permit(:experiments, :dr_engine_file_upload)
    should permit(:experiments, :verify_query)
    should permit(:experiments, :check_if_experiment_exists)
    should permit(:experiments, :check_if_log_data_exists)
    should permit(:experiments, :associate_experiment_with_colony_data)
    should permit(:experiments, :link_data)
  end

  it "should allow experiment raw datasets" do
    should permit(:experiment_raw_datasets, :new)
    should permit(:experiment_raw_datasets, :check_if_log_data_exists)
    should permit(:experiment_raw_datasets, :show)
    should permit(:experiment_raw_datasets, :destroy)
    should permit(:experiment_raw_datasets, :index)
  end
  # it "allows topics" do
  #   should allow(:topics, :index)
  #   should allow(:topics, :show)
  #   should allow(:topics, :new)
  #   should allow(:topics, :create)
  #   should_not allow(:topics, :edit)
  #   should_not allow(:topics, :update)
  #   should_not allow(:topics, :edit, other_topic)
  #   should_not allow(:topics, :update, other_topic)
  #   should allow(:topics, :edit, user_topic)
  #   should allow(:topics, :update, user_topic)
  #   should_not allow(:topics, :destroy)
  #   should allow_param(:topic, :name)
  #   should_not allow_param(:topic, :sticky)
  # end

end
