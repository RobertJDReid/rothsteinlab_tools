var Magnifier=function(e,t){"use strict";var o=t||{},a=null,n={x:0,y:0,w:0,h:0,lensW:0,lensH:0,lensBgX:0,lensBgY:0,largeW:0,largeH:0,largeL:0,largeT:0,zoom:2,largeWrapperId:o.largeWrapper.id||null,status:0,zoomAttached:!1,zoomable:void 0!==o.zoomable?o.zoomable:!1,onthumbenter:void 0!==o.onthumbenter?o.onthumbenter:null,onthumbmove:void 0!==o.onthumbmove?o.onthumbmove:null,onthumbleave:void 0!==o.onthumbleave?o.onthumbleave:null,onzoom:void 0!==o.onzoom?o.onzoom:null},l={t:0,l:0,x:0,y:0},r=0,s=0,m="",i=null,u=null,d=void 0!==o.zoom?o.zoom:n.zoom,h={},g=!1,c=function(e,t){var o=document.createElement("div");o.id=t+"-lens",o.className="magnifier-loader",e.parentNode.appendChild(o)},p=function(){i.style.left=l.l+"px",i.style.top=l.t+"px",i.style.width=n.lensW+"px",i.style.height=n.lensH+"px",i.style.backgroundPosition="-"+n.lensBgX+"px -"+n.lensBgY+"px",u.style.left="-"+n.largeL+"px",u.style.top="-"+n.largeT+"px",u.style.width=n.largeW+"px",u.style.height=n.largeH+"px"},f=function(e,t,o,a){var n=document.getElementById(e+"-lens"),l=null;1===h[e].status?(l=document.createElement("div"),l.className="magnifier-loader-text",n.className="magnifier-loader hidden",l.appendChild(document.createTextNode("Loading...")),n.appendChild(l)):2===h[e].status&&(n.className="magnifier-lens hidden",n.removeChild(n.childNodes[0]),n.style.background="url("+t.src+") no-repeat 0 0 scroll",o.id=e+"-large",o.style.width=h[e].largeW+"px",o.style.height=h[e].largeH+"px",o.className="magnifier-large hidden",a.appendChild(o)),n.style.width=h[e].lensW+"px",n.style.height=h[e].lensH+"px"},v=function(){var e=l.x-n.x,t=l.y-n.y,o=0,a=0;g=0>e||0>t||e>n.w||t>n.h?!1:!0,a=e-n.lensW/2,o=t-n.lensH/2,e<n.lensW/2&&(a=0),t<n.lensH/2&&(o=0),e-n.w+n.lensW/2>0&&(a=n.w-(n.lensW+2)),t-n.h+n.lensH/2>0&&(o=n.h-(n.lensH+2)),l.l=Math.round(a),l.t=Math.round(o),n.lensBgX=l.l+1,n.lensBgY=l.t+1,n.largeL=Math.round(n.lensBgX*n.zoom*(n.largeWrapperW/n.w)),n.largeT=Math.round(n.lensBgY*n.zoom*(n.largeWrapperH/n.h))},b=function(e){var t=e.wheelDelta>0||e.detail<0?.1:-.1,o=n.onzoom;e.preventDefault&&e.preventDefault(),e.returnValue=!1,n.zoom=Math.round(10*(n.zoom+t))/10,n.zoom>=1.1?(n.lensW=Math.round(n.w/n.zoom),n.lensH=Math.round(n.h/n.zoom),n.largeW=Math.round(n.zoom*n.largeWrapperW),n.largeH=Math.round(n.zoom*n.largeWrapperH),v(),p(),null!==o&&o({thumb:a,lens:i,large:u,x:l.x,y:l.y,zoom:Math.round(10*n.zoom*(n.largeWrapperW/n.w))/10,w:n.lensW,h:n.lensH})):n.zoom=1.1},z=function(){n=h[m],i=document.getElementById(m+"-lens"),2===n.status?(i.className="magnifier-lens",n.zoomAttached===!1&&(void 0!==n.zoomable&&n.zoomable===!0&&(e.attach("mousewheel",i,b),window.addEventListener&&i.addEventListener("DOMMouseScroll",function(e){b(e)})),n.zoomAttached=!0),u=document.getElementById(m+"-large"),u.className="magnifier-large"):1===n.status&&(i.className="magnifier-loader")},y=function(){if(n.status>0){var e=n.onthumbleave;null!==e&&e({thumb:a,lens:i,large:u,x:l.x,y:l.y}),i.className+=" hidden",a.className=n.thumbCssClass,null!==u&&(u.className+=" hidden")}},x=function(){if(s!==n.status&&z(),n.status>0){a.className=n.thumbCssClass+" opaque",1===n.status?i.className="magnifier-loader":2===n.status&&(i.className="magnifier-lens",u.className="magnifier-large",u.style.left="-"+n.largeL+"px",u.style.top="-"+n.largeT+"px"),i.style.left=l.l+"px",i.style.top=l.t+"px",i.style.backgroundPosition="-"+n.lensBgX+"px -"+n.lensBgY+"px";var e=n.onthumbmove;null!==e&&e({thumb:a,lens:i,large:u,x:l.x,y:l.y})}s=n.status},W=function(e,t){var o=e.getBoundingClientRect();t.x=o.left,t.y=o.top,t.w=Math.round(o.right-t.x),t.h=Math.round(o.bottom-t.y),t.lensW=Math.round(t.w/t.zoom),t.lensH=Math.round(t.h/t.zoom),t.largeW=Math.round(t.zoom*t.largeWrapperW),t.largeH=Math.round(t.zoom*t.largeWrapperH)};this.attach=function(t){if(void 0===t.thumb)throw{name:"Magnifier error",message:"Please set thumbnail dom object",toString:function(){return this.name+": "+this.message}};if(void 0===t.large)throw{name:"Magnifier error",message:"Please set large image url",toString:function(){return this.name+": "+this.message}};if(void 0!==h[t.thumb.id])return a=t.thumb,!1;var o=new Image,s=new Image,g=t.thumb,p=g.id,b=null,w=t.largeWrapper||document.getElementById(n.largeWrapperId),M=t.zoom||d,H=void 0!==t.onthumbenter?t.onthumbenter:n.onthumbenter,N=void 0!==t.onthumbleave?t.onthumbleave:n.onthumbleave,B=void 0!==t.onthumbmove?t.onthumbmove:n.onthumbmove,C=void 0!==t.onzoom?t.onzoom:n.onzoom;if(null===w)throw{name:"Magnifier error",message:"Please specify large image wrapper DOM element",toString:function(){return this.name+": "+this.message}};void 0!==t.zoomable?b=t.zoomable:void 0!==n.zoomable&&(b=n.zoomable),""===g.id&&(p=g.id="magnifier-item-"+r,r+=1),c(g,p),h[p]={zoom:M,zoomable:b,thumbCssClass:g.className,zoomAttached:!1,status:0,largeWrapperId:w.id,largeWrapperW:w.offsetWidth,largeWrapperH:w.offsetHeight,onzoom:C,onthumbenter:H,onthumbleave:N,onthumbmove:B},e.attach("mouseover",g,function(e,t){0!==n.status&&y(),m=t.id,a=t,z(t),W(a,n),l.x=e.clientX,l.y=e.clientY,v(),x();var o=n.onthumbenter;null!==o&&o({thumb:a,lens:i,large:u,x:l.x,y:l.y})},!1),e.attach("load",o,function(){h[p].status=1,W(g,h[p]),f(p),e.attach("load",s,function(){h[p].status=2,f(p,g,s,w)}),s.src=t.large}),o.src=g.src},e.attach("mousemove",document,function(e){l.x=e.clientX,l.y=e.clientY,v(),g===!0?x():y()}),e.attach("scroll",window,function(){null!==a&&W(a,n)})};