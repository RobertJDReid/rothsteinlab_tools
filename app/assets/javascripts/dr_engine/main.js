alphabet = new Array('A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z','AA','AB','AC','AD','AE','AF','AG','AH','AI','AJ','AK','AL','AM','AN','AO','AP','AQ','AR','AS','AT','AU','AV','AW','AX','AY','AZ','BA','BB','BC','BD','BE','BF','BG','BH','BI','BJ','BK','BL','BM','BN','BO','BP','BQ','BR','BS','BT','BU','BV','BW','BX','BY','BZ','CA','CB','CC','CD','CE','CF','CG','CH','CI','CJ','CK','CL','CM','CN','CO','CP','CQ','CR','CS','CT','CU','CV','CW');
doNotDisplayClass='displayNone';

var positionsFunction = function(aPosition){return [];};

var MouseDown = false;

function setupPage(excludedPlates){
	// prevent dragging of colonies, which interferes with the mousedown and mouseup events
	// on the next line. The tables that hold the colonies also have ondragstart set to return false
	$('.plate td img').on('dragstart',function(event){event.preventDefault();});
	// use global variable to check if the mouse button is currently down
	$(document).mousedown(function(e) {MouseDown = true;}).mouseup(function() { MouseDown = false;  });
	// if mouse is mouse when we mouseover a colony, run ec.
	$('.col').mouseenter(	function(){	if(MouseDown){ec(this);}	});
	$('.rowHead, .rowSubHead').click(function(){excludeRow(this);});
	// $('.col').click(function(){ec(this);});
	$('.col').mousedown(function(){ec(this);});
	$('#next_plates, #finalAnalysis').on('submit',function(){
		hideStuff();
		return save_progress('excludeList', 'killedPlates');
	});
	$('#plate_jump').on('submit',function(){
		hideStuff();
		updateFlashTitle($(this.parentNode));
		return save_progress('excludeList2', 'killedPlates2');
	});

	//fyi - plateRows and replicates are defined in the perl script dr_engine/main.cgi
	// positionsFunction is used in cs()
	if(replicates == '4'){	
		positionsFunction = function(aPosition){
			return [aPosition, (aPosition+1), (aPosition+plateRows), (aPosition+plateRows+1)];	
		};
	}
	else if(replicates == '2v'){	
		positionsFunction = function(aPosition){	return [aPosition, (aPosition+1)];	};
	}
	else if(replicates == '2h'){	
		positionsFunction = function(aPosition){return [aPosition, (aPosition+plateRows)];	};
	}
	else if(replicates == '16'){
		positionsFunction = function(aPosition){
			return [	aPosition, (aPosition+1), (aPosition+2), (aPosition+3), 
									(aPosition+plateRows), (aPosition+plateRows+1), (aPosition+plateRows+2), (aPosition+plateRows+3),
									(aPosition+plateRows2), (aPosition+plateRows2+1), (aPosition+plateRows2+2), (aPosition+plateRows2+3),
									(aPosition+plateRows3), (aPosition+plateRows3+1),	(aPosition+plateRows3+2), (aPosition+plateRows3+3) 
								];
		};
	}
	else if(replicates == '1'){	positionsFunction = function(aPosition){return [aPosition];};}


	// find all rows in highlightable table
  $( 'table.plate tbody tr td.rowHead, table.plate tbody tr td.rowSubHead' ).hover(function() {
  		// get parent tr
  		if($(this).hasClass('rowHead')){
  			var span = $(this).prop('rowSpan') || 1;
  			var t = $(this).closest('tr').next();
  			var headers = t;
  			// add any additional trs
  			for (var i = 1; i < span-1; i++) {
  				t = t.next();
  				headers = headers.add(t);
  			};
  			headers.toggleClass('highlight');
  		}
  		// use not($(this).prev) to prevent rowHead from being highlighted when hovering over a .rowSubHead 
  		$(this).siblings().not($(this).prev()).toggleClass('highlight');	
  });
	
	// add realIndex attribute to all tds to account for rowSpans
	$( 'table.plate').each(function(){fixCellIndexes(this)});
	
	$( 'table.plate thead tr td.colHeader, table.plate thead tr td.colSubHead').hover(function(evt){
		var colHeader = this;
		for(i=0;i< colHeader.colSpan;i++){
			elementIndex = colHeader.realIndex+i; // td cell index
			// given the column header (in thead) find all the next rows in thead
			// and highlight the td with the same index as this one
			$(colHeader)
				.closest('tr')
				.nextAll()
				.find(':nth-child('+(elementIndex+1)+')')
				.toggleClass('highlight');
			// next, find the tbody section and do the same, need to check 'realIndex' on all matched
			// tds to account for row headers with rowSpan
			$(colHeader).closest('table').find('tbody>tr>td:nth-child('+elementIndex+')').each(function(){
				if(this.realIndex == elementIndex){	$(this).toggleClass('highlight');	}
				else{	$(this).next().toggleClass('highlight');	}
			})				
		}
	});	

	$('#layout').fadeIn();
	if(parent.$('.flashError').length==0){parent.killFlash();}
	if(parent.$('#exclusionTableWrapper')){
		parent.setMenuOffset(parent.$('#exclusionTableWrapper'));
		parent.$("#exclusionTableWrapper").css('display','');
	}
	if(typeof control != "undefined"){
		for(var i=0;i<excludedPlates.length;i++){
			if(excludedPlates[i]!=""){
				var plateInfo = excludedPlates[i].split(/,/);
				if(!plateInfo[2]){plateInfo[2]='';}
				if(!plateInfo[6]){plateInfo[6]='';}
				plate=$('#'+plateIndicesRev[plateInfo[0]+'-'+plateInfo[1]+'-'+plateInfo[2]] );
				if(plate.length>0 && plateInfo[6] != 'ce'){killPlate(plate, plateInfo[0], false);}
				if(plateInfo[0]==control){
					if(plate.length<1){
						killPlate(plateInfo[0]+'-'+plateInfo[1]+'-'+plateInfo[2], plateInfo[0], false);
					}
				}
			}
		}
	}
}

function removeAllExclusion(plate){
	var eSingle = plate.find("td.eSingle");
	for (var i = 0; i < eSingle.length; i++) {	ec(eSingle[i]);	}
	plate.find("td.columnExcluded, td.rowExcluded").removeClass('columnExcluded rowExcluded');
	var plateIndex = plate.prop('id').replace(/^plate/, 'p');
	parent.$('#'+plateIndex+'-li').slideUp(function(){$(this).remove();}); 
}

function excludeColumn(columnTD){
	$(columnTD).toggleClass('columnExcluded');
		for(i=0;i< columnTD.colSpan;i++){
			elementIndex = columnTD.realIndex+i; // td cell index
			// given the column header (in thead) search all the next rows in thead
			// and find the tds with the same index as this one
			var headerTDs = $(columnTD)
												.closest('tr')
												.nextAll()
												.find(':nth-child('+(elementIndex+1)+')');
				
			// next, find the tbody section and do the same, need to check 'realIndex' on all matched
			// tds to account for row headers with rowSpan
			var tds = $(columnTD).closest('table').find('tbody>tr>td:nth-child('+elementIndex+')');
			if($(columnTD).hasClass('columnExcluded')){
				headerTDs.addClass('columnExcluded');
				tds.each(function(){
					var td = $(this);
					if(this.realIndex != elementIndex){	td=td.next();	}
					if(!td.is('.ce, .eSingle')){	ec(td); }
				});
			}
			else{
				headerTDs.removeClass('columnExcluded');
				tds.each(function(){
					var td = $(this);
					if(this.realIndex != elementIndex){	td=td.next();	}
					if(!td.hasClass('.ce') && td.hasClass('eSingle')){	ec(td); }
				});
			}				
		}
}

function excludeRow(rowTD){
	rowTD = $(rowTD);
	rowTD.toggleClass("rowExcluded");
	// use not(rowTD.prev) to prevent rowHead from being highlighted when hovering over a .rowSubHead 
	var tds = rowTD.siblings().not('.rowHead, .rowSubHead, .blankCellRight');	
	var headers = $();
	if(rowTD.hasClass('rowHead')){
		var span = rowTD.prop('rowSpan') || 1;
		// already have the first row, add the second
		var temp = rowTD.closest('tr').next();
		var relevant_trs = temp;

		headers = headers.add(temp.children(':first'));
		headers = headers.add(rowTD.next());

		// add any additional trs
		for (var i = 1; i < span-1; i++) {
			temp = temp.next();
			headers = headers.add(temp.children(':first'));
			relevant_trs = relevant_trs.add(temp);
		};
		// if this is a row head need to add the next row too
		tds=tds.add(relevant_trs.children().not('.rowHead, .rowSubHead, .blankCellRight'));	
	}

	if(rowTD.hasClass('rowExcluded')){
		headers.addClass('rowExcluded');
		tds.not('.ce, .eSingle').each(function(){
			ec($(this));
		});
	}
	else{
		headers.removeClass('rowExcluded');
		tds.filter('.ce, .eSingle').each(function(){
			ec($(this));
		});
	}
}

// calls for this function are in the output from the perl scripts
function hideStuff(){
	$('#layout').fadeOut();
	parent.$("#exclusionTableWrapper").hide();
	// hide plate exclusion divs
	$('.excludedPlateContainer').hide();
}
	
// saves items in excludeListTable to hidden form fields
function save_progress(colonyField, plateField){
	var excludes = '';
	parent.$('#excludeListTable ul li').each(function(){
		var val = $(this).prop('id').replace(/^li\-/,'').split('-');
		excludes = excludes+'*-*'+plateIndices[val[0]]+','+val[1];
	});
	var plateExcludes = '';
	if(parent.$('#KilledPlatesTable')){
		parent.$('#KilledPlatesTable').children().each(function(s){
			var val = $(this).prop('id').replace(/^li\-plate/,'p');
			if($(this).hasClass("controlExcluded")){plateExcludes=plateExcludes+plateIndices[val]+",ce*-*";}
			else{plateExcludes=plateExcludes+plateIndices[val]+"*-*";}
		});
		plateExcludes=plateExcludes.replace(new RegExp("\\*-\\*$"), ''); // chop off trailing *-*
	}
	// current form fields...
	if(colonyField && $('#'+colonyField).length>0){$('#'+colonyField).val(excludes);	}
	if(plateField && $('#'+plateField).length>0){$('#'+plateField).val(plateExcludes);}
	return 1;
}

function updateFlashTitle(formEl){
	if(formEl.length<1){return false;}
	var title='Generating Cartoon Renderings...';
	if($('#next_page_num option:selected').val().match(/^analysis/i)){title='Performing Final Analysis...';}
	parent.setupFlash(true, title);
	return true;
}

// check surroundings
// this is only run for control plates, if all replicates are 'on' then the value of count will equal the number of 
// replicates and we will need add them to the control excluded list and change all the corresponding experimentals to light red, 
// else if all replicates but one are  'on' then count will be one less then the number of replicates and we will 
// need to remove all of them from the control exclude list and change all the corresponding experimental colonies
// back to their default state (on or off)
function cs(currentPlateAndPosition){
	var count=0;
	// currentPlateAndPositon.id example: '1,345,2'
	var idHolder=currentPlateAndPosition.prop('id').split('-'); // should contain 2 elements (0 = plateID, 1 = position, 2 = position of replicate 'A')
	var aPosition = parseInt(idHolder[idHolder.length-1]);
	var position=parseInt(idHolder[idHolder.length-2]); // postion = value from 0 to the density of the plate - 1
	idHolder=idHolder.slice(0,-2).join('-');
	var positions = positionsFunction(aPosition);
	for (var i=0;i<positions.length;i++){
	  count += $('#'+idHolder+'-'+positions[i]+'-'+aPosition+'.eSingle').length;
	}
	return {orig:currentPlateAndPosition.prop('id'),positions:positions,origPosition:position,count:count};
}

// bunchOfInfo contains...
// orig = id (current plate and position)  																											
// positions = # of each colony within replicates (if plate density is 1536 this value wil fall between 0 and 1535)			
// origPosition = position of current replicate											
// count = number of replicate (including this colony) that are 'on' excluded		
// function name is ce this stands for changeExperimentals 	

// need to add check to NOT iterate over all gene names, in fact the array 'queries' should only contain	
// queries present on current page...	

// do not really need to change the experimentals, just need to change their color.  No need to add them to any list			
// and it does not matter if they already 'on' or 'off'.  In this way we can change their color to light red if
// they are excluded on the control, however if the user decides to re-introduce the corresponding controls it will
// be easy to return them to their original state.  Need to add a check that looks to see if a colony is light red, 
// if so then clicking on them will do nothing until the user reintroduces the controls (display message to user explaining this?)
// can still usse this function to find the proper id names of the experimentals and change then to light red or their
// original state...		
function ce(bunchOfInfo){
	for(var i=0;i<queries.length;i++){
		var parts = bunchOfInfo.orig.split('-');
		var testID = plateIndicesRev[plateIndices[parts[0]].replace(new RegExp(control, 'gi'),queries[i])];
		if(testID && testID != parts[0] ){ //check if plate exisits on this page and that it is not the current plate
			if(bunchOfInfo.count==numReps){ // if we just turned the control on SOOOOO turn these guys light red
				for (var j=0;j<bunchOfInfo.positions.length;j++){
				  $('#'+testID+'-'+bunchOfInfo.positions[j]+'-'+bunchOfInfo.positions[0]).addClass('ce');
				}
			}
			else{ // change experimentals back to their default state
				for (var j=0;j<bunchOfInfo.positions.length;j++){
				  $('#'+testID+'-'+bunchOfInfo.positions[j]+'-'+bunchOfInfo.positions[0]).removeClass('ce');
				}
			}
		}
	}
}

// ec stands for excludeColony
function ec(currentPlateAndPosition){
	var tdElem = $(currentPlateAndPosition);
	if(!$(tdElem).prop('id')){return;}
	var colonyLabel=tdElem.prop('id').split('-');
	var plateIndex = colonyLabel[0];
	var isControl = false;

	if(plateIndices[plateIndex].toLowerCase().indexOf(control) == 0){ 
		isControl=true;
	}
	// if the current colony is not selected by determining if it has any of the
	// following class label
	if(!tdElem.is('.eSingle, .excludedCol, .excludedRow, .ce, .blankCellRight')){  
		// only allow the user to change the colony's 'state' to excluded if it has not been 'control excluded'
		tdElem.addClass('eSingle'); // switch from off to on (replace off tag with on)

		// if this guy is on a control plate then check its replicates to see if they have also been excluded
		if(isControl){ 
			var results=cs(tdElem);
			if(results.count==numReps){ce(results);} // if all the replicates have been excluded then exclude the experimentals
		}
		var displayColonyLabel = plateIndices[plateIndex].replace(/, $/, '').replace(/,$/,'');
		
		if(parent.$('#'+plateIndex+"-li").length<1){
			var parentLI = '<li id="'+plateIndex+'-li">';
			parentLI += '<div class="el_showHide" onclick="$(this).toggleClass(\'showUL\'); $(this).next().slideToggle();">'+displayColonyLabel+'</div>';
			parentLI += '<ul id="'+plateIndex+'-ul" class="excludedElementList" style="display:none;"></ul></li>';
			parent.$('#excludeListTable').append(parentLI);
		}
		var li = '<li id="li-'+plateIndex+'-'+colonyLabel[colonyLabel.length-2]+'">';
		li += '<a href="#'+escape(plateIndex)+'">'+displayColonyLabel+' -- '+tdElem.prop('title')+'</a></li>';
		parent.$('#'+plateIndex+'-ul').append(li);
	}
	//  else colony is currently excluded so reintroduce it!
	else{
		tdElem.removeClass('eSingle excludedCol excludedRow'); // remove red color
		// run through check surroundings (cs), if count == one less then the number of replicates, run ce
		if(isControl){
			var results=cs(tdElem);
			if(results.count==(numReps-1)){ce(results);}
		}
		// remove the li element
		parent.$('#li-'+plateIndex+'-'+colonyLabel[colonyLabel.length-2]).slideUp(function(){
			$(this).remove();
			// if there are no more li elements then remove the parent li of this list
			// console.debug(parent.$('#'+plateIndex+'-ul').length);
			if(parent.$('#'+plateIndex+'-ul').length > 0 && parent.$('#'+plateIndex+'-ul').children().length < 1){
				parent.$('#'+plateIndex+'-li').slideUp(function(){$(this).remove();}); 
			}
		}); 
	}
}

function killPlate(obj, gene, controlExcluded){
	var epElement = $();
	var objID = obj.prop('id');
	var divID=objID+"exclusionDIV"; // create a unique ID for this div

	// if this plate has not yet been excluded then exclude it...could have also done this by checking if this plate was already added to the 
	// hidden field "killedPlates"
	epElement = $("#"+divID);
	if(controlExcluded){
		// if this element has already been excluded explicitly (i.e., not because its corresponding control was excluded) hide
		// the exclusion div that has already been created and add an adjuster to divID
		epElement.hide();
		parent.$('#li-'+objID).hide();
		divID=divID+"-"+gene;
		epElement = $("#"+divID);
		objID=objID+'-'+gene;
	}

	if(epElement.length<1){ 
		var width=obj.outerWidth(); // get width of plate
		var height=obj.outerHeight(); // get height of plate
		// populate style variable with the appropriate values
		var style='position:absolute;height:'+height+';width:'+width+';top:'+obj.offset().top+';left:'+obj.offset()+';';
		var element = '<div id="'+divID+'" class="excludedPlateContainer" style="'+style+'">';
		
		var top=(height/2)-85; // set the top position for the inner div (will be more or less vertically centered)
		// create the contents of the nested div
		// if the plate was exclude by the use show this msg
		var inHTML='<div onclick="restorePlate(\''+divID+'\', \''+gene+'\');" class="excludedPlate" style="margin-top:'+top+'px;"><h2 onclick="restorePlate(\''+divID+'\', \''+gene+'\');">This plate has been excluded from statistical consideration click on this window to re-include it</h2></div>'; 
		// else if the plate was exclude b/c the corrisponding control plate was excluded, display this msg
		if(controlExcluded){
			inHTML='<div class="excludedPlate" style="margin-top:'+top+'px;"><h2>The comparer plate corresponding to this experimental plate has been excluded from statistical consideration. The corresponding comparer plate must be re-included into statisitcal consideration before this plate can be re-included.</h2></div>';	
		}
		
		$('#screen_mill_dr_engine').append(element+inHTML+'</div>'); // append the div to the body of the webpage
		
		// create a unique ID if this plate is not being excluded because the control plate was excluded.  This will prevent the plate from automatically
		// being included if the corresponding control plate is excluded and then re-included
		var el_id='li-'+objID;
		var li = '<li id="'+el_id+'"><a href="#'+escape(objID)+'">';
		li += obj.find('.plateTitle .middle a').html()+'</a></li>';
		
		if(parent.$('#KilledPlatesTable').length<1){
			parent.$('#coloniesDIV').css('height','200px');
			var temp = '<hr id = "exclusionHR" /><u class="title" id="ePlatesTitle">Plates</u>';
			temp += '<div class="plates" id="ePlatesDiv"><ul id="KilledPlatesTable" class="list"></ul></div>';
			parent.$('#exclusionTableWrapper').append(temp);
		}
		parent.$("#KilledPlatesTable").append(li); // add li to list
	}
	if(gene==control){
		var plateID = obj.prop('id').replace(/^plate/i, 'p');
		var plateName = plateIndices[plateID];
		
		for(var j=0; j<queries.length;j++){
			if(queries[j]!=control){
				var tempID = plateIndicesRev[plateName.replace(control,queries[j])];
				if(tempID){
					tempID = tempID.replace(/^p/i, 'plate')
					if($('#'+tempID).length > 0){
						killPlate($('#'+tempID), obj.prop('id'), true);
					}		
				}
			}
		}
	}
}

function restorePlate(divID,gene){
	var temp = $('#'+divID);
	if(temp.length>0){temp.remove();} // remove element from webpage (DOM)
	var plateID=divID.replace("exclusionDIV" , ""); // remove the "excludionDIV" tag
	temp = parent.$('#li-'+plateID);
	if(temp.length>0){temp.remove();} // temp.remove was throwing an error here so using this approach
	if(gene==control){ // if you are re-including a control plate also re-include corresponding experimentals
		var tempID;
		for(var j=0; j<queries.length;j++){
			if(queries[j]!=control){
				var tempID = plateIndicesRev[plateIndices[plateID.replace(/^plate/i,'p')].replace(control,queries[j])];
				if(tempID){
					tempID=tempID.replace(/^p/i,"plate");
					tempID += 'exclusionDIV';
					temp=$('#'+tempID);
					if(temp.length>0){
						temp.show();
						temp=parent.$('#li-'+tempID.replace("exclusionDIV" , ""));
						if(temp.length>0){temp[0].style.display='';}
					}

					tempID=tempID+"-"+plateID;
					if($('#'+tempID.length>0)){
						restorePlate(tempID, "ControlExcluded");
					}
				}			
			}
		}
	}
	if(parent.$('#KilledPlatesTable').length>0 && parent.$('#KilledPlatesTable').children().length < 1 ){
		parent.$('#exclusionHR').remove();
		parent.$('#ePlatesTitle').remove();
		parent.$('#ePlatesDiv').remove();
		parent.$('#coloniesDIV').css('height','300px');
	}
}

// used to help with row- and colspan issues
// creates a new attribute on tds called 'realIndex' 
// which can be used to determine all the tds in a given
// row or column, irrespective of the corresponding row- and colspans
var fixCellIndexes = function(table) {
	var rows = table.rows;
	var len = rows.length;
	var matrix = [];
	for ( var i = 0; i < len; i++ ){
		var cells = rows[i].cells;
		var clen = cells.length;
		for ( var j = 0; j < clen; j++ ){
			var c = cells[j];
			var rowSpan = c.rowSpan || 1;
			var colSpan = c.colSpan || 1;
			var firstAvailCol = -1;
			if ( !matrix[i] ){ 	matrix[i] = []; 	}
			var m = matrix[i];
			// Find first available column in the first row
			while ( m[++firstAvailCol] ) {}
			c.realIndex = firstAvailCol;
			for ( var k = i; k < i + rowSpan; k++ ){
				if ( !matrix[k] ){ 	matrix[k] = []; 	}
				var matrixrow = matrix[k];
				for ( var l = firstAvailCol; l < firstAvailCol + colSpan; l++ ){
					matrixrow[l] = 1;
				}
			}
		}
	}
};