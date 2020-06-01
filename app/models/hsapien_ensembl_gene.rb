class HsapienEnsemblGene < ActiveRecord::Base

  def self.findEnsemblFromGene(params)
  	if(!params[:scerevisiae_hsapien_ortholog] || !params[:scerevisiae_hsapien_ortholog][:humanGeneName])
    return {"error"=>"bad data"}
  end
  # take is a bit faster than first as the sql is "Limit 1" as opposed to "order by [primary key] asc LIMIT 1"
  result = HsapienEnsemblGene.select('geneName, ensemblID').where("`geneName` LIKE ?", params[:scerevisiae_hsapien_ortholog][:humanGeneName]).take #.map{|ortho| ortho.humanEnsemblID}
  if(!result)
  	return "" 
  end
  return {"ensemblID"=>result.ensemblID}#,"geneName"=>result.humanGeneName}
  end

end
