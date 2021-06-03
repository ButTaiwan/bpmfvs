var text = [];
var curr = -1;
var vsbase = 0xe01e0;
window.textinfo = {};

String.prototype.unicharAt = function (i) {
	if (this.charAt(i).match(/[\ud800-\udb7f]/)) return this.substr(i, 2);
	return this.charAt(i);
};

function chr(uni) {
	if (String.fromCodePoint) return String.fromCodePoint(uni);	// ES6
	if (uni <= 0xffff) return String.fromCharCode(uni);
	return String.fromCharCode(0xd800 | (((uni-0x10000) >> 10) & 0x03ff), // UTF-16 surrogate pairs
								0xdc00 | ((uni-0x10000) & 0x03ff));
}

function match(c, i, p, j, onlydic) {
	var pos = p.indexOf('*');
	if (i-pos<0) return false;
	if (i-pos+p.length>text.length) return false;

	var tmp = '';
	for (var z=i-pos; z<i-pos+p.length; z++) tmp += text[z].charAt(0);
	if (tmp != p.replace(/\*/g, c)) return false;
	
	var phrase = p.replace("*",c);
	for (var x=0; x<p.length; x++) {
		var a = i-pos+x;
		var spDom = $('#sp' + a);
		
		// update ivs
		if (p.charAt(x) == '*' && !onlydic) {
			text[a] = c + (j > 0 ? chr(vsbase + j*1) : '');
			spDom.text(text[a]).addClass('auto');
		}

		// update phrase for dic
		if(!textinfo[a]){
			textinfo[a] = {};
		}
		var ivsinfo = textinfo[a];
		var phrasearr = ivsinfo.phrasearr;		
		var phrasedata = {phrase:phrase,x:x,a:a};
		if(phrasearr === undefined){
			phrasearr = [phrasedata];
		} else {
			phrasearr.push(phrasedata);
		} 
		ivsinfo.phrasearr = phrasearr;
	}
}

function autoSelect() {
	for (var i=0; i<text.length; i++) {
		var t = text[i];
		var c = t.charAt(0);
		if (!data[c]) continue;
		var onlydic = false;
		if (t.length > 1) {
			// For IVS char, do not overwrite the inserted text
			onlydic = true;
		};
		//if (t.length > 1) continue;
		if (!data[c].v) continue;
		
here:	for (var j in data[c].v) {
			if (!data[c].v[j]) continue;
			var list = data[c].v[j].split('/');
			for (var n=0; n<list.length; n++) {
				if (match(c, i, list[n], j, onlydic)) break here;
			}
			//console.log(list);
		}
		//console.log(c);
	}
}

function goNext(step) {
	if (!step) step = 1;
	
	$('.curr').removeClass('curr');
	
	var c, d;
	do {
		curr += step;
		if (curr >= text.length) curr = 0;
		if (curr < 0) curr = text.length-1;
		
		c = text[curr].charAt(0);
		d = data[c.charAt(0)];
	} while (! d);
	
	var sp = $('#sp' + curr);
	sp.addClass('curr');
	//console.log( sp );
	$('#editor').animate({'scrollTop': sp.prop('offsetTop') - 200}, 200 ); // prop('scrollTop',  );
	//console.log([ sp.position(), sp[0].scrollTop])
	
	//return;
	var sel = $('#selector').empty();
	for (var i=0; i<d.s; i++) {
		var sl = $('<span data-vs=' + i + '></span>').text(c + (i > 0 ? chr(vsbase+i) : ''));
		sl.click(function() {
			var vs = $(this).data('vs') * 1;
			text[curr] = text[curr].charAt(0) + (vs > 0 ? chr(vsbase+vs) : '');
			$('#sp' + curr).text(text[curr]).removeClass('auto').addClass('ok');
			goNext();
		});
		sl.appendTo(sel);
	}
}

function setEditorText(t) {
	//text = t.replace(/(.)/sg, "\x01$1").replace(/\x01([\ufe00-\ufe0f])/ug, "$1").split(/\x01/);
	
	// [\ud800-\udfff] means surrogate pairs of UTF-16
	// Here I wrote /(.|\n)/g because MS Edge doesn't support /(.)/s.
	//text = t.replace(/(.|\n)/g, "\x01$1").replace(/\x01([\ud800-\udfff])/g, "$1").split(/\x01/);
	text = t.replace(/(.|\n)/g, "\x01$1").replace(/\x01([\udb40\udc00-\udfff])/g, "$1").split(/\x01/);
	textinfo = {};

	var editor = $('#editor');
	$('#editor').empty();

	var html = '';
	for (var i in text) {
		var c = text[i];
		if (c == '\n') {
			$('<span id="sp'+ i +'" data-i="'+ i +'"><br></span>').appendTo(editor);
		} else {
			var sp = $('<span id="sp'+ i +'" data-i="'+ i +'"></span>').text(c).appendTo(editor);
			if (data[c.charAt(0)]) {
				sp.addClass('p');
				if (data[c.charAt(0)].f) sp.addClass('fuzzy');
			}
		}
	}
	editor.show();
	curr = -1;
	var cnt = $('#editor span.p').length;
	if (cnt > 0) {
		goNext();
		autoSelect();
	} else {
		alert('文章內查無任何多音字。');
		$('#done').click();
	}
}

$('#editor').on('click', '.p', function(n) {
	curr = $(this).data('i')*1-1;
	goNext();
});

$('#prev').click(function() { goNext(-1); })
$('#next').click(function() { goNext(); })

$('#start').click(function() {
	var t = $('#input').val();
	//if (t == '') return;

	$('#input').hide();
	$('.navi').show();
	$('#done').show();
	$('#start').hide();
	$('#info2').show();
	$('#info1').hide();

	setEditorText(t);
});

$('#done').click(function() {
	var res = ''
	for (var i in text) res += text[i];
	$('#editor').hide();
	$('#selector').empty();
	$('#input').val(res).show().select();
	$('.navi').hide();
	$('#done').hide();
	$('#start').show();
	$('#info2').hide();
	$('#info1').show();
});

$(window).resize(function() {
	var w = $(window).width();
	var h = $(window).height();
	$('#body').css({width: (w-40)+'px', height: (h-160)+'px'});
	$('#main').css({height: (h-194)+'px'});

}).resize();