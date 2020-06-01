class Experiment < ActiveRecord::Base
  # these belongs_to relationships work! to access them on a experiment try the following
  # exp = Experiment.find(someID)
  # exp.experiment_query_raw_dataset
  belongs_to :experiment_query_raw_dataset, class_name: "ExperimentRawDataset", foreign_key: :experiment_query_raw_dataset_id, inverse_of: :experiment_query_raw_datasets
  belongs_to :experiment_comparer_raw_dataset, class_name: "ExperimentRawDataset", foreign_key: :experiment_comparer_raw_dataset_id, inverse_of: :experiment_comparer_raw_datasets
  has_many :excluded_colonies
  
  # belongs_to :project
  # has_many :data_averages, :dependent => :destroy
  # has_many :screen_files, :dependent => :destroy
  validates_presence_of :density, :comparer, :query, :condition, :replicates, :screen_type, :library_used,
                        :donor_strain_used, :comments, :screen_purpose, :created_by, :updated_by, :number_of_plates, :performed_by
                        :incubation_temperature
  validates_numericality_of :replicates, :density, :number_of_plates
  validates_inclusion_of :created_by, :in => User.select('login').where("`permissions` IN ('admin','labMember')").map { |e| e.login  }
  validates_inclusion_of :updated_by, :in => User.select('login').where("`permissions` IN ('admin','labMember')").map { |e| e.login  }
  validates_inclusion_of :performed_by, :in => User.select('login').where("`permissions` IN ('admin','labMember')").map { |e| e.login  }
  validates_inclusion_of :density, :in => Density.select('density').map { |e| e.density  }
  validates_inclusion_of :comparer, :in => PwjPlasmid.select('number').map { |e| e.number  }
  validates_inclusion_of :query, :in => PwjPlasmid.select('number').map { |e| e.number  }
  validates_inclusion_of :replicates, :in => Replicate.select('reps').map { |e| e.reps  }
  validates_inclusion_of :screen_type, :in => ScreenType.select('screen_type').map { |e| e.screen_type  }
  validates_inclusion_of :library_used, :in => StrainLibrary.select('name').map { |e| e.name  }
  validates_inclusion_of :donor_strain_used, :in => Donor.select('wNumber').map { |e| e.wNumber  }
  validates_inclusion_of :screen_purpose, :in => ScreenPurpose.select('purpose').map { |e| e.purpose  }
  validate :comparer_dataset_id_exists
  validate :query_dataset_id_exists

  # validates :date, presence: true, date: {on_or_after: :screen_date_start}

  # validates_presence_of :lawn_growth_time, :library_age, _library_growth_time, :mating_time, :first_gal_leu, :second_gal_leu, :final_selection
  # validates_numericality_of :library_age, :library_growth_time, :donor_growth_time, :number_matings_per_donor_lawn, :mating_time, :first_gal_leu, :second_gal_leu, :final_selection

  def self.doesExperimentAlreadyExist(query,condition)
  	if(condition == '-')
  		condition = ''
  	end
		e=Experiment.where("`query` LIKE ? AND `condition` LIKE ?", query, condition)	
		if(e.nil? or e.length==0)
			e=Experiment.new
      e.comments = 'not found!'
    end
    return e
  end

  def self.screen_date_start
    "01/01/2001".to_datetime
  end

  def self.experiment_datasets(exp, option)
    ExperimentRawDataset.joins(:pwj_plasmid).joins(:density).select('experiment_raw_datasets.id as exp_raw_set_id, experiment_raw_datasets.batch_date as bd, experiment_raw_datasets.condition, experiment_raw_datasets.pwj_plasmid_id, pwj_plasmids.number as pwj, densities.density').where('pwj_plasmids.number LIKE ? and experiment_raw_datasets.condition LIKE ? and experiment_raw_datasets.number_of_plates = ? and densities.density = ?', exp[option], exp.condition, exp.number_of_plates, exp.density)
  end

  private 

  def comparer_dataset_id_exists
    self.errors.add(:experiment_comparer_raw_dataset, "doesn't exist") unless dataset_id_exists(self.experiment_comparer_raw_dataset_id)
  end

  def query_dataset_id_exists
    self.errors.add(:experiment_query_raw_dataset, "doesn't exist") unless dataset_id_exists(self.experiment_query_raw_dataset_id)
  end

  def dataset_id_exists(theID)
    exists = true
    if(!theID.blank?)
      exists = ExperimentRawDataset.exists?(theID)
    end
    return exists
  end

  
end


