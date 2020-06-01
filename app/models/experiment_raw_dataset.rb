class ExperimentRawDataset < ActiveRecord::Base
  belongs_to :density
  belongs_to :pwj_plasmid
  
  # these relationships work!
  has_many :experiment_comparer_raw_datasets, class_name: "Experiment", inverse_of: :experiment_comparer_raw_dataset
  has_many :experiment_query_raw_datasets, class_name: "Experiment", inverse_of: :experiment_comparer_raw_dataset
  #access all data with something like:
  # exp = Experiment.find(someID)
  # exp.experiment_query_raw_dataset.experiment_colony_data
  has_many :experiment_colony_data, class_name: "ExperimentColonyData", inverse_of: :experiment_raw_dataset
  has_many :excluded_colonies

  def self.doesLogDatasetAlreadyExist(plasmid,condition,density)
  	if(condition == '-')
  		condition = ''
  	end
  	
		e=ExperimentRawDataset.joins(:density).joins(:pwj_plasmid).select('experiment_raw_datasets.*, pwj_plasmids.number as pwj_number, densities.density as d_density').where("`condition` LIKE ? AND pwj_plasmids.number LIKE ? AND densities.density LIKE ?", condition, plasmid, density)
		if(e.nil? or e.length==0)
			e=ExperimentRawDataset.new
      e.comments = 'not found!'
    end
    return e
  end  	
  
  def date_pwj_plasmid_condition
    # logger.debug "bd = #{bd}, #{pwj}"
    @date_pwj_plasmid_condition = "#{bd} - #{pwj} - #{condition}"
  end
end
