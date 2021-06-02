// Begin CONFIG ====================================================
// the dic URL 
const tzDicFolder = "tzdic/";
const tzDicEntryHTML = tzDicFolder+"tzdic.html";
const tzstrCssIframe = {
	width:"100%"
	, height:"100%"
};
// End CONFIG ======================================================

if (typeof $ === "undefined") {
	document.write('<script type="text/javascript" src="'+tzDicFolder+'tzlib/jquery.min.js">\x3C/script>');
}
if(!window.tzdicidx){
	document.write('<script type="text/javascript" src="'+tzDicFolder+'tzdata/tzdicidx.js">\x3C/script>');
}

function TZDicUI(){	
	let thisObj = this;
	// ToneOZDic Parameters
	let tzparam = {
		objInput : null 		
		// Input source of the jQuery Dom to get the dictionary query string		
		, objIframe : null		
		// Output display to a jQuery Dom for the dictionary query results		
		, objOutput : null 		
		// Output parent container of objIframe		
		, fnGetPhrases : null	
		// Custome function to get query strings from objInput
		, fnGetHash : null		
		// Custom Dictionary Index Hash function to overwrite the defautl function fnDftDicHash()
		, pathCssDic : null		
		// Custom css file path for the objIframe inner content
		, pathJsIVSLookup : null
		// Custeom lookup table to specify the IVS fonts (Ideographic Variation Sequences) displayed in the dictionary entry iframe
		, strCssIframe : tzstrCssIframe
		// Custom css object to decorate the objIframe outter position
		, intMaxPhrase : 16
		// Max phrases per query
		, strVer : ""
		// Version control string
	};
	
	/**
	* Init ToneOZDic
	* @param {any} initparam : parameters to overwrite the default tzparam
	* @return {array} words: output words array	
	*/
	this.init = function(initparam){
		// parameters init
		if(initparam){
			Object.assign(tzparam, initparam);			
		}
		if(!tzparam.objInput){
			tzparam.objInput = $("body");
		}
		if(!tzparam.objIframe){
			tzparam.objIframe = $("<iframe>")
				.addClass("tzIFrame");
		}
		if(!tzparam.objOutput){
			tzparam.objOutput = $(".tzIFrameBox");
			if(tzparam.objOutput.length == 0){
				tzparam.objOutput = $("<div>")
					.addClass("tzIFrameBox")
					.appendTo("body");
			}
		} 
		tzparam.objIframe.detach().appendTo(tzparam.objOutput);		
		if(tzparam.strCssIframe){
			tzparam.objIframe.css(tzparam.strCssIframe);
		}
		if(!tzparam.fnGetHash){
			tzparam.fnGetHash = fnDftDicHash;
		}
		
		// events init
		tzparam.objInput.on('input selectionchange propertychange keydown click focus', function(event) {
			thisObj.tzUpdateEvent({event:event});
		});
		tzparam.objInput.on('DOMSubtreeModified', function(event) {
			thisObj.tzUpdateEvent({event:event});
		});			
		$(document).on('mouseup', function(event) {
			thisObj.tzUpdateEvent({event:event});
		});	
		
		return tzparam;
	};	
	
	/**
	* Dictionary Index Hash function. 
	* Must be sync between the Step1()->fnDftDicHash() in Google Script "TZDicCreator.cs"
    * and the TZDicUI()->fnDftDicHash() in tzdicui.js 
	*/
	function fnDftDicHash(param){
		let {phrase, ischinese = false} = param;
		let hash = phrase;
		if(!ischinese && phrase.length > 1){
			hash = phrase[0]+phrase[1];
		} else if (phrase.length >= 1){
			hash = phrase[0];
		}
		return hash;
	}
	
	let tmrUpdateEvent = null;
	this.tzUpdateEvent = function(dicParam){	
		if(tmrUpdateEvent){
			clearTimeout(tmrUpdateEvent);
			tmrUpdateEvent = null;
		}	
		tmrUpdateEvent = setTimeout(function(){
			if(tzparam.fnGetPhrases){
				let phrasesInfo = tzparam.fnGetPhrases(dicParam);
				if(!phrasesInfo.phrases){
					// not a valid query
					return;
				}
				Object.assign(dicParam, phrasesInfo);
			}
			UpdateDic(dicParam);
		},200);
	}

	function UpdateDic(dicparam){				
		if(!dicparam){
			dicparam = {};
		}
		let {event, phrases, rawstr} = dicparam;
		let qArray = [];
		let tmpq, id, hash, isChinese, objSrc;

		if(!phrases && !rawstr){
			if(event && event.target){
				objSrc = $(event.target);
			} else {
				objSrc = tzparam.objInput;
			}
			// get selected string from a textarea
			rawstr = GetSelectedString(objSrc);
		}
		if(rawstr){
			rawstr = rawstr.trim();
			// query each words in the selected string
			let rawstrarr = splitx(rawstr);
			if(!phrases){
				phrases = [];
			}
			phrases = phrases.concat(rawstrarr);
			
			// add selected string as the first query phrase
			if(phrases.indexOf(rawstr)<0){
				qArray.push(GetQuery({
					phrase : rawstr
				}));				
			}
		}
		
		// get query parameters for ToneOZDic
		for(let idxPhrase in phrases){
			let phrase = phrases[idxPhrase];
			if(qArray.length >= tzparam.intMaxPhrase){
				break;
			}
			qArray.push(GetQuery({
				phrase : phrase
			}));			
		}
		
		let dicURLParam = JSON.stringify(qArray);
		
		// do dictionary query
		let dicURLBase = tzDicEntryHTML + "?" 
			+ (tzparam.strVer ? "v="+tzparam.strVer+"&" : "");
		let URL = dicURLBase+"q="+dicURLParam;			
		if(tzparam.pathCssDic){
			URL += "&css=" + encodeURIComponent(tzparam.pathCssDic+".css");
		}
		if(tzparam.pathJsIVSLookup){
			URL += "&ivs=" + encodeURIComponent(tzparam.pathJsIVSLookup+".js");
		}
		tzparam.objIframe.attr("src", URL).show();
		tmrUpdateDic = null;
		//console.log(URL);
	};	
	
	function GetQuery(param){
		let {phrase} = param;
		
		let isChinese = true;
		if(phrase.length > 0){
			isChinese = chkChinese(phrase[0]);
		}				
		let hash = tzparam.fnGetHash({
			phrase : phrase
			,ischinese : isChinese
		})
		let id = tzdicidx[hash];

		let tmpq = {
			q:phrase
		}				
		if(id !== undefined){
			tmpq.id = id;				
		}	
		
		return tmpq;
	}
	
	function GetSelectedString(objInput){
		let s = null;
		let posStart = objInput.prop("selectionStart");
		let posEnd = objInput.prop("selectionEnd");
		if(posStart !== undefined && posEnd != undefined){
			// textarea
			let clength = posEnd-posStart;
			if(clength<1){
				clength = 1;
			}
			if(posStart == posEnd && posStart!=0){
				posStart--;
			}			
			s = objInput.val().substr(posStart, clength);
		} else {
			// dom HTML
			if (window.getSelection) {
				s = window.getSelection().toString();
			} else if (document.selection && document.selection.type != "Control") {
				s = document.selection.createRange().text;
			}
		}
		return s;
	}
	
	/**
	* split an input string to a words array. 
	* e.g. "你們call out我ok?" => ["你","們","call","out","我","ok","?"]
	* @param {any} s : input string. Support mixed with Chinese and English
	* @return {array} words: output words array
	*/
	function splitx(s){		
		let splittedStr = [...s];
		let arrayLength = splittedStr.length;
		let words = [];
		let englishWord = "";
		let i;
		for (i = 0; i < arrayLength; i += 1) {
			if (/^[a-zA-Z]+$/.test(splittedStr[i])) {
				englishWord += splittedStr[i];
			} else if (/(\s)+$/.test(splittedStr[i])) {
				if (englishWord !== "") {
					words.push(englishWord);
					englishWord = "";
				}
			} else {
				if (englishWord !== "") {
					words.push(englishWord);
					englishWord = "";
				}
				words.push(splittedStr[i]);        
			}
		}

		if (englishWord !== "") {
			words.push(englishWord);
		}
		return words;
	}
	
	function chkChinese(str){
		const REGEX_CHINESE = /[\u4e00-\u9fff]|[\u3400-\u4dbf]|[\u{20000}-\u{2a6df}]|[\u{2a700}-\u{2b73f}]|[\u{2b740}-\u{2b81f}]|[\u{2b820}-\u{2ceaf}]|[\uf900-\ufaff]|[\u3300-\u33ff]|[\ufe30-\ufe4f]|[\uf900-\ufaff]|[\u{2f800}-\u{2fa1f}]/u;
		return REGEX_CHINESE.test(str);
	}
}

