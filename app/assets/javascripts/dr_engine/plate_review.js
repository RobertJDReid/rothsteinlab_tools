
function killElement(elementToKill){
	if(elementToKill){elementToKill.parentNode.removeChild(elementToKill);}
	else{return false;}
}

function calcHeight(el){
  //find the height of the internal page
  //change the width/height of the iframe
  el.style.height=el.contentWindow.document.body.scrollHeight+30+'px';
	el.style.width="100%";
}

function findPos(obj) {
	var curleft = curtop = 0;
	if (obj.offsetParent) {
		do{
			curleft += obj.offsetLeft;
			curtop += obj.offsetTop;
		}while (obj = obj.offsetParent);
		return [curleft,curtop];
	}
}
		
function setMenuOffset(header) { 
	if(header.length>0){
		header.css('position','fixed');
		var currentOffset = document.documentElement.scrollTop || document.body.scrollTop; // body for Safari
		var go_menu_bottom = $(document.getElementById('plates_reviewed').contentDocument.getElementById('plate_jump'));
		if (go_menu_bottom.length>0) {
			go_menu_bottom=go_menu_bottom.offset().top+go_menu_bottom.outerHeight();
			var iframe_top=$('#plates_reviewed').offset().top;
			var startPos =  go_menu_bottom+iframe_top+10;
			var desiredOffset = startPos - currentOffset;
			if (desiredOffset < 20){desiredOffset = 20;}
			header.css('top',desiredOffset + 'px');
		}
	}
}


function addMenu(excludedColonies, plateIndicesRev){
	var mainDIV = '<div id="exclusionTableWrapper" style="position:fixed;display:none;">';
	mainDIV += '<div id="exclusionList">Exclusion List</div>';
	mainDIV += '<div class="title">Colonies <small>(click to expand)</small></div>';
	mainDIV += '<div id="coloniesDIV" class="colonies" style="height:300px;">';
	mainDIV += '<ul id="excludeListTable" class="list"></ul></div></div>';
	
	$('#main').after(mainDIV);

	var excludeList='';

	// the success of the code below relies on excludedColonies being ordered
	if(excludedColonies && excludedColonies != ''){
		excludedColonies = excludedColonies.replace(/^\*-\*/,"").split("*-*");
		var queryConditionCombos = {};
		var first = true;
		for (var i = 0; i < excludedColonies.length; i++) {
	
			var temp=excludedColonies[i].split(',');
			var plateID = plateIndicesRev[temp[0]+','+temp[1]+','+temp[2]];
			var plateLabel = (temp[0]+', '+temp[1]+', '+temp[2]).replace(/, $/, '');
			if(!queryConditionCombos.hasOwnProperty(plateID)){
				if(first){first=false;}
				else{excludeList=excludeList+'</ul></li>';}
				queryConditionCombos[plateID] = 1;
				excludeList=excludeList+'<li id="'+plateID+'-li"><div class="el_showHide">'+plateLabel+'</div><ul style="display:none;" id="'+plateID+'-ul" class="excludedElementList">';
			}
			excludeList=excludeList+'<li id="li-'+plateID+'-'+temp[3]+'">';
			excludeList=excludeList+'<a href="#'+plateID+'">'+plateLabel+' -- '+temp[4]+'</a></li>';
		}
	}
	$('#excludeListTable').html(excludeList);
	document.getElementsByTagName("body")[0].setAttribute("onscroll","setMenuOffset($('#exclusionTableWrapper'))");	
	$('.el_showHide').click(function(){
		$(this).toggleClass('showUL'); 
		$(this).next().slideToggle();
	});
}
