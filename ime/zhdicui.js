// Begin CONFIG======
const tzDicTitle = "字典";
const tzDicWelcome = "請輸入並按下開始";
const cssUI = 
	".dicWinMin {position:absolute;top:0;right:0;font-size:24px;cursor: pointer;user-select: none;padding:0 10px 0 10px; overflow:hidden;} "
	+ ".dicWin{background: linear-gradient(45deg, rgba(16, 16, 16, 0.7) 0%, rgba(0,0,0,0.9) 40%,rgba(16,16,16,0.7) 100%) !important;opacity:0.95;color:#fff;padding:5px;"
	+ "position:absolute;top:0;left:0;width:50%;height:100px;display:inline-block;} "
	+ ".dicWinTitle {padding:5px;display:inline-block;width:100%;cursor: pointer;user-select: none;} "
	+ ".dicWinDesc {position: absolute;width: 100%;height: 100%;display: flex;justify-content: center;align-items: center;} "
	;
const pathCssDic = "../zihaidic";
const pathJsIVSLookup = "../zhuivsdic";
const strVer="";	
// End CONFIG======

$(document).ready(function () {
	// ZiHaiDicUI init
	let zhDic = new ZiHaiDicUI();	
});

function ZiHaiDicUI(){				
	let domDic = {};
	let isIframeReady = null;
	let dicMinimized = true;
	
	init();

	function init(){
		if (typeof tzDicUI === 'undefined') {	
			initDom();		
		
			// load TonzOZDic		
			window.tzDicUI = new TZDicUI();
			tzDicUI.init({
				objInput : domDic["editor"]
				, objOutput : domDic["dicResult"]
				, fnGetPhrases : fnGetPhrases
				, pathCssDic : pathCssDic
				, pathJsIVSLookup : pathJsIVSLookup
				, strVer : strVer
			});
			
			initUIEvent();
		}
	}
	
	/**
	* Get words for dictionay queries
	* Read "phrase" from a jQuery object's attr. 
	* @param {any} event : jQuery UI event
	* @param {any} srcObj : a jQuery object with attr "phrase"
	* @return {array} words: output words array e.g.: ["行人","行"]
	*/
	function fnGetPhrases(param){
		let {event,srcObj} = param;
		let phrases = null;
		isIframeReady = false;
		if(!srcObj && event && event.target){
			srcObj = $(event.target);						
		}	
		if(srcObj){
			let currDataI = srcObj.attr("data-i");
			if(currDataI !== undefined){
				currDataI = parseInt(currDataI);
				let phrase = srcObj.attr("phrase");				
				let content = srcObj.text();
				if(phrase){
					phrases = phrase.split(",");
				}
				if(content){
					if(!phrases){
						phrases = [];
					}
					phrases.push(content.charAt(0));
				}
			}						
		}		
		
		return {
			phrases:phrases
		};
	}

	function initDom(){
		// dom init
		domDic["editor"] = $("#editor");
		domDic["selector"] = $("#selector");
		domDic["main"] = $("#main");
		domDic["body"] = $("#body");
		domDic["info1"] = $("#info1");
		domDic["info2"] = $("#info2");
		domDic["dicWin"] = $("<span class='dicWin'>").appendTo(domDic["main"]);
		domDic["dicWinTitle"] = $("<span class='dicWinTitle'>").html(tzDicTitle).appendTo(domDic["dicWin"]);
		domDic["dicWinDesc"] = $("<span class='dicWinDesc'>").html(tzDicWelcome).appendTo(domDic["dicWin"]);		
		domDic["loading"] = $('<svg style="width:16px;height:16px;" viewBox="0 0 100 100" preserveAspectRatio="xMidYMid" class="lds-rolling"><circle cx="50" cy="50" fill="none" ng-attr-stroke="{{config.color}}" ng-attr-stroke-width="{{config.width}}" ng-attr-r="{{config.radius}}" ng-attr-stroke-dasharray="{{config.dasharray}}" stroke="#fff" stroke-width="20" r="35" stroke-dasharray="164.93361431346415 56.97787143782138" transform="rotate(30 50 50)"><animateTransform attributeName="transform" type="rotate" calcMode="linear" values="0 50 50;360 50 50" keyTimes="0;1" dur="2s" begin="0s" repeatCount="indefinite"></animateTransform></circle></svg>')
			.hide()
			.appendTo(domDic["dicWinTitle"]);
		domDic["dicResult"] = $("<div>").addClass("tzResult")
			.hide()
			.appendTo(domDic["dicWin"]);
		domDic["dicCss"] = $("<style>").html(cssUI).appendTo($("head"));
		domDic["dicWinMin"] = $("<span class='dicWinMin'>").html("⌵").appendTo(domDic["dicWinTitle"]);
		
		render();
	}

	function initUIEvent(){
		// events init
		$(window).on('resize', function(){
			render();
		});		

		domDic["dicWinTitle"].on("click",function(){
			toggleDicWin();
			render();
		});
		
		$('#prev, #next, #start').click(function() { 
			ShowDicByCurr(); 
		});		

		window.addEventListener("message", function(event) {
			isIframeReady = true;			
			render();
			// inject zhuyin font css
			let iframeObj = domDic["dicResult"].find("iframe");
			let iframehead = iframeObj.contents().find("head");                
			let sdfsdaf=0;
			//iframehead.append($("<style>").html(cssDicEntry));
		});
	}
	
	function ShowDicByCurr(){
		let currObj = $(".curr");
		if(currObj.length > 0){
			let dicParam = {
				srcObj:currObj
			};
			tzUpdateEvent(dicParam);		
		}
	}

	function toggleDicWin(){
		dicMinimized = !dicMinimized;	
		if(!dicMinimized){
			ShowDicByCurr(); 
		}	
	}

	function render(){
		const dicWinPadding = 5;
		const dicWinMinHeight = 30;
		const dicWinMinWidth = 200;
		let bodyPaddingLeft = parseInt(domDic["body"].css("padding-left"));
		let mainTop = domDic["main"].offset().top;
		let bodyMarginTop = parseInt(domDic["body"].css("margin-top"));
		let bodyWidth = domDic["body"].width();
		let bodyHeight = domDic["body"].height();
		let info1Height = domDic["info1"].height();
		let info2Height = domDic["info2"].height();
		let dicWinHeight = dicWinMinHeight;
		let dicWinWidth = dicWinMinWidth;
		let isEditorVisiable = domDic["editor"].is(":visible");
		let iframeWidth = 0;
		let isIFrameVisiable = false;
		let mainDomWidth = "";

		if(!dicMinimized){
			dicWinHeight = bodyHeight - info1Height - parseInt(domDic["main"].css("margin-bottom")) - dicWinPadding*2;
			dicWinWidth = bodyWidth/2;

		}
		domDic["dicWin"].css({
			height: dicWinHeight
			, width : dicWinWidth
			, top:mainTop-bodyMarginTop + bodyHeight - dicWinHeight - dicWinPadding*2 - info1Height
			, left: bodyWidth - dicWinWidth - bodyPaddingLeft
		});
		
		iframeWidth = domDic["dicWin"].width()- dicWinPadding*2;
		if(isIframeReady && isEditorVisiable){
			domDic["loading"].hide();
			if(dicMinimized){
				domDic["dicResult"].hide();
				isIFrameVisiable = false;
			} else {				
				isIFrameVisiable = true;
				domDic["dicResult"].show().css({
					height: dicWinHeight-dicWinMinHeight
					, width : iframeWidth
				});
			}
		} else {
			if(!dicMinimized && isIframeReady != null && isEditorVisiable){
				domDic["loading"].show();
			}
			domDic["dicResult"].hide();
			isIFrameVisiable = false;
		}

		if(!dicMinimized){
			mainDomWidth = dicWinWidth - dicWinPadding*5;
		}
		domDic["main"].css({
			width:mainDomWidth
		});

		if(dicMinimized){
			domDic["dicWinMin"].css({
				"transform":"rotate(180deg)"
				, "margin-top":"7px"
			});
		} else {
			domDic["dicWinMin"].css({
				"transform":""
				, "margin-top":""
			});
		}
		if(dicMinimized || isIFrameVisiable || isEditorVisiable){
			domDic["dicWinDesc"].hide();
		} else {
			domDic["dicWinDesc"].show();
		}
	};
}

