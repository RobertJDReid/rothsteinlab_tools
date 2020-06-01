class CreateDatabase < ActiveRecord::Migration
  def self.up
    create_table "densities", force: true do |t|
      t.integer "density", null: false
    end

    add_index "densities", ["density"], name: "density", using: :btree

    create_table "donors", force: true do |t|
      t.string   "wNumber",    limit: 15, default: "", null: false
      t.string   "matingType", limit: 10, default: "", null: false
      t.text     "notes"
      t.string   "genotype"
      t.string   "created_by", limit: 50
      t.datetime "updated_at"
      t.datetime "created_at"
      t.string   "updated_by", limit: 50
    end

    add_index "donors", ["created_by"], name: "created_by", using: :btree
    add_index "donors", ["updated_by"], name: "updated_by", using: :btree
    add_index "donors", ["wNumber"], name: "Wnumber", using: :btree

    create_table "ensembl_version", force: true do |t|
      t.string   "syncedVersionNumber", limit: 4
      t.datetime "dateLastSynced"
    end

    create_table "experiments", force: true do |t|
      t.date     "date"
      t.integer  "density"
      t.string   "comparer",               limit: 11
      t.string   "query",                  limit: 11
      t.string   "condition",                          default: "",  null: false
      t.integer  "replicates",                         default: -1,  null: false
      t.string   "screen_type",            limit: 75,  default: "",  null: false
      t.string   "library_used",           limit: 100, default: "-", null: false
      t.string   "donor_strain_used",      limit: 15,  default: "-", null: false
      t.text     "comments"
      t.integer  "screen_file_id"
      t.string   "file_name"
      t.string   "screen_purpose",         limit: 20,  default: "",  null: false
      t.integer  "log_file_id"
      t.string   "created_by",             limit: 50,  default: ""
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   "updated_by",             limit: 50
      t.integer  "number_of_plates"
      t.string   "performed_by",           limit: 50
      t.integer  "incubation_temperature",             default: 30
    end

    add_index "experiments", ["comparer"], name: "comparer", using: :btree
    add_index "experiments", ["condition"], name: "testCondition", using: :btree
    add_index "experiments", ["created_by"], name: "experimentPerformedBy", using: :btree
    add_index "experiments", ["density"], name: "density", using: :btree
    add_index "experiments", ["donor_strain_used"], name: "donor_strain_used", using: :btree
    add_index "experiments", ["library_used"], name: "library_used", using: :btree
    add_index "experiments", ["log_file_id"], name: "logFileID", using: :btree
    add_index "experiments", ["performed_by"], name: "performed_by", using: :btree
    add_index "experiments", ["query"], name: "query", using: :btree
    add_index "experiments", ["replicates"], name: "replicates", using: :btree
    add_index "experiments", ["screen_file_id"], name: "screenFileID", using: :btree
    add_index "experiments", ["screen_purpose"], name: "screenPurpose", using: :btree
    add_index "experiments", ["screen_type"], name: "screen_type", using: :btree
    add_index "experiments", ["updated_by"], name: "updated_by", using: :btree

    create_table "honig_preppi_int_hsapien", id: false, force: true do |t|
      t.string "int_id",        limit: 20
      t.string "int_a",         limit: 20
      t.string "int_b",         limit: 20
      t.float  "str_score",                 default: 0.0
      t.float  "go_score",                  default: 0.0
      t.float  "ess_score",                 default: 0.0
      t.float  "mips_score",                default: 0.0
      t.float  "phy_score",                 default: 0.0
      t.float  "coexp_score",               default: 0.0
      t.float  "exp_score",                 default: 0.0
      t.float  "pred_score",                default: 0.0
      t.float  "preppi_score",              default: 0.0
      t.string "db_entry",      limit: 100
      t.string "pubmed_id",     limit: 500
      t.string "organism",      limit: 20
      t.string "version",       limit: 5
      t.string "int_a_ensembl", limit: 20
      t.string "int_b_ensembl", limit: 20
    end

    add_index "honig_preppi_int_hsapien", ["int_a"], name: "int_a", using: :btree
    add_index "honig_preppi_int_hsapien", ["int_a_ensembl"], name: "int_a_ensembl", using: :btree
    add_index "honig_preppi_int_hsapien", ["int_b"], name: "int_b", using: :btree
    add_index "honig_preppi_int_hsapien", ["int_b_ensembl"], name: "int_b_ensembl", using: :btree
    add_index "honig_preppi_int_hsapien", ["organism"], name: "organism", using: :btree
    add_index "honig_preppi_int_hsapien", ["preppi_score"], name: "preppi_score", using: :btree

    create_table "honig_preppi_int_hsapien_filtered", id: false, force: true do |t|
      t.string "int_id",        limit: 20
      t.string "int_a",         limit: 20
      t.string "int_b",         limit: 20
      t.float  "str_score",                 default: 0.0
      t.float  "go_score",                  default: 0.0
      t.float  "ess_score",                 default: 0.0
      t.float  "mips_score",                default: 0.0
      t.float  "phy_score",                 default: 0.0
      t.float  "coexp_score",               default: 0.0
      t.float  "exp_score",                 default: 0.0
      t.float  "pred_score",                default: 0.0
      t.float  "preppi_score",              default: 0.0
      t.string "db_entry",      limit: 100
      t.string "pubmed_id",     limit: 500
      t.string "organism",      limit: 20
      t.string "version",       limit: 5
      t.string "int_a_ensembl", limit: 20
      t.string "int_b_ensembl", limit: 20
    end

    add_index "honig_preppi_int_hsapien_filtered", ["int_a"], name: "int_a", using: :btree
    add_index "honig_preppi_int_hsapien_filtered", ["int_a_ensembl"], name: "int_a_ensembl", using: :btree
    add_index "honig_preppi_int_hsapien_filtered", ["int_b"], name: "int_b", using: :btree
    add_index "honig_preppi_int_hsapien_filtered", ["int_b_ensembl"], name: "int_b_ensembl", using: :btree
    add_index "honig_preppi_int_hsapien_filtered", ["organism"], name: "organism", using: :btree
    add_index "honig_preppi_int_hsapien_filtered", ["preppi_score"], name: "preppi_score", using: :btree

    create_table "honig_preppi_int_scerevisiae", id: false, force: true do |t|
      t.string "int_id",       limit: 20
      t.string "int_a",        limit: 20
      t.string "int_b",        limit: 20
      t.float  "str_score",                default: 0.0
      t.float  "go_score",                 default: 0.0
      t.float  "ess_score",                default: 0.0
      t.float  "mips_score",               default: 0.0
      t.float  "phy_score",                default: 0.0
      t.float  "coexp_score",              default: 0.0
      t.float  "exp_score",                default: 0.0
      t.float  "pred_score",               default: 0.0
      t.float  "preppi_score",             default: 0.0
      t.string "db_entry",     limit: 100
      t.string "pubmed_id",    limit: 500
      t.string "int_a_ORF",    limit: 20
      t.string "int_b_ORF",    limit: 20
    end

    add_index "honig_preppi_int_scerevisiae", ["int_a"], name: "int_a", using: :btree
    add_index "honig_preppi_int_scerevisiae", ["int_a_ORF"], name: "int_a_ORF", using: :btree
    add_index "honig_preppi_int_scerevisiae", ["int_b"], name: "int_b", using: :btree
    add_index "honig_preppi_int_scerevisiae", ["int_b_ORF"], name: "int_b_ORF", using: :btree
    add_index "honig_preppi_int_scerevisiae", ["preppi_score"], name: "preppi_score", using: :btree

    create_table "hsapien_bioGrid_interactions", force: true do |t|
      t.string "intA",          limit: 20
      t.string "intB",          limit: 20
      t.string "throughput",    limit: 40
      t.string "expSystemType", limit: 20
      t.string "expSystem",     limit: 40
      t.string "pubmedID",      limit: 10
    end

    add_index "hsapien_biogrid_interactions", ["intA", "intB", "pubmedID"], name: "intA", unique: true, using: :btree

    create_table "hsapien_ensembl_genes", force: true do |t|
      t.string   "ensemblID",           limit: 20,  default: "", null: false
      t.string   "geneBioType",         limit: 15,  default: "", null: false
      t.string   "geneName",            limit: 30
      t.string   "description",         limit: 500
      t.integer  "numberOfTranscripts",                          null: false
      t.datetime "updated_at"
      t.datetime "created_at"
    end

    add_index "hsapien_ensembl_genes", ["ensemblID"], name: "ensemblID", unique: true, using: :btree
    add_index "hsapien_ensembl_genes", ["ensemblID"], name: "ensembleID", using: :btree
    add_index "hsapien_ensembl_genes", ["geneBioType"], name: "geneBioType", using: :btree

    create_table "pwj_plasmids", force: true do |t|
      t.string   "number",              limit: 11
      t.string   "promoter",            limit: 11
      t.string   "yeast_selection",     limit: 11
      t.string   "bacterial_selection", limit: 11
      t.string   "gene",                limit: 20
      t.text     "comments"
      t.string   "parent",              limit: 11
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   "created_by",          limit: 50
      t.string   "updated_by",          limit: 50
      t.boolean  "empty_vector",                   default: false
    end

    add_index "pwj_plasmids", ["created_by"], name: "created_by", using: :btree
    add_index "pwj_plasmids", ["gene"], name: "gene", using: :btree
    add_index "pwj_plasmids", ["number"], name: "number", using: :btree
    add_index "pwj_plasmids", ["number"], name: "number_2", unique: true, using: :btree
    add_index "pwj_plasmids", ["promoter"], name: "promoter", using: :btree
    add_index "pwj_plasmids", ["updated_by"], name: "updated_by", using: :btree

    create_table "replicates", force: true do |t|
      t.integer "reps", null: false
    end

    add_index "replicates", ["reps"], name: "reps", using: :btree

    create_table "scerevisiae_baryshnikova_complex_data", force: true do |t|
      t.string "orf",     limit: 11,  default: "", null: false
      t.string "gene",    limit: 10
      t.string "complex", limit: 100, default: "", null: false
    end

    add_index "scerevisiae_baryshnikova_complex_data", ["orf", "complex"], name: "orf", unique: true, using: :btree

    create_table "scerevisiae_benschop_complex_data", force: true do |t|
      t.string "orf",     limit: 11,  default: "", null: false
      t.string "gene",    limit: 10
      t.string "complex", limit: 100, default: "", null: false
    end

    add_index "scerevisiae_benschop_complex_data", ["orf", "complex"], name: "orf", unique: true, using: :btree

    create_table "scerevisiae_bioGrid_interactions", force: true do |t|
      t.string "intA",          limit: 15
      t.string "intB",          limit: 15
      t.string "throughput",    limit: 30
      t.string "expSystemType", limit: 20
      t.string "expSystem",     limit: 40
      t.string "pubmedID",      limit: 10
    end

    add_index "scerevisiae_biogrid_interactions", ["intA", "intB", "pubmedID"], name: "intA", unique: true, using: :btree

    create_table "scerevisiae_genes", primary_key: "id", force: true do |t|
      t.string  "orf",        limit: 11
      t.string  "gene",        limit: 11
      t.string  "alias",       limit: 40
      t.string  "description", limit: 500
    end

    add_index "scerevisiae_genes", ["gene"], name: "gene", using: :btree
    add_index "scerevisiae_genes", ["id"], name: "id", unique: true, using: :btree
    add_index "scerevisiae_genes", ["orf"], name: "orf", using: :btree

    create_table "scerevisiae_go_process_associations", force: true do |t|
      t.string "gene",        limit: 11, default: "", null: false
      t.string "ORF",         limit: 11, default: "", null: false
      t.string "qualifier",   limit: 20
      t.string "go_id",       limit: 11, default: "", null: false
      t.string "dbReference", limit: 50
      t.string "evidence",    limit: 10
      t.string "withOrFrom",  limit: 4
      t.string "objectName",  limit: 50
      t.string "objectType",  limit: 10, default: "", null: false
      t.date   "date"
      t.string "assignedBy",  limit: 20
    end

    add_index "scerevisiae_go_process_associations", ["ORF", "go_id"], name: "ORF", unique: true, using: :btree
    add_index "scerevisiae_go_process_associations", ["go_id"], name: "go_id", using: :btree

    create_table "scerevisiae_go_terms", primary_key: "go_id", force: true do |t|
      t.string  "name",       limit: 50
      t.integer "size"
      t.text    "definition"
    end

    create_table "scerevisiae_hsapien_orthologs", force: true do |t|
      t.string   "humanEnsemblID",                        limit: 20,                    null: false
      t.string   "humanGeneName",                         limit: 30
      t.string   "yeastOrf",                              limit: 10, default: "",       null: false
      t.integer  "percentIdentityWithRespectToQueryGene"
      t.integer  "percentIdentityWithRespectToYeastGene"
      t.string   "homologyType",                          limit: 30
      t.string   "source",                                limit: 20, default: "",       null: false
      t.datetime "updated_at"
      t.string   "created_by",                            limit: 20, default: "script", null: false
      t.string   "updated_by",                            limit: 20
      t.datetime "created_at"
      t.boolean  "approved",                                         default: false,    null: false
    end

    add_index "scerevisiae_hsapien_orthologs", ["humanEnsemblID", "yeastOrf", "source"], name: "humanEnsemblID_2", unique: true, using: :btree
    add_index "scerevisiae_hsapien_orthologs", ["humanEnsemblID"], name: "humanEnsemblID", using: :btree
    add_index "scerevisiae_hsapien_orthologs", ["humanGeneName"], name: "humanGeneName", using: :btree
    add_index "scerevisiae_hsapien_orthologs", ["yeastOrf"], name: "yeastOrf", using: :btree

    create_table "scerevisiae_interactions_funNet", force: true do |t|
      t.string "intA",     limit: 10
      t.string "intB",     limit: 10
      t.float  "strength"
    end

    add_index "scerevisiae_interactions_funnet", ["intA", "intB"], name: "intA", unique: true, using: :btree
    add_index "scerevisiae_interactions_funnet", ["intA"], name: "intA_2", using: :btree
    add_index "scerevisiae_interactions_funnet", ["intB"], name: "intB", using: :btree

    create_table "screen_purposes", force: true do |t|
      t.string "purpose", limit: 20
    end

    add_index "screen_purposes", ["purpose"], name: "purpose", using: :btree

    create_table "screen_results", force: true do |t|
      t.integer "experiment_id"
      t.string  "plate",                               limit: 25
      t.string  "row",                                 limit: 5
      t.integer "column"
      t.float   "p_value"
      t.float   "z_score"
      t.float   "ratio"
      t.string  "ORF",                                 limit: 20
      t.float   "exp_colony_size_variance"
      t.integer "number_of_considered_exp_replicates"
      t.float   "exp_colony_circularity_mean"
      t.float   "exp_colony_circularity_variance"
      t.float   "exp_colony_size_mean"
      t.float   "comparer_colony_size_mean"
      t.string  "problem_flag",                        limit: 50
    end

    add_index "screen_results", ["exp_colony_circularity_mean"], name: "colonyCirularityMean", using: :btree
    add_index "screen_results", ["exp_colony_circularity_variance"], name: "colonyCircularityVariance", using: :btree
    add_index "screen_results", ["exp_colony_size_mean"], name: "colonySizeMean", using: :btree
    add_index "screen_results", ["exp_colony_size_variance"], name: "colonySizeVariance", using: :btree
    add_index "screen_results", ["experiment_id"], name: "experiment_id", using: :btree
    add_index "screen_results", ["number_of_considered_exp_replicates"], name: "numberOfReplicates", using: :btree
    add_index "screen_results", ["p_value"], name: "p_value", using: :btree
    add_index "screen_results", ["ratio"], name: "ratio", using: :btree
    add_index "screen_results", ["z_score"], name: "z_score", using: :btree

    create_table "screen_types", force: true do |t|
      t.string "screen_type", limit: 20
    end

    add_index "screen_types", ["screen_type"], name: "screen_type", using: :btree

    create_table "sessions", force: true do |t|
      t.text "a_session", null: false
    end

    create_table "spombe_bioGrid_interactions", force: true do |t|
      t.string "intA",          limit: 20
      t.string "intB",          limit: 20
      t.string "throughput",    limit: 20
      t.string "expSystemType", limit: 40
      t.string "expSystem",     limit: 40
      t.string "pubmedID",      limit: 10
    end

    add_index "spombe_biogrid_interactions", ["intA", "intB", "pubmedID"], name: "intA", unique: true, using: :btree

    create_table "strain_libraries", force: true do |t|
      t.string   "name",              limit: 100, default: "", null: false
      t.string   "mating_type",       limit: 11
      t.string   "selectable_marker", limit: 11
      t.string   "key_file_location"
      t.string   "background",        limit: 20
      t.boolean  "default"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.string   "created_by",        limit: 50
      t.string   "updated_by",        limit: 50
    end

    add_index "strain_libraries", ["name"], name: "name", using: :btree

    create_table "supported_organisms", force: true do |t|
      t.string "organism",        limit: 50
      t.string "biogrid_version", limit: 10
    end

    add_index "supported_organisms", ["organism"], name: "organism", using: :btree

    create_table "users", force: true do |t|
      t.string   "login",                  limit: 50, default: "",         null: false
      t.string   "hashed_password",        limit: 50
      t.string   "email",                  limit: 50
      t.string   "salt",                   limit: 50
      t.datetime "created_at"
      t.string   "permissions",            limit: 15, default: "standard", null: false
      t.string   "auth_token",             limit: 50
      t.datetime "password_reset_sent_at"
      t.string   "password_reset_token",   limit: 50
    end

    add_index "users", ["login"], name: "login", using: :btree
  end

  def self.down
    # drop all the tables if you really need
    # to support migration back to version 0
  end
end