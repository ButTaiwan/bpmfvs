// BEGIN CONFIG /////////
// Folder path of the dictionary files
const defaultDataFolder = "./tzdata/";
// Max phrases per query 
const intMaxPhrase = 16;
// END CONFIG /////////
const vsbase = 0xe01e0;
let tzQuery, tzQueryArray, tzCss, tzIvsPosDic, tzVer;
let winSearch = window.location.search;
if(!window.tzdic){
	window.tzdic = {};
}
if(winSearch){
	const urlParams = new URLSearchParams(winSearch);
	tzQuery = urlParams.get("q");	
	tzCss = urlParams.get("css");	
	tzIvsPosDic = urlParams.get("ivs");	
	tzVer = urlParams.get("v");	
	tzVer = (tzVer?"?v="+tzVer:"");
	tzQueryArray = JSON.parse(tzQuery);	
	if(tzCss){
		document.write('<link rel="stylesheet" href="'+tzCss + tzVer +'" />');
	}
	if(tzIvsPosDic){
		document.write('<script type="text/javascript" src="' +tzIvsPosDic
		+ tzVer + '">\x3C/script>');
	}
	if(tzQueryArray){
		for(let qIdx in tzQueryArray){
			if(tzQueryArray[qIdx].id){
				document.write('<script type="text/javascript" src="' 
				+ defaultDataFolder
				+ (""+tzQueryArray[qIdx].id)+'.js'
				+ tzVer + '">\x3C/script>');
			}
		}			
	}	
}

let poyinMaxCount = 6;
let separators = [" ", "　"];
$(document).ready(function () {
	let outputDom = $("<div>").appendTo("body");
	if(typeof window.ivsdic === "undefined"){
		window.ivsdic = null;
	}
	if(tzdic){
		let isPrevIVSCtl = false;
		for(let qIdx=0; qIdx<tzQueryArray.length; qIdx++){
			let item = tzQueryArray[qIdx];
			let dicSlot = null;
			if(item.id){
				dicSlot = ""+item.id;
			}
			if(item.q){					
				for(let pi = 0; pi < poyinMaxCount; pi++){
					// lookup each poyin option
					let posfix = "";
					let result=null,resultDom, qDom, zDom, dDom;
					if(pi>0){
						posfix = pi;
					}
					if(item.q){	
						let qarray = null;
						let yinarray = null;
						let noivs = removeIVS(item.q);
						if(item.q && !noivs){
							isPrevIVSCtl = true;
							break;;
						}
						if(isPrevIVSCtl){
							isPrevIVSCtl = false;
							if(HasIvsPair(item.q)){
								break;
							}
						}
						// check is the dictionary data tzdata loaded
						if(tzdic[dicSlot]){
							// dictionary lookup
							result = tzdic[dicSlot][noivs+posfix];
							if(result && ivsdic){
								qarray = noivs.split("");
								if(result && result.z){
									yinarray = result.z.split(new RegExp(separators.join('|'), 'g'));
								}
							}
						}
						if(result || pi==0){
							let phraseivs = item.q;
							if(ivsdic && result && yinarray){
								phraseivs = "";
								for(let iq in qarray){
									let c = qarray[iq];
									let yin = yinarray[iq];
									if(yin && ivsdic[yin] && ivsdic[yin][c] !== undefined){
										let ivspos = ivsdic[yin][c];
										c = getIVS(c,ivspos);
									}
									phraseivs += c;
								}
							}
							qDom = $("<div class='dicq'>").html(phraseivs); // phrase
							resultDom = $("<div class='diccard'>")
								.append(qDom)
								.appendTo(outputDom);
						}
						if(result){
							zDom = $("<div class='dicz'>").html(result.z); // yin (zhuyin)
							dDom = $("<div class='dicd'>").html(result.d); // desc						
							resultDom
								.append(zDom)
								.append(dDom);
						}
					}
				}								
			}
			if(qIdx >= intMaxPhrase-1){
				break;
			}
		}	
	}
	parent.postMessage("ready " + tzQuery, "*");
});

function getIVS(c, j){
	return c + (j > 0 ? chr(vsbase + j*1) : '');
}

function removeIVS(q){
	let noivs = "";
	if(q){
		let qarr = q.split("");
		let prevIsVbase = false;
		for(iq=0;iq<qarr.length;iq++){
			if(qarr[iq] == "\udb40"){
				prevIsVbase = true;
				continue;
			} 
			if(!prevIsVbase){
				noivs += qarr[iq];
			}
			prevIsVbase = false;
		}
	}
	return noivs;
}

function HasIvsPair(q){
	return q.match(/([\ud800-\udfff])/g);
}

function chr(uni) {
	if (String.fromCodePoint) return String.fromCodePoint(uni);	// ES6
	if (uni <= 0xffff) return String.fromCharCode(uni);
	return String.fromCharCode(0xd800 | (((uni-0x10000) >> 10) & 0x03ff), // UTF-16 surrogate pairs
								0xdc00 | ((uni-0x10000) & 0x03ff));
}