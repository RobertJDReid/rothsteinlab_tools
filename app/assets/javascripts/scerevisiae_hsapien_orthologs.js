$(document).ready(function(){
	$("#theForm").validate({
		rules:{
			'scerevisiae_hsapien_ortholog[humanGeneName]':{
				minlength:3,
				maxlength:10,
				remote:{
					url: '../hsapien_ensembl_genes/getEnsemblID',
					type: 'get', 
					dataType: "json",
					//async: false,
					dataFilter: function(data) {
						data = JSON.parse(data);
						if(!data || data.length < 1 || data.error){
							$('#scerevisiae_hsapien_ortholog_humanEnsemblID').val("?");
							//$('#ensemblLookupMsg').html("");
							return '"Invalid human gene name!"';
						}
						//$('#ensemblLookupMsg').html("Gene: "+data.geneName);
						$('#scerevisiae_hsapien_ortholog_humanEnsemblID').val(data.ensemblID);
						return '"true"';
					}
				}
			},
			'scerevisiae_hsapien_ortholog[humanEnsemblID]':{minlength:15,maxlength:15}, // must begin with ENSG followed by 11 numbers [0-9]
			'tempYeast':{
				minlength:3,
				maxlength:9,
				remote:{
					url: '../scerevisiae_genes/validate',
					type: 'get', 
					//async: false,
					dataFilter: function(data) {
						data = JSON.parse(data);
						if(!data || data.length < 1 || data.error){
							$('#validYeastGene').hide();
							return '"Invalid yeast ORF/gene name!"';
						}
						$('#tempYeast').effect('highlight',{},1000);
						$('#validYeastGene').show();
						$("#yeastOrf").val(data.orf);
						return '"true"';
					},
					data: {
						gene: function() { return $('#tempYeast').val();}
					},
				}
			}
					//regex: "^[Y|y][A-Pa-p][L|R|l|r][0-9]{3}[W|w|C|c](?:-[A-Za-z])?$"} // orf_pattern='^[Y|y][A-Pa-p][L|R|l|r][0-9]{3}[W|w|C|c](?:-[A-Za-z])?$';
		},
		ignoreTitle: true
	});
});