# encoding: utf-8

toolpath = Dir.exists?('d:\fontworks') ? 'd:\fontworks' : 'd:\fontprj'
$otfccdump = toolpath + '\otfcc\otfccdump.exe'
$otfccbuild = toolpath + '\otfcc\otfccbuild.exe'
$ttx = toolpath + '\FDK\Tools\win\ttx'
$bpmfsrc = 'f_bpmfgen.js'

$font_vendor = 'But Ko'
$font_url = 'https://github.com/ButTaiwan/bpmfvs'

require 'json'
require 'set'

$pos = [
	nil,
	[200, 460],
	[400, 50, 660],
	[520, 230, -60, 780]
]

$bpmfname = {
	'ㄅ' => 'b', 'ㄆ' => 'p', 'ㄇ' => 'm', 'ㄈ' => 'f', 'ㄉ' => 'd', 'ㄊ' => 't', 'ㄋ' => 'n', 'ㄌ' => 'l',
	'ㄍ' => 'g', 'ㄎ' => 'k', 'ㄏ' => 'h', 'ㄐ' => 'j', 'ㄑ' => 'q', 'ㄒ' => 'x',
	'ㄓ' => 'zh', 'ㄔ' => 'ch', 'ㄕ' => 'sh', 'ㄖ' => 'r', 'ㄗ' => 'z', 'ㄘ' => 'c', 'ㄙ' => 's',
	'ㄚ' => 'a', 'ㄛ' => 'o', 'ㄜ' => 'e', 'ㄝ' => 'eh', 'ㄞ' => 'ai', 'ㄟ' => 'ei', 'ㄠ' => 'ao', 'ㄡ' => 'ou',
	'ㄢ' => 'an', 'ㄣ' => 'en', 'ㄤ' => 'ang', 'ㄥ' => 'eng', 'ㄦ' => 'er',
	'ㄧ' => 'i', 'ㄨ' => 'u', 'ㄩ' => 'iu'
}


def create_bpmf_glypfs(fnt, use_src_bpmf)
	puts "Now create bpmf glyphs..."
	$z = {}

	# 強制抽換注音符號
	unless use_src_bpmf
		(0x3105..0x3129).each { |i| 
			gn = 'uni' + i.to_s(16).upcase
			$order_sym << gn
			fnt['glyf'][gn]['advanceWidth'] = 1536
			fnt['glyf'][gn]['advanceHeight'] = 1024
			fnt['glyf'][gn]['verticalOrigin'] = 900
		}
		['uni02CA', 'uni02C7', 'uni02CB', 'uni02D9'].each { |gn| 
			$order_sym << gn
			fnt['glyf'][gn]['advanceWidth'] = 1536
			fnt['glyf'][gn]['advanceHeight'] = 1024
			fnt['glyf'][gn]['verticalOrigin'] = 900
		}
	end

	# add small bpmf components to glyph order
	$bpmfname.each { |k, v| $order_zy << 'zy' + v}
	(2..5).each { |i| $order_zy << 'tone' + i.to_s }
		
	f = File.open('phonetic/phonic_types.txt', 'r:utf-8')
	f.each { |s|
		s.chomp!
		zy, py, grp = s.split(/\t/)
		$z[zy] = py
		
		refs = []
		zy = zy.gsub(/[ˊˇˋ˙]/, '')
		len = zy.length
		len.times { |i|
			refs << {"glyph":"zy" + $bpmfname[zy[i]],"x":0,"y":$pos[len][i] + (py[-1] == '5' ? -60 : 0)}
		}
		refs << {"glyph":"tone" + py[-1], "x":300,"y":$pos[len][-2]+(py[-1]=='2' ? 280 : 200) } if py[-1] =~ /[234]/
		refs << {"glyph":"tone5", "x":0,"y":$pos[len][-1]} if py[-1] == '5'
		
		gly = {'advanceWidth': 512, 'advanceHeight': 1024, 'verticalOrigin': 900, 'references': refs }
		fnt['glyf']['z_' + py] = gly
		$order_zy << 'z_' + py
	}
	f.close
end

#$svs = 65024
$ivs = 0xe01e0 #65024
def create_zhuyin_glyphs fnt
	puts "Now create zhuyin glyphs..."
	
	$clist.each { |uniHex, has_han|
		next unless has_han
		uniDec = uniHex.to_i(16).to_s
		c = uniHex.to_i(16).chr(Encoding::UTF_8)
		next unless $zhuyin.has_key?(c)
		
		$zhuyin[c].each_with_index { |zy, i|
			next if i >= 6
			hangn = 'uni'+uniHex+'.ss00'
			gly = {
				'advanceWidth': 1536, 
				'advanceHeight': 1024, 
				'verticalOrigin': fnt['glyf'][hangn]['verticalOrigin'],
				'references': [
					{"glyph": "z_" + $z[zy], "x":1024, "y": 0},
					{"glyph": hangn, "x":0, "y": 0}
				]}
			
			gn = 'uni'+uniHex
			if i == 0
				fnt['cmap'][uniDec] = gn
			else
				gn += '.ss0' + i.to_s
				fnt['cmap_uvs'][uniDec + ' ' + ($ivs + i).to_s] = gn
				$sslist[i]['uni' + uniHex] = gn
			end
			fnt['glyf'][gn] = gly
			$order_han << gn
		}
	}
end

def read_zhuyin_data
	$zhuyin = {}
	#f = File.open('phonetic/phonic_table_C.txt', 'r:utf-8')
	f = File.open('phonetic/phonic_table_Z.txt', 'r:utf-8')
	f.each { |s|
		s.chomp!
		tmp = s.split(/\t/)
		$zhuyin[tmp[0]] = tmp[3..-1]
	}
	f.close
end

def align_pos contours, dir
	min = 9999
	max = -9999
	axis = (dir == 'L' || dir == 'R') ? 'x' : 'y'
	contours.each { |path|
		path.each { |node|
			max = node[axis] if node[axis] > max
			min = node[axis] if node[axis] < min
		}
	}
	
	off = 0
	off = 1136 - max if dir == 'L'
	off =  400 - min if dir == 'R'
	off =  680 - max if dir == 'B'
	off =  100 - min if dir == 'T'
	contours.each_with_index { |path, i|
		path.each_with_index { |node, j|
			contours[i][j][axis] += off
		}
	}
	contours
end

def shift_y contours, off
	return nil if contours == nil
	contours.each_with_index { |path, i|
		path.each_with_index { |node, j|
			contours[i][j]['y'] += off
		}
	}
	contours
end

def gen_rotate_glyph sg
	h = sg['advanceWidth']
	paths = []
	return nil unless sg.has_key?('contours')
	sg['contours'].each { |sp|
		path = []
		sp.each { |sn|
			path << {'x' => sn['y'] + 124, 'y' => h-sn['x'], 'on' => sn['on']}
		}
		paths << path
	}

	return {
		'advanceWidth' => 1536,
		'advanceHeight' => h,
		'verticalOrigin' => h,
		'contours' => paths
	}
end

def read_font fnt, font_file, c_family, e_family, version, use_src_bpmf, offy
	puts "Now dump font to JSON..."
	system("#{$otfccdump} --pretty srcfonts/#{font_file} -o tmp/src_font.js")
	
	$clist = {}
	$ccfg = {}
	(0x20..0x7e).each { |i| $clist[sprintf('%04x', i).upcase] = false}
	f = File.open('big5_merge.txt', 'r:utf-8')
	f.each { |s|
		s.chomp!
		s.gsub!(/\#.*$/, '')
		next if s == ''
		next if s[0] == '#'
		
		u, cfg = s.split(/\t/)
		u.chomp!
		$clist[u] = false
		$ccfg[u] = ',' + (cfg || '') + ','
	}
	f.close

	puts "Now read glyphs from font..."
	
	data = File.read('tmp/src_font.js')
	input = JSON.parse(data)
	set_font_name fnt, input['name'], c_family, e_family, version
	fnt['OS_2']['panose'][2] = input['OS_2']['panose'][2]
	fnt['OS_2']['usWeightClass'] = input['OS_2']['usWeightClass']
	
	# 先清點算過來源字型檔的vert對應
	src_verts = {}
	input['GSUB']['lookups'].each { |lkn, lkup|
		next unless lkn =~ /_vert_/
		
		lkup['subtables'].each { |lktb|
			lktb.each { |n1, n2|
				src_verts[n1] = n2
			}
		}
	}

	# 讀取salt對應（源X系列比例寬字對應至全形字）
	src_salts = {}
	input['GSUB']['lookups'].each { |lkn, lkup|
		next unless lkn =~ /_salt_/
		
		lkup['subtables'].each { |lktb|
			lktb.each { |n1, n2|
				src_salts[n1] = n2
			}
		}
	}

	# 開始複製來源字符
	$clist.keys.each { |uniHex|
		uniDec = uniHex.to_i(16).to_s
		next unless input['cmap'].has_key?(uniDec)

		$clist[uniHex] = true
		
		c = uniDec.to_i.chr(Encoding::UTF_8)
		fgn = input['cmap'][uniDec]
		fgn = src_salts[fgn] if src_salts.has_key?(fgn)
		g = input['glyf'][fgn]
		g['contours'] = shift_y(g['contours'], offy) if offy != 0 && g.has_key?('contours')
		#g['instructions'] = []

		if $zhuyin.has_key?(c)					# 有注音定義的漢字
			g['advanceWidth'] = 1536
			g['advanceHeight'] = 1024
			gn = 'uni' + uniHex + '.ss00'
			fnt['glyf'][gn] = g
			$order_han << gn
			fnt['cmap_uvs'][uniDec + ' ' + ($ivs).to_s] = gn
			$sslist[0]['uni' + uniHex] = gn
		elsif g['advanceWidth'] == 1024 || g['advanceWidth'] == 1000			# 全形符號
			gn = 'uni' + uniHex
			g['advanceWidth'] = 1536
			g['advanceHeight'] = 1024
			g['contours'] = align_pos(g['contours'], $1) if $ccfg[uniHex] =~ /,([LRTB]),/
			fnt['glyf'][gn] = g
			fnt['cmap'][uniDec] = gn
			$order_sym << gn
		else									# 半形符號等
			gn = 'uni' + uniHex
			fnt['glyf'][gn] = g
			fnt['cmap'][uniDec] = gn
			$order_sym << gn
			
			gv = gen_rotate_glyph(g)
			if gv && g['advanceWidth'] < 1000 #1024
				gvn = gn+'.vrt2'
				fnt['glyf'][gvn] = gv
				$vrt2s[gn] = gvn
			end
		end

		# 從來源字型讀取直排(vert)用字符
		next unless $ccfg[uniHex] =~ /,vert,/
		next unless src_verts.has_key?(fgn)
		
		fvgn = src_verts[fgn]
		gv = input['glyf'][fvgn]
		gv['contours'] = shift_y(gv['contours'], offy) if offy != 0 && gv.has_key?('contours')
		#gv['instructions'] = []
		gvn = 'uni' + uniHex + '.vert'
		gv['advanceWidth'] = 1536
		gv['advanceHeight'] = 1024
		fnt['glyf'][gvn] = gv
		$order_sym << gvn
		$verts[gn] = gvn
	}

	return unless use_src_bpmf

	[(0x3105..0x3129).to_a, 0x02CA, 0x02C7, 0x02CB, 0x02D9].flatten.each { |uni|
		uniHex = sprintf('%04x', uni).upcase
		uniDec = uni.to_s
		
		$clist[uniHex] = true
		c = uniDec.to_i.chr(Encoding::UTF_8)
		fgn = input['cmap'][uniDec]
		g = input['glyf'][fgn]
		g['contours'] = shift_y(g['contours'], offy) if offy != 0 && g.has_key?('contours')

		gn = 'uni' + uniHex
		g['advanceWidth'] = 1536
		g['advanceHeight'] = 1024
		fnt['glyf'][gn] = g
		fnt['cmap'][uniDec] = gn
		#fnt['glyf'][gn]['verticalOrigin'] = 900
		$order_sym << gn

		# 從來源字型讀取直排(vert)用字符
		next unless src_verts.has_key?(fgn)
		
		fvgn = src_verts[fgn]
		gv = input['glyf'][fvgn]
		gv['contours'] = shift_y(gv['contours'], offy) if offy != 0 && gv.has_key?('contours')
		gvn = 'uni' + uniHex + '.vert'
		gv['advanceWidth'] = 1536
		gv['advanceHeight'] = 1024
		fnt['glyf'][gvn] = gv
		$order_sym << gvn
		$verts[gn] = gvn
	}
end

def generate_gsub(fnt)
	
	aalts = {}
	aalts_single = {}

	$clist.each { |uniHex, exist|
		next unless exist
		
		if $ccfg[uniHex] =~ /v:([0-9A-F]+)/
			$verts['uni' + uniHex] = 'uni' + $1
		end
	}
	
	$sslist[0].each { |src, obj|
		aalts[src] = [obj]
		(1..5).each { |i| aalts[src] << $sslist[i][src] if $sslist[i].has_key?(src) }
	}
	
	vert = $verts.merge($vrt2s)
	vert.each { |k, v| 
		aalts[k] = [] unless aalts.has_key?(k)
		aalts[k] << v
	}
	
	aalts.each { |k, v|
		next if v.size > 1
		aalts_single[k] = v[0]
		aalts.delete(k)
	}
	

	fnt['GSUB'] = {
		'languages' => {
			'DFLT_DFLT' => { 'features' => ['ss10_00000', 'ss01_00001', 'ss02_00002', 'ss03_00003', 'ss04_00004', 'ss05_00005',
											'vert_00006', 'vrt2_00007', 'aalt_00008'] }
			#'latn_DFLT' => { 'features' => ['aalt_00000', 'vert_00002'] }
		},
		'features' => {
			'ss10_00000' => ['lookup_ss10_0'],
			'ss01_00001' => ['lookup_ss01_1'],
			'ss02_00002' => ['lookup_ss02_2'],
			'ss03_00003' => ['lookup_ss03_3'],
			'ss04_00004' => ['lookup_ss04_4'],
			'ss05_00005' => ['lookup_ss05_5'],
			'vert_00006' => ['lookup_vert_6'],
			'vrt2_00007' => ['lookup_vrt2_7'],
			'aalt_00008' => ['lookup_aalt_8', 'lookup_aalt_9']
		},
		'lookups' => {
			'lookup_vert_6' => { 'type' => 'gsub_single', 'flags' => {}, 'subtables' => [ vert ] },
			'lookup_vrt2_7' => { 'type' => 'gsub_single', 'flags' => {}, 'subtables' => [ vert ] },
			'lookup_aalt_8' => { 'type' => 'gsub_single', 'flags' => {}, 'subtables' => [ aalts_single ] },
			'lookup_aalt_9' => { 'type' => 'gsub_alternate', 'flags' => {}, 'subtables' => [ aalts ] }
		}
	}

	$sslist.each_with_index { |map, i|
		ln = i > 0 ? "lookup_ss0#{i}_#{i}" : "lookup_ss10_0"
		fnt['GSUB']['lookups'][ln] = {'type' => 'gsub_single', 'flags' => {}, 'subtables' => [ map ] }
	}
end

def set_font_name fnt, src_name, c_family, e_family, version
	$nmap = Hash.new { nil }
	src_name.each { |ne| $nmap[ne['nameID']] = ne['nameString'] if ne['platformID'] == 3 }

	weight = $nmap[17] || $nmap[2] || 'Regular'
	license = $nmap[13] || nil
	license_url = $nmap[14] || nil
	$psname = e_family.gsub(/\s/, '') + '-' + weight
	
	identifier = (version+';'+$psname).gsub(/\s/, '')
	
	fnt['head']['fontRevision'] = version.to_f
	fnt['name'] = [
		{ 'platformID' => 3, 'encodingID' => 1, 'languageID' => 1028, 'nameID':  1, 'nameString': c_family + ' ' + weight },
		{ 'platformID' => 3, 'encodingID' => 1, 'languageID' => 1028, 'nameID':  2, 'nameString': weight },
		{ 'platformID' => 3, 'encodingID' => 1, 'languageID' => 1028, 'nameID':  4, 'nameString': c_family + ' ' + weight },
		{ 'platformID' => 3, 'encodingID' => 1, 'languageID' => 1028, 'nameID': 16, 'nameString': c_family },
		{ 'platformID' => 3, 'encodingID' => 1, 'languageID' => 1028, 'nameID': 17, 'nameString': weight },

		{ 'platformID' => 3, 'encodingID' => 1, 'languageID' => 1033, 'nameID':  1, 'nameString': e_family + ' ' + weight },
		{ 'platformID' => 3, 'encodingID' => 1, 'languageID' => 1033, 'nameID':  2, 'nameString': weight },
		{ 'platformID' => 3, 'encodingID' => 1, 'languageID' => 1033, 'nameID':  3, 'nameString': identifier },
		{ 'platformID' => 3, 'encodingID' => 1, 'languageID' => 1033, 'nameID':  4, 'nameString': e_family + ' ' + weight },
		{ 'platformID' => 3, 'encodingID' => 1, 'languageID' => 1033, 'nameID':  5, 'nameString': 'Version ' + version },
		{ 'platformID' => 3, 'encodingID' => 1, 'languageID' => 1033, 'nameID':  6, 'nameString': $psname },
		{ 'platformID' => 3, 'encodingID' => 1, 'languageID' => 1033, 'nameID':  8, 'nameString': $font_vendor },
		{ 'platformID' => 3, 'encodingID' => 1, 'languageID' => 1033, 'nameID': 11, 'nameString': $font_url },
		{ 'platformID' => 3, 'encodingID' => 1, 'languageID' => 1033, 'nameID': 16, 'nameString': e_family },
		{ 'platformID' => 3, 'encodingID' => 1, 'languageID' => 1033, 'nameID': 17, 'nameString': weight },

		{ 'platformID' => 1, 'encodingID' => 0, 'languageID' => 0, 'nameID':  1, 'nameString': e_family + ' ' + weight },
		{ 'platformID' => 1, 'encodingID' => 0, 'languageID' => 0, 'nameID':  2, 'nameString': weight },
		{ 'platformID' => 1, 'encodingID' => 0, 'languageID' => 0, 'nameID':  3, 'nameString': identifier },
		{ 'platformID' => 1, 'encodingID' => 0, 'languageID' => 0, 'nameID':  4, 'nameString': e_family + ' ' + weight },
		{ 'platformID' => 1, 'encodingID' => 0, 'languageID' => 0, 'nameID':  5, 'nameString': 'Version ' + version },
		{ 'platformID' => 1, 'encodingID' => 0, 'languageID' => 0, 'nameID':  6, 'nameString': $psname },
		{ 'platformID' => 1, 'encodingID' => 0, 'languageID' => 0, 'nameID':  8, 'nameString': $font_vendor },
		{ 'platformID' => 1, 'encodingID' => 0, 'languageID' => 0, 'nameID': 11, 'nameString': $font_url },
		{ 'platformID' => 1, 'encodingID' => 0, 'languageID' => 0, 'nameID': 16, 'nameString': e_family },
		{ 'platformID' => 1, 'encodingID' => 0, 'languageID' => 0, 'nameID': 17, 'nameString': weight }
	]

	fnt['name'] << { 'platformID' => 3, 'encodingID' => 1, 'languageID' => 1033, 'nameID': 13, 'nameString': license } if license && license != ''
	fnt['name'] << { 'platformID' => 3, 'encodingID' => 1, 'languageID' => 1033, 'nameID': 14, 'nameString': license_url } if license_url && license_url != ''

end

def make_font src_font, c_family, e_family, version, use_src_bpmf=false, offy=0
	read_zhuyin_data

	data = File.read($bpmfsrc)
	fnt = JSON.parse(data)

	$order_sym = []
	$order_zy = []
	$order_han = []

	fnt['cmap_uvs'] = {} unless fnt.has_key?('cmap_uvs')
	fnt['OS_2']['ulCodePageRange1'] = { 'big5' => true }
	fnt['OS_2']['fsType'] = 0
	
	$sslist = []
	$verts = {}
	$vrt2s = {}
	6.times { |i| $sslist[i] = {} }

	#read_font(fnt, 'SourceHanSansTW-Regular.ttf', '音源黑體', 'Yinyuan Sans', '0.100')
	read_font(fnt, src_font, c_family, e_family, version, use_src_bpmf, offy)
	create_bpmf_glypfs(fnt, use_src_bpmf)
	create_zhuyin_glyphs(fnt)

	generate_gsub(fnt)


	fnt['glyph_order'] = ['.notdef'] + $order_sym.sort + $order_zy + $order_han.sort

	f = File.open('tmp/output.js', 'w:utf-8')
	f.puts JSON.pretty_generate(fnt)
	f.close

	puts "Build TrueType font... (pre)"
	system("#{$otfccbuild} tmp/output.js -o tmp/otfbuild.ttf")

	puts "Fix Cmap..."
	system("#{$ttx} -t cmap -o tmp/otfbuild_cmap.ttx tmp/otfbuild.ttf")
	system("#{$ttx} -m tmp/otfbuild.ttf -o outputs/#{$psname}.ttf tmp/otfbuild_cmap.ttx")
end

make_font('ZihiKaiStd.ttf', 'ㄅ字嗨注音標楷', 'Bpmf Zihi KaiStd', '1.100', true)
make_font('GenRyuMinTW-B.ttf', 'ㄅ源流注音明體', 'Bpmf GenRyu Min', '1.100', true)
make_font('GenRyuMinTW-EL.ttf', 'ㄅ源流注音明體', 'Bpmf GenRyu Min', '1.100', true)
make_font('GenRyuMinTW-H.ttf', 'ㄅ源流注音明體', 'Bpmf GenRyu Min', '1.100', true)
make_font('GenRyuMinTW-L.ttf', 'ㄅ源流注音明體', 'Bpmf GenRyu Min', '1.100', true)
make_font('GenRyuMinTW-M.ttf', 'ㄅ源流注音明體', 'Bpmf GenRyu Min', '1.100', true)
make_font('GenRyuMinTW-R.ttf', 'ㄅ源流注音明體', 'Bpmf GenRyu Min', '1.100', true)
make_font('GenRyuMinTW-SB.ttf', 'ㄅ源流注音明體', 'Bpmf GenRyu Min', '1.100', true)
make_font('GenSekiGothicTW-B.ttf', 'ㄅ源石注音黑體', 'Bpmf GenSeki Gothic', '1.100', true)
make_font('GenSekiGothicTW-H.ttf', 'ㄅ源石注音黑體', 'Bpmf GenSeki Gothic', '1.100', true)
make_font('GenSekiGothicTW-L.ttf', 'ㄅ源石注音黑體', 'Bpmf GenSeki Gothic', '1.100', true)
make_font('GenSekiGothicTW-M.ttf', 'ㄅ源石注音黑體', 'Bpmf GenSeki Gothic', '1.100', true)
make_font('GenSekiGothicTW-R.ttf', 'ㄅ源石注音黑體', 'Bpmf GenSeki Gothic', '1.100', true)
make_font('GenSenRoundedTW-B.ttf', 'ㄅ源泉注音圓體', 'Bpmf GenSen Rounded', '1.100', true)
make_font('GenSenRoundedTW-EL.ttf', 'ㄅ源泉注音圓體', 'Bpmf GenSen Rounded', '1.100', true)
make_font('GenSenRoundedTW-H.ttf', 'ㄅ源泉注音圓體', 'Bpmf GenSen Rounded', '1.100', true)
make_font('GenSenRoundedTW-L.ttf', 'ㄅ源泉注音圓體', 'Bpmf GenSen Rounded', '1.100', true)
make_font('GenSenRoundedTW-M.ttf', 'ㄅ源泉注音圓體', 'Bpmf GenSen Rounded', '1.100', true)
make_font('GenSenRoundedTW-R.ttf', 'ㄅ源泉注音圓體', 'Bpmf GenSen Rounded', '1.100', true)
make_font('GenWanMinTW-EL.ttf', 'ㄅ源雲注音明體', 'Bpmf GenWan Min', '1.100', true)
make_font('GenWanMinTW-L.ttf', 'ㄅ源雲注音明體', 'Bpmf GenWan Min', '1.100', true)
make_font('GenWanMinTW-M.ttf', 'ㄅ源雲注音明體', 'Bpmf GenWan Min', '1.100', true)
make_font('GenWanMinTW-R.ttf', 'ㄅ源雲注音明體', 'Bpmf GenWan Min', '1.100', true)
make_font('GenWanMinTW-SB.ttf', 'ㄅ源雲注音明體', 'Bpmf GenWan Min', '1.100', true)
make_font('GenYoGothicTW-B.ttf', 'ㄅ源樣注音黑體', 'Bpmf GenYo Gothic', '1.100', true)
make_font('GenYoGothicTW-EL.ttf', 'ㄅ源樣注音黑體', 'Bpmf GenYo Gothic', '1.100', true)
make_font('GenYoGothicTW-H.ttf', 'ㄅ源樣注音黑體', 'Bpmf GenYo Gothic', '1.100', true)
make_font('GenYoGothicTW-L.ttf', 'ㄅ源樣注音黑體', 'Bpmf GenYo Gothic', '1.100', true)
make_font('GenYoGothicTW-M.ttf', 'ㄅ源樣注音黑體', 'Bpmf GenYo Gothic', '1.100', true)
make_font('GenYoGothicTW-N.ttf', 'ㄅ源樣注音黑體', 'Bpmf GenYo Gothic', '1.100', true)
make_font('GenYoGothicTW-R.ttf', 'ㄅ源樣注音黑體', 'Bpmf GenYo Gothic', '1.100', true)
make_font('GenYoMinTW-B.ttf', 'ㄅ源樣注音明體', 'Bpmf GenYo Min', '1.100', true)
make_font('GenYoMinTW-EL.ttf', 'ㄅ源樣注音明體', 'Bpmf GenYo Min', '1.100', true)
make_font('GenYoMinTW-H.ttf', 'ㄅ源樣注音明體', 'Bpmf GenYo Min', '1.100', true)
make_font('GenYoMinTW-L.ttf', 'ㄅ源樣注音明體', 'Bpmf GenYo Min', '1.100', true)
make_font('GenYoMinTW-M.ttf', 'ㄅ源樣注音明體', 'Bpmf GenYo Min', '1.100', true)
make_font('GenYoMinTW-R.ttf', 'ㄅ源樣注音明體', 'Bpmf GenYo Min', '1.100', true)
make_font('GenYoMinTW-SB.ttf', 'ㄅ源樣注音明體', 'Bpmf GenYo Min', '1.100', true)
make_font('SourceHanSansTW-Bold.ttf', 'ㄅ字嗨注音黑體', 'Bpmf Zihi Sans', '1.100', true)
make_font('SourceHanSansTW-ExtraLight.ttf', 'ㄅ字嗨注音黑體', 'Bpmf Zihi Sans', '1.100', true)
make_font('SourceHanSansTW-Heavy.ttf', 'ㄅ字嗨注音黑體', 'Bpmf Zihi Sans', '1.100', true)
make_font('SourceHanSansTW-Light.ttf', 'ㄅ字嗨注音黑體', 'Bpmf Zihi Sans', '1.100', true)
make_font('SourceHanSansTW-Medium.ttf', 'ㄅ字嗨注音黑體', 'Bpmf Zihi Sans', '1.100', true)
make_font('SourceHanSansTW-Regular.ttf', 'ㄅ字嗨注音黑體', 'Bpmf Zihi Sans', '1.100', true)
make_font('SourceHanSerifTW-Bold.ttf', 'ㄅ字嗨注音宋體', 'Bpmf Zihi Serif', '1.100')
make_font('SourceHanSerifTW-ExtraLight.ttf', 'ㄅ字嗨注音宋體', 'Bpmf Zihi Serif', '1.100')
make_font('SourceHanSerifTW-Heavy.ttf', 'ㄅ字嗨注音宋體', 'Bpmf Zihi Serif', '1.100')
make_font('SourceHanSerifTW-Light.ttf', 'ㄅ字嗨注音宋體', 'Bpmf Zihi Serif', '1.100')
make_font('SourceHanSerifTW-Medium.ttf', 'ㄅ字嗨注音宋體', 'Bpmf Zihi Serif', '1.100')
make_font('SourceHanSerifTW-Regular.ttf', 'ㄅ字嗨注音宋體', 'Bpmf Zihi Serif', '1.100')
make_font('SourceHanSerifTW-SemiBold.ttf', 'ㄅ字嗨注音宋體', 'Bpmf Zihi Serif', '1.100')
