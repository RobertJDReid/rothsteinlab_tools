function handleOver(currentGuy) {
	$(currentGuy).css("background","#7878F0");
	$(currentGuy).css('color','#00016F');
	var showThis="#"+currentGuy.id + "Sub";
	if($(showThis).length>0){
		$(showThis).attr('class',"showSub");
		$(showThis).css('left', $(currentGuy).offset().left+'px');
	}
}

function handleOut(currentGuy) {
	$(currentGuy).css("background","");
	$(currentGuy).css('color','');
 	var showThis="#"+currentGuy.id + "Sub";
	if($(showThis)){$(showThis).attr('class',"");}
}

function handleSubOver(currentGuy) {
	var main = '#'+currentGuy.id.replace(/Sub$/, '');
	$(main).css("background","#7878F0");
	$(main).css('color','#00016F');
	var showThis="#"+currentGuy.id;
	$(showThis).attr('class',"showSub");
}

function handleSubOut(currentGuy) {
	var main ='#'+currentGuy.id.replace(/Sub$/, '');
	$(main).css("background","");
	$(main).css('color','');
	var showThis="#"+currentGuy.id;
	$(showThis).attr('class',"");
}
