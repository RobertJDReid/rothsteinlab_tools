var FixedHeader=function(e,t){if("function"!=typeof this.fnInit)return alert("FixedHeader warning: FixedHeader must be initialised with the 'new' keyword."),void 0;var i={aoCache:[],oSides:{top:!0,bottom:!1,left:!1,right:!1},oZIndexes:{top:104,bottom:103,left:102,right:101},oMes:{iTableWidth:0,iTableHeight:0,iTableLeft:0,iTableRight:0,iTableTop:0,iTableBottom:0},oOffset:{top:0},nTable:null,bUseAbsPos:!1,bFooter:!1};this.fnGetSettings=function(){return i},this.fnUpdate=function(){this._fnUpdateClones(),this._fnUpdatePositions()},this.fnPosition=function(){this._fnUpdatePositions()},this.fnDestroy=function(){var e=i.nTable.id,t=jQuery.inArray(e,FixedHeader.idTablas);t>-1&&(jQuery("div.fixedHeader table#"+e).parents("div").remove(),FixedHeader.afnScroll.splice(t,1),FixedHeader.idTablas.splice(t,1)),0==FixedHeader.afnScroll.length&&jQuery(window).unbind(".FixedHeader")},jQuery(window).bind("scroll.FixedHeader",function(){FixedHeader.fnMeasure();for(var e=0,t=FixedHeader.afnScroll.length;t>e;e++)FixedHeader.afnScroll[e]()}),this.fnInit(e,t),"function"==typeof e.fnSettings&&(e._oPluginFixedHeader=this)};FixedHeader.prototype={fnInit:function(e,t){var i=this.fnGetSettings(),o=this;if(this.fnInitSettings(i,t),"function"==typeof e.fnSettings){if("functon"==typeof e.fnVersionCheck&&e.fnVersionCheck("1.6.0")!==!0)return alert("FixedHeader 2 required DataTables 1.6.0 or later. Please upgrade your DataTables installation"),void 0;var n=e.fnSettings();if(""!=n.oScroll.sX||""!=n.oScroll.sY)return alert("FixedHeader 2 is not supported with DataTables' scrolling mode at this time"),void 0;i.nTable=n.nTable,n.aoDrawCallback.push({fn:function(){FixedHeader.fnMeasure(),o._fnUpdateClones.call(o),o._fnUpdatePositions.call(o)},sName:"FixedHeader"})}else i.nTable=e;i.bFooter=$(">tfoot",i.nTable).length>0?!0:!1,i.bUseAbsPos=jQuery.browser.msie&&("6.0"==jQuery.browser.version||"7.0"==jQuery.browser.version),i.oSides.top&&i.aoCache.push(o._fnCloneTable("fixedHeader","FixedHeader_Header",o._fnCloneThead)),i.oSides.bottom&&i.aoCache.push(o._fnCloneTable("fixedFooter","FixedHeader_Footer",o._fnCloneTfoot)),i.oSides.left&&i.aoCache.push(o._fnCloneTable("fixedLeft","FixedHeader_Left",o._fnCloneTLeft)),i.oSides.right&&i.aoCache.push(o._fnCloneTable("fixedRight","FixedHeader_Right",o._fnCloneTRight)),FixedHeader.afnScroll.push(function(){o._fnUpdatePositions.call(o)}),FixedHeader.idTablas.push(i.nTable.id),jQuery(window).bind("resize.FixedHeader",function(){FixedHeader.fnMeasure(),o._fnUpdateClones.call(o),o._fnUpdatePositions.call(o)}),FixedHeader.fnMeasure(),o._fnUpdateClones(),o._fnUpdatePositions()},fnInitSettings:function(e,t){"undefined"!=typeof t&&("undefined"!=typeof t.top&&(e.oSides.top=t.top),"undefined"!=typeof t.bottom&&(e.oSides.bottom=t.bottom),"undefined"!=typeof t.left&&(e.oSides.left=t.left),"undefined"!=typeof t.right&&(e.oSides.right=t.right),"undefined"!=typeof t.zTop&&(e.oZIndexes.top=t.zTop),"undefined"!=typeof t.zBottom&&(e.oZIndexes.bottom=t.zBottom),"undefined"!=typeof t.zLeft&&(e.oZIndexes.left=t.zLeft),"undefined"!=typeof t.zRight&&(e.oZIndexes.right=t.zRight),"undefined"!=typeof t.offsetTop&&(e.oOffset.top=t.offsetTop)),e.bUseAbsPos=jQuery.browser.msie&&("6.0"==jQuery.browser.version||"7.0"==jQuery.browser.version)},_fnCloneTable:function(e,t,i){var o,n=this.fnGetSettings();"absolute"!=jQuery(n.nTable.parentNode).css("position")&&(n.nTable.parentNode.style.position="relative"),o=n.nTable.cloneNode(!1),o.removeAttribute("id");var a=document.createElement("div");return a.style.position="absolute",a.style.top="0px",a.style.left="0px",a.className+=" FixedHeader_Cloned "+e+" "+t,"fixedHeader"==e&&(a.style.zIndex=n.oZIndexes.top),"fixedFooter"==e&&(a.style.zIndex=n.oZIndexes.bottom),"fixedLeft"==e?a.style.zIndex=n.oZIndexes.left:"fixedRight"==e&&(a.style.zIndex=n.oZIndexes.right),o.style.margin="0",a.appendChild(o),document.body.appendChild(a),{nNode:o,nWrapper:a,sType:e,sPosition:"",sTop:"",sLeft:"",fnClone:i}},_fnMeasure:function(){var e=this.fnGetSettings(),t=e.oMes,i=jQuery(e.nTable),o=i.offset(),n=this._fnSumScroll(e.nTable.parentNode,"scrollTop");this._fnSumScroll(e.nTable.parentNode,"scrollLeft"),t.iTableWidth=i.outerWidth(),t.iTableHeight=i.outerHeight(),t.iTableLeft=o.left+e.nTable.parentNode.scrollLeft,t.iTableTop=o.top+n,t.iTableRight=t.iTableLeft+t.iTableWidth,t.iTableRight=FixedHeader.oDoc.iWidth-t.iTableLeft-t.iTableWidth,t.iTableBottom=FixedHeader.oDoc.iHeight-t.iTableTop-t.iTableHeight},_fnSumScroll:function(e,t){for(var i=e[t];(e=e.parentNode)&&"HTML"!=e.nodeName&&"BODY"!=e.nodeName;)i=e[t];return i},_fnUpdatePositions:function(){var e=this.fnGetSettings();this._fnMeasure();for(var t=0,i=e.aoCache.length;i>t;t++)"fixedHeader"==e.aoCache[t].sType?this._fnScrollFixedHeader(e.aoCache[t]):"fixedFooter"==e.aoCache[t].sType?this._fnScrollFixedFooter(e.aoCache[t]):"fixedLeft"==e.aoCache[t].sType?this._fnScrollHorizontalLeft(e.aoCache[t]):this._fnScrollHorizontalRight(e.aoCache[t])},_fnUpdateClones:function(){for(var e=this.fnGetSettings(),t=0,i=e.aoCache.length;i>t;t++)e.aoCache[t].fnClone.call(this,e.aoCache[t])},_fnScrollHorizontalRight:function(e){var t=this.fnGetSettings(),i=t.oMes,o=FixedHeader.oWin,n=FixedHeader.oDoc,a=e.nWrapper,s=jQuery(a).outerWidth();o.iScrollRight<i.iTableRight?(this._fnUpdateCache(e,"sPosition","absolute","position",a.style),this._fnUpdateCache(e,"sTop",i.iTableTop+"px","top",a.style),this._fnUpdateCache(e,"sLeft",i.iTableLeft+i.iTableWidth-s+"px","left",a.style)):i.iTableLeft<n.iWidth-o.iScrollRight-s?t.bUseAbsPos?(this._fnUpdateCache(e,"sPosition","absolute","position",a.style),this._fnUpdateCache(e,"sTop",i.iTableTop+"px","top",a.style),this._fnUpdateCache(e,"sLeft",n.iWidth-o.iScrollRight-s+"px","left",a.style)):(this._fnUpdateCache(e,"sPosition","fixed","position",a.style),this._fnUpdateCache(e,"sTop",i.iTableTop-o.iScrollTop+"px","top",a.style),this._fnUpdateCache(e,"sLeft",o.iWidth-s+"px","left",a.style)):(this._fnUpdateCache(e,"sPosition","absolute","position",a.style),this._fnUpdateCache(e,"sTop",i.iTableTop+"px","top",a.style),this._fnUpdateCache(e,"sLeft",i.iTableLeft+"px","left",a.style))},_fnScrollHorizontalLeft:function(e){var t=this.fnGetSettings(),i=t.oMes,o=FixedHeader.oWin,n=(FixedHeader.oDoc,e.nWrapper),a=jQuery(n).outerWidth();o.iScrollLeft<i.iTableLeft?(this._fnUpdateCache(e,"sPosition","absolute","position",n.style),this._fnUpdateCache(e,"sTop",i.iTableTop+"px","top",n.style),this._fnUpdateCache(e,"sLeft",i.iTableLeft+"px","left",n.style)):o.iScrollLeft<i.iTableLeft+i.iTableWidth-a?t.bUseAbsPos?(this._fnUpdateCache(e,"sPosition","absolute","position",n.style),this._fnUpdateCache(e,"sTop",i.iTableTop+"px","top",n.style),this._fnUpdateCache(e,"sLeft",o.iScrollLeft+"px","left",n.style)):(this._fnUpdateCache(e,"sPosition","fixed","position",n.style),this._fnUpdateCache(e,"sTop",i.iTableTop-o.iScrollTop+"px","top",n.style),this._fnUpdateCache(e,"sLeft","0px","left",n.style)):(this._fnUpdateCache(e,"sPosition","absolute","position",n.style),this._fnUpdateCache(e,"sTop",i.iTableTop+"px","top",n.style),this._fnUpdateCache(e,"sLeft",i.iTableLeft+i.iTableWidth-a+"px","left",n.style))},_fnScrollFixedFooter:function(e){var t=this.fnGetSettings(),i=t.oMes,o=FixedHeader.oWin,n=FixedHeader.oDoc,a=e.nWrapper,s=jQuery("thead",t.nTable).outerHeight(),l=jQuery(a).outerHeight();o.iScrollBottom<i.iTableBottom?(this._fnUpdateCache(e,"sPosition","absolute","position",a.style),this._fnUpdateCache(e,"sTop",i.iTableTop+i.iTableHeight-l+"px","top",a.style),this._fnUpdateCache(e,"sLeft",i.iTableLeft+"px","left",a.style)):o.iScrollBottom<i.iTableBottom+i.iTableHeight-l-s?t.bUseAbsPos?(this._fnUpdateCache(e,"sPosition","absolute","position",a.style),this._fnUpdateCache(e,"sTop",n.iHeight-o.iScrollBottom-l+"px","top",a.style),this._fnUpdateCache(e,"sLeft",i.iTableLeft+"px","left",a.style)):(this._fnUpdateCache(e,"sPosition","fixed","position",a.style),this._fnUpdateCache(e,"sTop",o.iHeight-l+"px","top",a.style),this._fnUpdateCache(e,"sLeft",i.iTableLeft-o.iScrollLeft+"px","left",a.style)):(this._fnUpdateCache(e,"sPosition","absolute","position",a.style),this._fnUpdateCache(e,"sTop",i.iTableTop+l+"px","top",a.style),this._fnUpdateCache(e,"sLeft",i.iTableLeft+"px","left",a.style))},_fnScrollFixedHeader:function(e){for(var t=this.fnGetSettings(),i=t.oMes,o=FixedHeader.oWin,n=(FixedHeader.oDoc,e.nWrapper),a=0,s=t.nTable.getElementsByTagName("tbody"),l=0;l<s.length;++l)a+=s[l].offsetHeight;i.iTableTop>o.iScrollTop+t.oOffset.top?(this._fnUpdateCache(e,"sPosition","absolute","position",n.style),this._fnUpdateCache(e,"sTop",i.iTableTop+"px","top",n.style),this._fnUpdateCache(e,"sLeft",i.iTableLeft+"px","left",n.style)):o.iScrollTop+t.oOffset.top>i.iTableTop+a?(this._fnUpdateCache(e,"sPosition","absolute","position",n.style),this._fnUpdateCache(e,"sTop",i.iTableTop+a+"px","top",n.style),this._fnUpdateCache(e,"sLeft",i.iTableLeft+"px","left",n.style)):t.bUseAbsPos?(this._fnUpdateCache(e,"sPosition","absolute","position",n.style),this._fnUpdateCache(e,"sTop",o.iScrollTop+"px","top",n.style),this._fnUpdateCache(e,"sLeft",i.iTableLeft+"px","left",n.style)):(this._fnUpdateCache(e,"sPosition","fixed","position",n.style),this._fnUpdateCache(e,"sTop",t.oOffset.top+"px","top",n.style),this._fnUpdateCache(e,"sLeft",i.iTableLeft-o.iScrollLeft+"px","left",n.style))},_fnUpdateCache:function(e,t,i,o,n){e[t]!=i&&(n[o]=i,e[t]=i)},_fnCloneThead:function(e){var t=this.fnGetSettings(),i=e.nNode;for(e.nWrapper.style.width=jQuery(t.nTable).outerWidth()+"px";i.childNodes.length>0;)jQuery("thead th",i).unbind("click"),i.removeChild(i.childNodes[0]);var o=jQuery("thead",t.nTable).clone(!0)[0];i.appendChild(o),jQuery("thead>tr th",t.nTable).each(function(e){jQuery("thead>tr th:eq("+e+")",i).width(jQuery(this).width())}),jQuery("thead>tr td",t.nTable).each(function(e){jQuery("thead>tr td:eq("+e+")",i).width(jQuery(this).width())})},_fnCloneTfoot:function(e){var t=this.fnGetSettings(),i=e.nNode;for(e.nWrapper.style.width=jQuery(t.nTable).outerWidth()+"px";i.childNodes.length>0;)i.removeChild(i.childNodes[0]);var o=jQuery("tfoot",t.nTable).clone(!0)[0];i.appendChild(o),jQuery("tfoot:eq(0)>tr th",t.nTable).each(function(e){jQuery("tfoot:eq(0)>tr th:eq("+e+")",i).width(jQuery(this).width())}),jQuery("tfoot:eq(0)>tr td",t.nTable).each(function(e){jQuery("tfoot:eq(0)>tr th:eq("+e+")",i)[0].style.width(jQuery(this).width())})},_fnCloneTLeft:function(e){var t=this.fnGetSettings(),i=e.nNode,o=$("tbody",t.nTable)[0];for($("tbody tr:eq(0) td",t.nTable).length,$.browser.msie&&("6.0"==$.browser.version||"7.0"==$.browser.version);i.childNodes.length>0;)i.removeChild(i.childNodes[0]);i.appendChild(jQuery("thead",t.nTable).clone(!0)[0]),i.appendChild(jQuery("tbody",t.nTable).clone(!0)[0]),t.bFooter&&i.appendChild(jQuery("tfoot",t.nTable).clone(!0)[0]),$("thead tr",i).each(function(){$("th:gt(0)",this).remove()}),$("tfoot tr",i).each(function(){$("th:gt(0)",this).remove()}),$("tbody tr",i).each(function(){$("td:gt(0)",this).remove()}),this.fnEqualiseHeights("tbody",o.parentNode,i);var n=jQuery("thead tr th:eq(0)",t.nTable).outerWidth();i.style.width=n+"px",e.nWrapper.style.width=n+"px"},_fnCloneTRight:function(e){var t=this.fnGetSettings(),i=$("tbody",t.nTable)[0],o=e.nNode,n=jQuery("tbody tr:eq(0) td",t.nTable).length;for($.browser.msie&&("6.0"==$.browser.version||"7.0"==$.browser.version);o.childNodes.length>0;)o.removeChild(o.childNodes[0]);o.appendChild(jQuery("thead",t.nTable).clone(!0)[0]),o.appendChild(jQuery("tbody",t.nTable).clone(!0)[0]),t.bFooter&&o.appendChild(jQuery("tfoot",t.nTable).clone(!0)[0]),jQuery("thead tr th:not(:nth-child("+n+"n))",o).remove(),jQuery("tfoot tr th:not(:nth-child("+n+"n))",o).remove(),$("tbody tr",o).each(function(){$("td:lt("+(n-1)+")",this).remove()}),this.fnEqualiseHeights("tbody",i.parentNode,o);var a=jQuery("thead tr th:eq("+(n-1)+")",t.nTable).outerWidth();o.style.width=a+"px",e.nWrapper.style.width=a+"px"},fnEqualiseHeights:function(e,t,i){var o=$(e+" tr:eq(0)",t).children(":eq(0)"),n=o.outerHeight()-o.height(),a=$.browser.msie&&("6.0"==$.browser.version||"7.0"==$.browser.version);$(e+" tr",i).each(function(i){$.browser.mozilla||$.browser.opera?$(this).children().height($(e+" tr:eq("+i+")",t).outerHeight()):$(this).children().height($(e+" tr:eq("+i+")",t).outerHeight()-n),a||$(e+" tr:eq("+i+")",t).height($(e+" tr:eq("+i+")",t).outerHeight())})}},FixedHeader.oWin={iScrollTop:0,iScrollRight:0,iScrollBottom:0,iScrollLeft:0,iHeight:0,iWidth:0},FixedHeader.oDoc={iHeight:0,iWidth:0},FixedHeader.afnScroll=[],FixedHeader.idTablas=[],FixedHeader.fnMeasure=function(){var e=jQuery(window),t=jQuery(document),i=FixedHeader.oWin,o=FixedHeader.oDoc;o.iHeight=t.height(),o.iWidth=t.width(),i.iHeight=e.height(),i.iWidth=e.width(),i.iScrollTop=e.scrollTop(),i.iScrollLeft=e.scrollLeft(),i.iScrollRight=o.iWidth-i.iScrollLeft-i.iWidth,i.iScrollBottom=o.iHeight-i.iScrollTop-i.iHeight},FixedHeader.VERSION="2.0.6",FixedHeader.prototype.VERSION=FixedHeader.VERSION;