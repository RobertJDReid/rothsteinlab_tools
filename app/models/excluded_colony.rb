class ExcludedColony < ActiveRecord::Base
  belongs_to :experiment
  belongs_to :experiment_raw_dataset
end
