# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20150513123809) do

  create_table "densities", force: :cascade do |t|
    t.integer "density", limit: 4,             null: false
    t.integer "rows",    limit: 2, default: 1, null: false
    t.integer "columns", limit: 2, default: 1, null: false
  end

  add_index "densities", ["density"], name: "density", using: :btree

  create_table "dmelanogaster_droidb_interactions", force: :cascade do |t|
    t.string   "flyID_a",              limit: 12,                             null: false
    t.string   "flyID_b",              limit: 12,                             null: false
    t.string   "symbol_a",             limit: 40
    t.string   "symbol_b",             limit: 40
    t.text     "url",                  limit: 65535
    t.string   "interaction_category", limit: 20
    t.string   "interaction_type",     limit: 100
    t.decimal  "score",                              precision: 15, scale: 5
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "dmelanogaster_droidb_interactions", ["flyID_a"], name: "flyB", using: :btree
  add_index "dmelanogaster_droidb_interactions", ["flyID_b"], name: "flyA", using: :btree
  add_index "dmelanogaster_droidb_interactions", ["interaction_category"], name: "drosophilia_i_category", using: :btree
  add_index "dmelanogaster_droidb_interactions", ["interaction_type"], name: "drosophilia_i_type", using: :btree
  add_index "dmelanogaster_droidb_interactions", ["symbol_a", "symbol_b", "interaction_type"], name: "uniques", unique: true, using: :btree

  create_table "donors", force: :cascade do |t|
    t.string   "wNumber",     limit: 15,    default: "", null: false
    t.string   "mating_type", limit: 10,    default: "", null: false
    t.text     "notes",       limit: 65535
    t.string   "genotype",    limit: 255
    t.string   "created_by",  limit: 50
    t.datetime "updated_at"
    t.datetime "created_at"
    t.string   "updated_by",  limit: 50
  end

  add_index "donors", ["created_by"], name: "created_by", using: :btree
  add_index "donors", ["updated_by"], name: "updated_by", using: :btree
  add_index "donors", ["wNumber"], name: "Wnumber", using: :btree

  create_table "ensembl_version", force: :cascade do |t|
    t.string   "syncedVersionNumber", limit: 4
    t.datetime "dateLastSynced"
  end

  create_table "excluded_colonies", force: :cascade do |t|
    t.integer "experiment_raw_dataset_id", limit: 4
    t.string  "plate",                     limit: 50
    t.string  "row",                       limit: 5
    t.integer "column",                    limit: 8
  end

  add_index "excluded_colonies", ["column"], name: "index_excluded_colonies_on_column", using: :btree
  add_index "excluded_colonies", ["experiment_raw_dataset_id"], name: "index_excluded_colonies_on_experiment_raw_dataset_id", using: :btree
  add_index "excluded_colonies", ["plate"], name: "index_excluded_colonies_on_plate", using: :btree
  add_index "excluded_colonies", ["row"], name: "index_excluded_colonies_on_row", using: :btree

  create_table "experiment_colony_data", force: :cascade do |t|
    t.string  "plate",                     limit: 50
    t.string  "row",                       limit: 5
    t.integer "column",                    limit: 8
    t.decimal "colony_measurement",                   precision: 15, scale: 5
    t.decimal "colony_circularity",                   precision: 15, scale: 5
    t.integer "experiment_raw_dataset_id", limit: 4
  end

  add_index "experiment_colony_data", ["column"], name: "index_experiment_colony_data_on_column", using: :btree
  add_index "experiment_colony_data", ["experiment_raw_dataset_id"], name: "index_experiment_colony_data_on_experiment_raw_dataset_id", using: :btree
  add_index "experiment_colony_data", ["plate"], name: "index_experiment_colony_data_on_plate", using: :btree
  add_index "experiment_colony_data", ["row"], name: "index_experiment_colony_data_on_row", using: :btree

  create_table "experiment_raw_datasets", force: :cascade do |t|
    t.integer  "density_id",       limit: 4
    t.integer  "pwj_plasmid_id",   limit: 4
    t.string   "condition",        limit: 50
    t.integer  "number_of_plates", limit: 4
    t.date     "batch_date"
    t.string   "updated_by",       limit: 50
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "comments",         limit: 65535
  end

  add_index "experiment_raw_datasets", ["density_id"], name: "index_experiment_raw_datasets_on_density_id", using: :btree
  add_index "experiment_raw_datasets", ["pwj_plasmid_id"], name: "index_experiment_raw_datasets_on_pwj_plasmid_id", using: :btree

  create_table "experiments", force: :cascade do |t|
    t.date     "batch_date"
    t.integer  "density",                            limit: 4
    t.string   "comparer",                           limit: 11
    t.string   "query",                              limit: 11
    t.string   "condition",                          limit: 255,   default: "",  null: false
    t.integer  "replicates",                         limit: 4,     default: -1,  null: false
    t.string   "screen_type",                        limit: 75,    default: "",  null: false
    t.string   "library_used",                       limit: 100,   default: "-", null: false
    t.string   "donor_strain_used",                  limit: 15,    default: "-", null: false
    t.text     "comments",                           limit: 65535
    t.string   "screen_purpose",                     limit: 20,    default: "",  null: false
    t.string   "created_by",                         limit: 50,    default: ""
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "updated_by",                         limit: 50
    t.integer  "number_of_plates",                   limit: 4
    t.string   "performed_by",                       limit: 50
    t.integer  "incubation_temperature",             limit: 4,     default: 30
    t.integer  "experiment_comparer_raw_dataset_id", limit: 4
    t.integer  "experiment_query_raw_dataset_id",    limit: 4
    t.integer  "pre_screen_library_replicates",      limit: 1
    t.integer  "mating_time",                        limit: 2
    t.integer  "first_gal_leu_time",                 limit: 2
    t.integer  "second_gal_leu_time",                limit: 2
    t.integer  "final_incubation_time",              limit: 2
  end

  add_index "experiments", ["comparer"], name: "comparer", using: :btree
  add_index "experiments", ["condition"], name: "testCondition", using: :btree
  add_index "experiments", ["created_by"], name: "experimentPerformedBy", using: :btree
  add_index "experiments", ["density"], name: "density", using: :btree
  add_index "experiments", ["donor_strain_used"], name: "donor_strain_used", using: :btree
  add_index "experiments", ["experiment_comparer_raw_dataset_id"], name: "comparer_dataset_id_index", using: :btree
  add_index "experiments", ["experiment_query_raw_dataset_id"], name: "query_dataset_id_index", using: :btree
  add_index "experiments", ["library_used"], name: "library_used", using: :btree
  add_index "experiments", ["performed_by"], name: "performed_by", using: :btree
  add_index "experiments", ["query"], name: "query", using: :btree
  add_index "experiments", ["replicates"], name: "replicates", using: :btree
  add_index "experiments", ["screen_purpose"], name: "screenPurpose", using: :btree
  add_index "experiments", ["screen_type"], name: "screen_type", using: :btree
  add_index "experiments", ["updated_by"], name: "updated_by", using: :btree

  create_table "honig_preppi_int_hsapien", id: false, force: :cascade do |t|
    t.string   "int_id",        limit: 20
    t.string   "int_a",         limit: 20
    t.string   "int_b",         limit: 20
    t.float    "str_score",     limit: 24,  default: 0.0
    t.float    "go_score",      limit: 24,  default: 0.0
    t.float    "ess_score",     limit: 24,  default: 0.0
    t.float    "mips_score",    limit: 24,  default: 0.0
    t.float    "phy_score",     limit: 24,  default: 0.0
    t.float    "coexp_score",   limit: 24,  default: 0.0
    t.float    "exp_score",     limit: 24,  default: 0.0
    t.float    "pred_score",    limit: 24,  default: 0.0
    t.float    "preppi_score",  limit: 24,  default: 0.0
    t.string   "db_entry",      limit: 100
    t.string   "pubmed_id",     limit: 500
    t.string   "organism",      limit: 20
    t.datetime "Timestamp"
    t.string   "version",       limit: 5
    t.string   "int_a_ensembl", limit: 20
    t.string   "int_b_ensembl", limit: 20
  end

  add_index "honig_preppi_int_hsapien", ["int_a"], name: "int_a", using: :btree
  add_index "honig_preppi_int_hsapien", ["int_a_ensembl"], name: "int_a_ensembl", using: :btree
  add_index "honig_preppi_int_hsapien", ["int_b"], name: "int_b", using: :btree
  add_index "honig_preppi_int_hsapien", ["int_b_ensembl"], name: "int_b_ensembl", using: :btree
  add_index "honig_preppi_int_hsapien", ["organism"], name: "organism", using: :btree

  create_table "honig_preppi_int_hsapien_filtered", id: false, force: :cascade do |t|
    t.string "int_id",        limit: 20
    t.string "int_a",         limit: 20
    t.string "int_b",         limit: 20
    t.float  "str_score",     limit: 24,  default: 0.0
    t.float  "go_score",      limit: 24,  default: 0.0
    t.float  "ess_score",     limit: 24,  default: 0.0
    t.float  "mips_score",    limit: 24,  default: 0.0
    t.float  "phy_score",     limit: 24,  default: 0.0
    t.float  "coexp_score",   limit: 24,  default: 0.0
    t.float  "exp_score",     limit: 24,  default: 0.0
    t.float  "pred_score",    limit: 24,  default: 0.0
    t.float  "preppi_score",  limit: 24,  default: 0.0
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

  create_table "honig_preppi_int_scerevisiae", id: false, force: :cascade do |t|
    t.string   "int_id",       limit: 20
    t.string   "int_a",        limit: 20
    t.string   "int_b",        limit: 20
    t.float    "str_score",    limit: 24,  default: 0.0
    t.float    "go_score",     limit: 24,  default: 0.0
    t.float    "ess_score",    limit: 24,  default: 0.0
    t.float    "mips_score",   limit: 24,  default: 0.0
    t.float    "phy_score",    limit: 24,  default: 0.0
    t.float    "coexp_score",  limit: 24,  default: 0.0
    t.float    "exp_score",    limit: 24,  default: 0.0
    t.float    "pred_score",   limit: 24,  default: 0.0
    t.float    "preppi_score", limit: 24,  default: 0.0
    t.string   "db_entry",     limit: 100
    t.string   "pubmed_id",    limit: 500
    t.string   "organism",     limit: 20
    t.datetime "Timestamp"
    t.string   "version",      limit: 5
    t.string   "int_a_ORF",    limit: 20
    t.string   "int_b_ORF",    limit: 20
  end

  add_index "honig_preppi_int_scerevisiae", ["int_a"], name: "int_a", using: :btree
  add_index "honig_preppi_int_scerevisiae", ["int_a_ORF"], name: "int_a_ORF", using: :btree
  add_index "honig_preppi_int_scerevisiae", ["int_b"], name: "int_b", using: :btree
  add_index "honig_preppi_int_scerevisiae", ["int_b_ORF"], name: "int_b_ORF", using: :btree
  add_index "honig_preppi_int_scerevisiae", ["organism"], name: "organism", using: :btree
  add_index "honig_preppi_int_scerevisiae", ["preppi_score"], name: "preppi_score", using: :btree

  create_table "hsapien_bioGrid_interactions", force: :cascade do |t|
    t.string "intA",          limit: 40
    t.string "intB",          limit: 40
    t.string "throughput",    limit: 40
    t.string "expSystemType", limit: 20
    t.string "expSystem",     limit: 40
    t.string "pubmedID",      limit: 10
  end

  add_index "hsapien_bioGrid_interactions", ["intA", "intB", "pubmedID"], name: "intA", unique: true, using: :btree

  create_table "hsapien_ensembl_genes", force: :cascade do |t|
    t.string   "ensemblID",           limit: 20,  default: "", null: false
    t.string   "geneBioType",         limit: 15,  default: "", null: false
    t.string   "geneName",            limit: 30
    t.string   "description",         limit: 500
    t.integer  "numberOfTranscripts", limit: 4,                null: false
    t.datetime "updated_at"
    t.datetime "created_at"
  end

  add_index "hsapien_ensembl_genes", ["ensemblID"], name: "ensemblID", unique: true, using: :btree
  add_index "hsapien_ensembl_genes", ["ensemblID"], name: "ensembleID", using: :btree
  add_index "hsapien_ensembl_genes", ["geneBioType"], name: "geneBioType", using: :btree

  create_table "pwj_plasmids", force: :cascade do |t|
    t.string   "number",              limit: 11
    t.string   "promoter",            limit: 11
    t.string   "yeast_selection",     limit: 11
    t.string   "bacterial_selection", limit: 11
    t.string   "gene",                limit: 20
    t.text     "comments",            limit: 65535
    t.string   "parent",              limit: 11
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "created_by",          limit: 50
    t.string   "updated_by",          limit: 50
    t.boolean  "empty_vector",        limit: 1,     default: false
  end

  add_index "pwj_plasmids", ["created_by"], name: "created_by", using: :btree
  add_index "pwj_plasmids", ["gene"], name: "gene", using: :btree
  add_index "pwj_plasmids", ["number"], name: "number", using: :btree
  add_index "pwj_plasmids", ["number"], name: "number_2", unique: true, using: :btree
  add_index "pwj_plasmids", ["promoter"], name: "promoter", using: :btree
  add_index "pwj_plasmids", ["updated_by"], name: "updated_by", using: :btree

  create_table "replicates", force: :cascade do |t|
    t.integer "reps", limit: 4, null: false
  end

  add_index "replicates", ["reps"], name: "reps", using: :btree

  create_table "scerevisiae_baryshnikova_complex_data", force: :cascade do |t|
    t.string "orf",     limit: 11,  default: "", null: false
    t.string "gene",    limit: 10
    t.string "complex", limit: 100, default: "", null: false
  end

  add_index "scerevisiae_baryshnikova_complex_data", ["orf", "complex"], name: "orf", unique: true, using: :btree

  create_table "scerevisiae_benschop_complex_data", force: :cascade do |t|
    t.string "orf",     limit: 11,  default: "", null: false
    t.string "gene",    limit: 10
    t.string "complex", limit: 100, default: "", null: false
  end

  add_index "scerevisiae_benschop_complex_data", ["orf", "complex"], name: "orf", unique: true, using: :btree

  create_table "scerevisiae_bioGrid_interactions", force: :cascade do |t|
    t.string "intA",          limit: 40
    t.string "intB",          limit: 40
    t.string "throughput",    limit: 40
    t.string "expSystemType", limit: 20
    t.string "expSystem",     limit: 40
    t.string "pubmedID",      limit: 10
  end

  add_index "scerevisiae_bioGrid_interactions", ["intA", "intB", "pubmedID"], name: "intA", unique: true, using: :btree

  create_table "scerevisiae_genes", primary_key: "orf", force: :cascade do |t|
    t.string  "gene",        limit: 11
    t.string  "alias",       limit: 200
    t.string  "description", limit: 500
    t.integer "id",          limit: 4,   null: false
  end

  add_index "scerevisiae_genes", ["gene"], name: "gene", using: :btree
  add_index "scerevisiae_genes", ["id"], name: "id", unique: true, using: :btree
  add_index "scerevisiae_genes", ["orf"], name: "orf", using: :btree

  create_table "scerevisiae_go_process_associations", force: :cascade do |t|
    t.string "gene",        limit: 11,  default: "", null: false
    t.string "ORF",         limit: 11,  default: "", null: false
    t.string "qualifier",   limit: 20
    t.string "go_id",       limit: 11,  default: "", null: false
    t.string "dbReference", limit: 400
    t.string "evidence",    limit: 20
    t.string "withOrFrom",  limit: 400
    t.string "objectName",  limit: 100
    t.string "objectType",  limit: 10,  default: "", null: false
    t.date   "date"
    t.string "assignedBy",  limit: 50
  end

  add_index "scerevisiae_go_process_associations", ["ORF", "go_id"], name: "ORF", unique: true, using: :btree
  add_index "scerevisiae_go_process_associations", ["go_id"], name: "go_id", using: :btree

  create_table "scerevisiae_go_terms", primary_key: "go_id", force: :cascade do |t|
    t.string  "name",       limit: 250
    t.integer "size",       limit: 4
    t.text    "definition", limit: 65535
  end

  create_table "scerevisiae_hsapien_orthologs", force: :cascade do |t|
    t.string   "humanEnsemblID",                        limit: 20,                    null: false
    t.string   "humanGeneName",                         limit: 30
    t.string   "yeastOrf",                              limit: 10, default: "",       null: false
    t.integer  "percentIdentityWithRespectToQueryGene", limit: 4
    t.integer  "percentIdentityWithRespectToYeastGene", limit: 4
    t.string   "homologyType",                          limit: 30
    t.string   "source",                                limit: 20, default: "",       null: false
    t.datetime "updated_at"
    t.string   "created_by",                            limit: 20, default: "script", null: false
    t.string   "updated_by",                            limit: 20
    t.datetime "created_at"
    t.integer  "approved",                              limit: 1,                     null: false
  end

  add_index "scerevisiae_hsapien_orthologs", ["approved"], name: "approved", using: :btree
  add_index "scerevisiae_hsapien_orthologs", ["humanEnsemblID", "yeastOrf", "source"], name: "humanEnsemblID_2", unique: true, using: :btree
  add_index "scerevisiae_hsapien_orthologs", ["humanEnsemblID"], name: "humanEnsemblID", using: :btree
  add_index "scerevisiae_hsapien_orthologs", ["humanGeneName"], name: "humanGeneName", using: :btree
  add_index "scerevisiae_hsapien_orthologs", ["yeastOrf"], name: "yeastOrf", using: :btree

  create_table "scerevisiae_interactions_funNet", force: :cascade do |t|
    t.string "intA",     limit: 10
    t.string "intB",     limit: 10
    t.float  "strength", limit: 24
  end

  add_index "scerevisiae_interactions_funNet", ["intA", "intB"], name: "intA", unique: true, using: :btree
  add_index "scerevisiae_interactions_funNet", ["intA"], name: "intA_2", using: :btree
  add_index "scerevisiae_interactions_funNet", ["intB"], name: "intB", using: :btree

  create_table "screen_purposes", force: :cascade do |t|
    t.string "purpose", limit: 20
  end

  add_index "screen_purposes", ["purpose"], name: "purpose", using: :btree

  create_table "screen_results", force: :cascade do |t|
    t.integer "experiment_id",                       limit: 4
    t.string  "plate",                               limit: 25
    t.string  "row",                                 limit: 5
    t.integer "column",                              limit: 4
    t.float   "p_value",                             limit: 24
    t.float   "z_score",                             limit: 24
    t.float   "ratio",                               limit: 24
    t.string  "ORF",                                 limit: 20
    t.float   "exp_colony_size_variance",            limit: 24
    t.integer "number_of_considered_exp_replicates", limit: 4
    t.float   "exp_colony_circularity_mean",         limit: 24
    t.float   "exp_colony_circularity_variance",     limit: 24
    t.float   "exp_colony_size_mean",                limit: 24
    t.float   "comparer_colony_size_mean",           limit: 24
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

  create_table "screen_types", force: :cascade do |t|
    t.string "screen_type", limit: 75, default: "", null: false
  end

  add_index "screen_types", ["screen_type"], name: "type", using: :btree

  create_table "sessions", force: :cascade do |t|
    t.text "a_session", limit: 65535
  end

  create_table "spombe_bioGrid_interactions", force: :cascade do |t|
    t.string "intA",          limit: 40
    t.string "intB",          limit: 40
    t.string "throughput",    limit: 40
    t.string "expSystemType", limit: 20
    t.string "expSystem",     limit: 40
    t.string "pubmedID",      limit: 10
  end

  add_index "spombe_bioGrid_interactions", ["intA", "intB", "pubmedID"], name: "intA", unique: true, using: :btree

  create_table "strain_libraries", force: :cascade do |t|
    t.string   "name",              limit: 100, default: "", null: false
    t.string   "mating_type",       limit: 11
    t.string   "selectable_marker", limit: 11
    t.string   "key_file_location", limit: 255
    t.string   "background",        limit: 20
    t.boolean  "default",           limit: 1
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "created_by",        limit: 50
    t.string   "updated_by",        limit: 50
    t.string   "short_name",        limit: 15
  end

  add_index "strain_libraries", ["name"], name: "name", using: :btree

  create_table "supported_organisms", force: :cascade do |t|
    t.string "organism",        limit: 50
    t.string "biogrid_version", limit: 10
  end

  add_index "supported_organisms", ["organism"], name: "organism", using: :btree

  create_table "users", force: :cascade do |t|
    t.string   "login",                  limit: 50, default: "",         null: false
    t.string   "hashed_password",        limit: 50, default: ""
    t.string   "auth_token",             limit: 50
    t.string   "password_reset_token",   limit: 50
    t.datetime "password_reset_sent_at"
    t.string   "email",                  limit: 50
    t.string   "salt",                   limit: 50
    t.datetime "created_at"
    t.string   "permissions",            limit: 15, default: "standard", null: false
  end

  add_index "users", ["login"], name: "login", using: :btree

  add_foreign_key "donors", "users", column: "created_by", primary_key: "login", name: "donors_ibfk_1", on_update: :cascade
  add_foreign_key "donors", "users", column: "updated_by", primary_key: "login", name: "donors_ibfk_2", on_update: :cascade
  add_foreign_key "experiments", "densities", column: "density", primary_key: "density", name: "experiments_ibfk_20", on_update: :cascade
  add_foreign_key "experiments", "donors", column: "donor_strain_used", primary_key: "wNumber", name: "experiments_ibfk_17", on_update: :cascade
  add_foreign_key "experiments", "pwj_plasmids", column: "comparer", primary_key: "number", name: "experiments_ibfk_21", on_update: :cascade
  add_foreign_key "experiments", "pwj_plasmids", column: "query", primary_key: "number", name: "experiments_ibfk_22", on_update: :cascade
  add_foreign_key "experiments", "replicates", column: "replicates", primary_key: "reps", name: "experiments_ibfk_11", on_update: :cascade
  add_foreign_key "experiments", "screen_purposes", column: "screen_purpose", primary_key: "purpose", name: "experiments_ibfk_27", on_update: :cascade
  add_foreign_key "experiments", "screen_types", column: "screen_type", primary_key: "screen_type", name: "experiments_ibfk_28", on_update: :cascade
  add_foreign_key "experiments", "strain_libraries", column: "library_used", primary_key: "name", name: "experiments_ibfk_23", on_update: :cascade
  add_foreign_key "experiments", "users", column: "created_by", primary_key: "login", name: "experiments_ibfk_15", on_update: :cascade
  add_foreign_key "experiments", "users", column: "performed_by", primary_key: "login", name: "experiments_ibfk_26", on_update: :cascade
  add_foreign_key "experiments", "users", column: "updated_by", primary_key: "login", name: "experiments_ibfk_16", on_update: :cascade
  add_foreign_key "pwj_plasmids", "users", column: "created_by", primary_key: "login", name: "pwj_plasmids_ibfk_1", on_update: :cascade
  add_foreign_key "pwj_plasmids", "users", column: "updated_by", primary_key: "login", name: "pwj_plasmids_ibfk_2", on_update: :cascade
  add_foreign_key "scerevisiae_hsapien_orthologs", "hsapien_ensembl_genes", column: "humanEnsemblID", primary_key: "ensemblID", name: "scerevisiae_hsapien_orthologs_ibfk_1", on_update: :cascade
  add_foreign_key "scerevisiae_hsapien_orthologs", "scerevisiae_genes", column: "yeastOrf", primary_key: "orf", name: "scerevisiae_hsapien_orthologs_ibfk_2", on_update: :cascade
  add_foreign_key "screen_results", "experiments", name: "screen_results_ibfk_1", on_update: :cascade, on_delete: :cascade
end
