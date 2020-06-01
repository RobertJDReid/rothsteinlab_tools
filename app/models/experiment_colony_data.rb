class ExperimentColonyData < ActiveRecord::Base
  belongs_to :experiment_raw_dataset, class_name: "ExperimentRawDataset", foreign_key: :experiment_raw_dataset_id, inverse_of: :experiment_colony_data
end
