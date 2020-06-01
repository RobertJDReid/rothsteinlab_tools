require "spec_helper"

describe Permissions::MemberPermission do

  let(:user) { FactoryGirl.create(:user, permissions: 'standard') }
  # let(:user_topic) { FactoryGirl.build(:topic, user: user) }
  # let(:other_topic) { FactoryGirl.build(:topic) }
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
    should_not permit(:cbio, :mutual_exclusion)
    should_not permit(:cbio, :scores)
    should_not permit(:cbio, :getAlterationTypes)
    should_not permit(:cbio, :getCaseList)
    should_not permit(:cbio, :getCbioScores)
  end

  it "does allow viewing and suggesting of orthologs" do
    should permit(:scerevisiae_hsapien_orthologs, :list)
    should permit(:scerevisiae_hsapien_orthologs, :search)
    should permit(:scerevisiae_hsapien_orthologs, :new_pair_submission)
    should permit(:scerevisiae_hsapien_orthologs, :submit)
    should_not permit(:scerevisiae_hsapien_orthologs, :new)
    should_not permit(:scerevisiae_hsapien_orthologs, :create)
    should_not permit(:scerevisiae_hsapien_orthologs, :edit)
    should_not permit(:scerevisiae_hsapien_orthologs, :update)
  end

  it "does not allow donors" do
    should_not permit(:donors, :list)
    should_not permit(:donors, :edit)
    should_not permit(:donors, :update)
    should_not permit(:donors, :create)
    should_not permit(:donors, :new)
  end

  it "does not allow densities" do
    should_not permit(:densities, :list)
    should_not permit(:densities, :create)
    should_not permit(:densities, :new)
  end

  it "does not allow screen_purposes" do
    should_not permit(:screen_purposes, :list)
    should_not permit(:screen_purposes, :create)
    should_not permit(:screen_purposes, :new)
  end

  it "should not allow pwj_plasmids" do
    should_not permit(:pwj_plasmids, :list)
    should_not permit(:pwj_plasmids, :edit)
    should_not permit(:pwj_plasmids, :update)
    should_not permit(:pwj_plasmids, :create)
    should_not permit(:pwj_plasmids, :new)
  end

  it "should not allow replicates" do
    should_not permit(:replicates, :list)
    should_not permit(:replicates, :create)
    should_not permit(:replicates, :new)
  end

  it "should not allow strain_libaries" do
    should_not permit(:strain_libaries, :list)
    should_not permit(:strain_libaries, :edit)
    should_not permit(:strain_libaries, :update)
    should_not permit(:strain_libaries, :create)
    should_not permit(:strain_libaries, :new)
  end

  it "shound not allow experiment stuff" do
    should_not permit(:experiments, :list)
    should_not permit(:experiments, :update)
    should_not permit(:experiments, :associated_data)
    should_not permit(:experiments, :my_experiments)
    should_not permit(:experiments, :destroy)
    should_not permit(:experiments, :search)
    should_not permit(:experiments, :deletion_search)
    should_not permit(:experiments, :dr_engine_file_upload)
    should_not permit(:experiments, :verify_query)
    should_not permit(:experiments, :check_if_experiment_exists)
    should_not permit(:experiments, :link_data)
    should_not permit(:experiments, :associate_experiment_with_colony_data)
  end

  it "should not allow experiment raw datasets" do
    should_not permit(:experiment_raw_datasets, :new)
    should_not permit(:experiment_raw_datasets, :check_if_log_data_exists)
    should_not permit(:experiment_raw_datasets, :show)
    should_not permit(:experiment_raw_datasets, :destroy)
    should_not permit(:experiment_raw_datasets, :index)
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
