class ScerevisiaeHsapienOrtholog < ActiveRecord::Base
	 belongs_to :scerevisiae_gene, foreign_key: 'yeastOrf'
		 # proc {"SELECT `gene` FROM `scerevisiae_genes` WHERE (`scerevisiae_genes`.orf = \"#{yeastOrf}\")"}

	# belongs_to :human_ensembl_gene, :foreign_key=>"humanEnsemblID"
	validate :properEnsemblID, :properYeastOrf
	validates_presence_of  :humanEnsemblID,:humanGeneName,:yeastOrf, :homologyType, :source
	validates_uniqueness_of :humanEnsemblID, :scope => [:yeastOrf], :case_sensitive=>false, :message => "This Human-yeast ortholog combination already exists."

	def self.processParams(params, current_user)
		# force false if permissions are wrong
		unless(current_user.permissions == 'admin' || current_user.permissions == 'labMember')
			params[:scerevisiae_hsapien_ortholog][:approved] = false
		end
		params[:scerevisiae_hsapien_ortholog][:humanEnsemblID].upcase!
		params[:scerevisiae_hsapien_ortholog][:humanGeneName].upcase!
		params[:scerevisiae_hsapien_ortholog][:yeastOrf].upcase!
		params[:scerevisiae_hsapien_ortholog][:created_by] = current_user.login
		params[:scerevisiae_hsapien_ortholog][:updated_by] = current_user.login
		return params
	end

	def self.email_pair(msg)
		msg = "#{msg}\n\n MAKE SURE TO APPROVE THIS INTERACTION IN DATABASE IF IT IS VALID!"
	  GeneralMailer.general_mail('admin@rothsteinlab.com', 'NEW ORTHOLOG SUBMISSION...', msg).deliver
	end

	private

	def properEnsemblID
		#puts "human = #{humanEnsemblID} #{params.inspect}"
    errors.add(:humanEnsemblID, 'Invalid Ensembl ID') unless HsapienEnsemblGene.exists?(["ensemblID = ?", humanEnsemblID])
	end

	def properYeastOrf
    errors.add(:yeastOrf, 'Invalid <em>S. cerevisiae</em> ORF') unless ScerevisiaeGene.exists?(["orf = ?", yeastOrf])
	end

end