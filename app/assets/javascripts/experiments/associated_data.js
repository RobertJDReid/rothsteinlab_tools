$(function() {
	$( "#loading-dialog" ).dialog({
	  height: 50,
	  width: 380,
	  modal: true,
	  autoOpen: true,
	  hide: "explode",
	  draggable: false,
	  dialogClass: "no-title curvy"
	});
	$( "#loading-dialog" ).dialog('open');
});
$(document).ready(function(){
	$("#experiments").fadeIn();
		var oTable1 = $("#experiments").dataTable({
      "bFilter": false,
      "bSort": false,
      "bInfo": false, 
      "bAutoWidth": true,
      "bJQueryUI": true,
      // "sDom": 'lfrtip'
		});

	var oTable = $("#experiment_data").dataTable({
		"sPaginationType": "full_numbers",
    "bFilter": true,
    "bSort": true,
    "bInfo": true, 
    "bAutoWidth": true,
    "bJQueryUI": true,
    "aLengthMenu": [[10, 25, 50, -1], [10, 25, 50, "All"]],
    "iDisplayLength" : 50,
    "oLanguage": { "sSearch": "Filter (all columns):"	}
	});

	$(function() {
	  $( "button" )
	    .button()
	    .click(function( event ) {
	      event.preventDefault();
	    });
	});

	/* Add event listeners to the two range filtering inputs */
  $('#min').keyup( function() { oTable.fnDraw(); } );
  $('#max').keyup( function() { oTable.fnDraw(); } );
  $('#data').fadeIn();
  $( "#loading-dialog" ).dialog('close');
});

/* Custom filtering function which will filter data in column 5 between two values */
$.fn.dataTableExt.afnFiltering.push(
  function( oSettings, aData, iDataIndex ) {
    var iMin = document.getElementById('min').value * 1;
    var iMax = document.getElementById('max').value * 1;
    var iVersion = aData[5] == "-" ? 0 : aData[5]*1;
    if ( iMin == "" && iMax == "" ){return true;}
    else if ( iMin == "" && iVersion < iMax ){return true;}
    else if ( iMin < iVersion && "" == iMax ){return true;}
    else if ( iMin < iVersion && iVersion < iMax ){return true;}
    return false;
  }
);