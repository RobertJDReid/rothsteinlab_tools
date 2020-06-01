$(document).ready(function(){
	$('#layout').fadeIn();
	parent.killFlash();
	$('#generateOutput').on('submit',function(){
		parent.setupFlash(true, 'Generating Excel File Output...'); 
		copy('chosen_sets', 'chosen_sets1');
	});
	$('.sv_close').click(function(){
		this.parentNode.style.display='none';
	});
	$('#changePval').on('submit',function(){parent.setupFlash(true, 'Re-rendering page...');});

	$('#plateJumpButton').click(function(){
		if($('#jump option:selected').prop('disabled') != 'disabled'){
			parent.setupFlash(true, 'Generating Comparison Cartoons...');
			submitForm($('#jump option:selected').val());
		}
	});
	$('#jump option:selected').prop('disabled', 'disabled');
	$('#jump').change(function(){
		if($('#jump option:selected').prop('disabled') != 'disabled'){
			$('#plateJumpButton').prop('disabled', '');
		}
		else{$('#plateJumpButton').prop('disabled', 'disabled');}
	});

	$('#comboToChange').change(function(){
		toggleNumbers(this, $('#front_pval'), $('#end_pval'));
	});

	$('#front_pval, #end_pval').change(function(){changeHiddenPval();});
});

// gathers all items with the give class and hides all of them except 'divToShow'
function showHideDivs(divToShow, className){
	if(divToShow == 'hitListDiv'){
		divToShow+='-'+$('#toc li.current').prop('id');
	}
	var isVisible = $('#'+divToShow).is(':visible');
	$('.'+className).slideUp();
	if(!isVisible){	$('#'+divToShow).slideDown();}
}

function copy(chosen_sets, chosen_sets1){
	if($('#'+chosen_sets).length>0){	
		if(!$('#'+chosen_sets).val()){	$('#'+chosen_sets1).val('');	}
		else{$('#'+chosen_sets1).val($('#'+chosen_sets).val());}
	}
} 
//window.onbeforeunload=init;

function redirect_to_image_setup(){
	var answer=confirm("Are you sure you want to go back to the layout page?  If you do this you will lose all the data you have selected.\nIf you would like to keep your data, scroll to the bottom of this page and click on the button labeled 'Click here to retrieve your selected colony sets'");
	if(answer){
		window.location="/tools/screen_mill/sv_engine";
	}
}

function redirect_to_FACS_setup(){
	var answer=confirm("Are you sure you want to go back to the FACS setup page?'");
	if(answer){
		window.location="/tools/screen_mill/FACS_analysis";
	}
}

function addToSummary(onGuys){
	var on_guys=onGuys.split(" ~~> ").join('</li><li>');
	$('#Visible_list').append('<li>'+on_guys+'</li>');
}

function submitForm(plateNum){
	$('#current_page_displayed').val(plateNum);
	document.imagelayout.submit();
}

function toggleNumbers(elem, front, end){
	if(elem.options[elem.selectedIndex].value != 'filler'){
		front.prop('disabled',false);
		end.prop('disabled',false);
	}
	else{
		front.prop('disabled','disabled');
		end.prop('disabled','disabled');
	}
}

function changeHiddenPval(){
	var pval=0;
	var front=$('#front_pval').val()
	var end_part=$('#end_pval').val()
	pval=front*Math.pow(10,end_part);
	var combo=$('#comboToChange').val();
	$('#combo').val(combo);
	$('#adjusted_pthresh').val(pval);
}

function AddRemoveSets(curSet, plateID){
	var curSetID = $(curSet).prop('id');
	var VisibleListContent= $('#Visible_list').html();
	var HiddenListContent= $('#chosen_sets').val();
	var highlight_left=$('SPAN-'+curSetID.split(":")[0]);
	var highlight_right=$('A-'+curSetID.split(":")[0]);

	// query == 0, plateNume == 1, condition == 2
	combo = plateIndices[plateID].split(/,/);
	var setInfo=combo[0]+', '+combo[1];
	if(combo[2]!=''){	setInfo=setInfo+', '+combo[2];	}
	else{	combo[2]='-';	}
	setInfo+=', '+$(curSet).prop('class');

	var setInfo1=combo[1]+'~'+combo[0].toLowerCase()+'~'+combo[2].toLowerCase()+'~'+$(curSet).prop('class');

	var width=curSet.getElementsByTagName("EM")[0].clientWidth;
	if(curSetID.indexOf(':off')>0){
		$(curSet).prop('id', curSetID.replace(':off',':on') );
		VisibleListContent=VisibleListContent+'<LI>'+setInfo+'</LI>';
		HiddenListContent=HiddenListContent+'~~>'+setInfo1;
		curSet.getElementsByTagName("EM")[0].style.backgroundColor='blue';
		curSet.getElementsByTagName("B")[0].style.backgroundColor='blue';
	}
	else if(curSetID.indexOf(':on')>0){
		$(curSet).prop('id', curSetID.replace(':on',':off'));
		var HiddenSetInfo='~~>'+setInfo1;
		HiddenListContent=HiddenListContent.replace(HiddenSetInfo,'');
		setInfo='<LI>'+setInfo+'</LI>';
		VisibleListContent=VisibleListContent.replace(new RegExp(setInfo, 'gi'),'');
		
		if(curSet.getElementsByTagName("EM")[0].className=='ok' || curSet.getElementsByTagName("EM")[0].className==null){
			curSet.getElementsByTagName("EM")[0].style.backgroundColor='transparent';
			curSet.getElementsByTagName("B")[0].style.backgroundColor='transparent';
		}
		else if(curSet.getElementsByTagName("EM")[0].className=='sig'){
			curSet.getElementsByTagName("EM")[0].style.backgroundColor='red';
			curSet.getElementsByTagName("B")[0].style.backgroundColor='red';
		}
		else if(curSet.getElementsByTagName("EM")[0].className=='de'){
			curSet.getElementsByTagName("EM")[0].style.backgroundColor='#FF7200';
			curSet.getElementsByTagName("B")[0].style.backgroundColor='#FF7200';
		}
		else if(curSet.getElementsByTagName("EM")[0].className=='ex' || curSet.getElementsByTagName("EM")[0].className=='bl'){
			curSet.getElementsByTagName("EM")[0].style.backgroundColor='green';
			curSet.getElementsByTagName("B")[0].style.backgroundColor='green';
		}
	}
	$('#Visible_list').html(VisibleListContent);
	$('#chosen_sets').val(HiddenListContent);
}

function show_plate(plate){
	plate=plate.replace(/\s|\t/g, ""); // removes spaces and tabs
	$('#plates table').fadeOut(function(){
		$('#'+plate+'_sub').fadeIn(function(){
			$('#'+plate+'_sub table').fadeIn();	
		});
		$('#toc li').prop('class','');
		$('#'+plate).prop('class','current');
	});
	
	$('.pthresh').fadeOut(); // hide all pthresh divs
	// display the one we are interested in seeing
	if($('#'+plate+"_pthresh").length>0){$('#'+plate+"_pthresh").fadeIn();}
	showHideDivs('nil', 'TopRightDiv') // hide all summary/menu info
}