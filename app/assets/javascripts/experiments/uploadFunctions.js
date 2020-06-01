var modalSuccessMsg = 'Successfully uploaded';
var successMsg = 'Success!';
if(typeof(customModalMsg) !== "undefined" ){modalSuccessMsg=customModalMsg;}
if(typeof(customSuccessMsg) !== "undefined" ){successMsg=customSuccessMsg;}

// check to see if the submission div should be displayed or not depending on if any experiments are "checked" to be uploaded
// called in updateGoodTable, uploadData and as an onchange event in the checkboxes themselves
function checkUploadButtons(){
	if($('input[name=uploadMe]:checked').length > 0){$('.submitDiv').fadeIn();}
	else{$('.submitDiv').fadeOut();}
}

function setupUploadData(){
	$("#progress-success").prop('title','0');
	var toUpload = $('input[name=uploadMe]:checked');
	return setupLoadingProgress(function(){uploadData(toUpload,0);});
}

// called in "uploadData" function
// percent is a number and $element is a jquery element
function progress(percent, $element) {
	var progressBarWidth = percent * $element.width() / 100;
	$element.find('div').animate({ width: progressBarWidth }, 500).html(percent + "%&nbsp;");
}

function setupLoadingProgress (callback) {
	$("#progress-success").html("");
	$("#progress-success").hide();
	$("#progress-errors").hide();
	$("#progress-errors ul").html("");
	$( "#loading-dialog" ).dialog({
	  height: 150,
	  width: 455,
	  modal: true,
	  autoOpen: false,
	  show:"slow",
	  hide: "explode",
	  draggable: false,
	  dialogClass: "no-title curvy"
	});
	// set progress to 0
	progress(0,$('#progressBar'));
	// made sure progress bar is displayed
	$('#progressBar').css('display','block');
	// remove any and all buttons
	$( "#loading-dialog" ).dialog( "option", "buttons",[]);
	// open dialog
	$( "#loading-dialog" ).dialog("open");
	// set width...
	$('#progressBar').css("width",$('#loading-dialog').width()-5);
	callback();
}

// pushed the selected data to script, where it will be verified and uploaded to the database
function uploadData($toUpload, iterator){
	if(iterator === undefined){iterator=0;}
	// if we hit this, we are done
	if(iterator >= $toUpload.length){	
		$('#loading-dialog').effect('highlight');
		progress(100,$('#progressBar'));
		setTimeout(function(){$('#progressBar').effect('fade', {}, 750, function(){ $( "#loading-dialog" ).dialog( "option", "buttons", [ { text: "Ok", click: function() { $( this ).dialog( "close" ); } } ] ); } )}, 500);
		var height = $("#loading-dialog").dialog( "option", "height" ); // getter
		$( "#loading-dialog" ).dialog( "option", "height", height+50 ); // setter
		$("#loading-message").html("Finished! Review the messages below and then click 'Ok' to close this window");
		return;	
	}
	else{
		var currentData = $toUpload[iterator];
		var rowNum = $(currentData).val();
		var dataToSend = buildData(rowNum);
		$.ajax({
			type		: 'POST',
			url			: script, 
			data		: $(dataToSend.form).serialize(), // should probably not do this as the temp form creates un-needed overhead
			dataType: 'json',
			beforeSend: function(){
				$("#loading-message").html( "Now Processing "+dataToSend.setInfo+" ("+(iterator+1)+" of "+$toUpload.length+")" );
			},
			success	: function(data){
				if(!data){
					$('#progress-errors').show();
					$('#progress-errors ul').append("<li>An error occurred server-side. Contact the admin for assistance.</li>");
				}
				else if(data.hasOwnProperty('errorMsg')){
					$('#progress-errors').show();
					if( typeof data.errorMsg !== 'string' ){data.errorMsg = data.errorMsg.join(', ')}
					$('#progress-errors ul').append("<li><strong>"+data.dataSet+":</strong> "+data.errorMsg+"</li>");
				}
				else{
					updateRow('success',data.rowNum);
					var successCount = parseInt($("#progress-success").prop('title'))+1;
					$("#progress-success").html("<strong>"+modalSuccessMsg+" <span>"+successCount+"</span> datasets.</strong>");
					$("#progress-success").prop('title', successCount);
					$('#progress-success').show();
					//	UPDATE TABLE ROWS TO INDICATE SUCCESS!!! 
				}
			},
			error:function(errorData, e, er){
				$('#progress-errors').show();
				$('#progress-errors ul').append("<li>"+dataToSend.setInfo+": an error occurred server-side. Contact the admin for assistance.</li>");
			},
			complete: function(){	
				iterator+=1;
				// update progress
				progress( Math.round((iterator/$toUpload.length)*100),$('#progressBar'));
				// process next query-condition combo
				uploadData($toUpload,iterator);	
				checkUploadButtons();
			}
		});
	}
}

// called from upload data, updates the given row (defined by rowNum) with a success message (could easily be modified to also display error)
function updateRow (successOrFailure,rowNum) {
	$('.rowNum'+rowNum).each(function(){
		if($(this).hasClass('fileNameRow')){return true;} // return true in this jquery loop is akin to 'next'
		$(this).addClass(successOrFailure);
		$(this).removeClass('badData');
		if(successOrFailure == 'success'){
			$(this).children().each(function(index, value){
				$(value).unbind();
				$(value).removeClass('badData');
				if($(value).is('select') || $(value).is('input') || $(value).is('textarea') || $(value).is('button')){
					$(value).prop('disabled' , 'disabled');
				}
				//else if($(value))
			});
		}
		
	});
	if(successOrFailure == 'success'){	$('#uploadTD'+rowNum).html("<strong>"+successMsg+"</strong>");	}
}
