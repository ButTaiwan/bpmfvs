require 'set'

# 一字多音審訂表
def make_tableA
	all = {}
	ptype = Set.new

	f = File.open('source/phonic_table_src.txt', 'r:utf-8')
	f.each { |s|
		s.chomp!
		
		tmp = s.split(/\t/)
		
		all[tmp[0]] = tmp unless all.has_key?(tmp[0])
	}
	f.close

	f = File.open('phonic_table_A.txt', 'w:utf-8')
	all.sort_by{|k, v| k}.each { |k, v|
		f.print v[0] + "\t" + v[0].ord.to_s(16).upcase + "\tA"
		(2..7).each { |i|
			next unless v[i]
			t = v[i].gsub(/[\(（]限讀[\)）]|讀|語| /, '')
			f.print "\t" + t
			
			p t if t =~ /˙$/
			ptype << t
		}
		f.puts
	}
	f.close
	
	puts "A: Type count #{ptype.count}"
end

# 教育部重編國語字典
def make_tableB
	all = {}
	ptype = Set.new

	f = File.open('source/moe_chongbian.txt', 'r:utf-8')
	f.each { |s|
		s.gsub!(/\([一二三四五六七八九]\)/, '')
		s.gsub!(/（[讀語又]音）/, '')
		
		if s =~ /^\d+\t\d+[A-Z]?\t(\W+)\t\W*\t\d+\t\d+\t([˙ㄅ-ㄩˊˇˋ　]+)/
			term = $1
			reads = $2.split(/　/)
			if term.length == reads.size
				term.length.times { |i|
					c = term[i]
					r = reads[i]
					next if i>0 && reads[i][0] == '˙'
					next if c == '○'

					r = '˙ㄑㄧ' if r == '˙ㄑ'

					all[c] = Set.new unless all.include?(c)
					all[c] << r
					ptype << r
				}
			end
		end
	}
	f.close

	f = File.open('phonic_table_B.txt', 'w:utf-8')
	all.sort_by{|k, v| k}.each { |k, v|
		f.puts k + "\t" + k.ord.to_s(16).upcase + "\tB\t" + v.to_a.join("\t")
	}
	f.close
	
	puts "B: Type count #{ptype.count}"
end

# 國立編譯館《化學命名原則》 〈02 元素〉〈附錄一　化學名詞用字之讀音〉
def make_tableC
	list = {}
	f = File.open('source/phonic_chemical.txt', 'r:utf-8')
	f.each { |s|
		s.chomp!
		chr, read = s.split /\s+/ 
		list[chr] = read
	}
	f.close

	all = {}
	if File.exists?('phonic_table_Z.txt')
		f = File.open('phonic_table_Z.txt', 'r:utf-8')
		f.each { |s|
			s.chomp!
			chr, uni, type, read = s.split(/\t/, 4) 
			all[chr] = [type, read]
		}
		f.close
	end

	f = File.open('phonic_table_C.txt', 'w:utf-8')
	list.each { |k, v|
		uni = k.ord.to_s(16).upcase
		f.print "#{k}\t#{uni}\tC\t#{v}\t"
		#f.print "# same" if all.has_key?(k) && v == all[k][1] 
		f.print "# new" if !all.has_key?(k) 
		f.print "# #{all[k][0]} #{all[k][1]}" if all.has_key?(k) && v != all[k][1] 
		f.puts
		#f.puts "#{k}\t#{all[k]}" if all.has_key?(k)
	}
	f.close
end

# 全字庫讀音
def make_tableD
	cnsmap = {}
	f = File.open('source/CNS2UNICODE.txt')		#
	f.each { |s|
		s.chomp!
		pl, pos, uni = s.split(/\t/)
		cnsmap[pl+'-'+pos] = uni
	}
	f.close

	all = {}
	ptype = Set.new

	f = File.open('source/CNS_phonetic.txt', 'r:utf-8')
	f.each { |s|
		s.chomp!
		s.encode!('utf-8')
		k, ph = s.split(/\t/)
		pl, pos = k.split(/-/)
		#k = pl+'-'+pos
		if (pl.to_i <= 3 || ph != 'ㄇㄡˇ') && cnsmap.has_key?(k)
			all[cnsmap[k]] = [] unless all.has_key?(cnsmap[k])
			all[cnsmap[k]] << ph
		end
	}
	f.close

	f = File.open('phonic_table_D.txt', 'w:utf-8')
	all.sort_by{|k, v| k}.each { |k, v|
		f.print k.to_i(16).chr(Encoding::UTF_8) + "\t" + k + "\tB"
		v.each { |t|
			next unless t
			f.print "\t" + t
			
			p t if t =~ /[^ㄅ-ㄩˊˇˋ˙]/
			p t if t =~ /˙$/
			ptype << t
		}
		f.puts
	}
	f.close
	
	puts "D: Type count #{ptype.count}"
end

# 因為全字庫實在收了太多垃圾讀音 所以跟新酷音取交集 ←還是很多
def make_tableD1
	# 新酷音字音資料
	key = {}
	cins = {}
	f = File.open('source/phone.cin.txt', 'r:utf-8')
	f.each { |s|
		s.chomp!
		next if s == ''
		next if s[0] == '%'
		next if s[0] == '#'
		
		k, c = s.split(/ +/)
		key[k] = c[0] if c =~ /^[ㄅ-ㄩˊˇˋ˙]/ && !key.has_key?(k)
		next if c =~ /[ㄅ-ㄩˊˇˋ˙]/
		
		r = ''
		k.each_char { |n| r += key[n] }
		cins[c] = Set.new unless cins.has_key?(c)
		r = '˙' + r[0..-2] if r[-1] == '˙'
		cins[c] << r
		
		#p "#{r}  #{c}"
		#exit if readings.size > 100
	}
	f.close
	
	# 全字庫
	cnsmap = {}
	f = File.open('source/CNS2UNICODE.txt')
	f.each { |s|
		s.chomp!
		pl, pos, uni = s.split(/\t/)
		cnsmap[pl+'-'+pos] = uni.to_i(16).chr(Encoding::UTF_8)
	}
	f.close

	read = {}
	f = File.open('source/CNS_phonetic.txt', 'r:utf-8')
	f.each { |s|
		s.chomp!
		#s.encode!('utf-8')
		k, ph = s.split(/\t/)
		pl, pos = k.split(/-/)
		#k = pl+'-'+pos
		#if (pl.to_i <= 3 || ph != 'ㄇㄡˇ') && cnsmap.has_key?(k)
		if cnsmap.has_key?(k)
			c = cnsmap[k]
		 	if cins.has_key?(c) && cins[c].include?(ph)
		 		read[c] = [] unless read.has_key?(c)
				read[c] << ph
			end
		end
	}
	f.close
	
	ptype = Set.new
	f = File.open('phonic_table_D.txt', 'w:utf-8')
	read.sort_by{|k, v| k}.each { |k, v|
		#f.print k.to_i(16).chr(Encoding::UTF_8) + "\t" + k + "\tB"
		f.print k + "\t" + k.ord.to_s(16).upcase + "\tB"
		v.each { |t|
			next unless t
			f.print "\t" + t
			
			p t if t =~ /[^ㄅ-ㄩˊˇˋ˙]/
			p t if t =~ /˙$/
			ptype << t
		}
		f.puts
	}
	f.close
	
	puts "D1: Type count #{ptype.count}"
end

# 整合以上各表，輸出為注音字型用注音表
def make_tableZ
	read = {}
	src = {}
	ptype = {}
	
	alist = {}

	# (A) 一字多音審訂表 (最優先)
	f = File.open('phonic_table_A.txt', 'r:utf-8')
	f.each { |s|
		s.chomp!
		tmp = s.split(/\t/)
		unless read.has_key?(tmp[0])
			alist[tmp[0]] = s
			
			read[tmp[0]] = {}
			tmp[3..-1].each { |t| 
				read[tmp[0]][t] = 0
				src[tmp[0]] = 'A'
				ptype[t] = 'A'
			}
		end
	}
	f.close

	# (C) 化學讀音表 (by 國家教育研究院)  *A已收錄之文字捨棄
	f = File.open('phonic_table_C.txt', 'r:utf-8')
	f.each { |s|
		s.chomp!
		s.gsub!(/\s*#.*$/, '')
		tmp = s.split(/\t/)
		unless read.has_key?(tmp[0])
			read[tmp[0]] = {}
			tmp[3..-1].each { |t| 
				read[tmp[0]][t] = 99999
				src[tmp[0]] = 'C'
				ptype[t] = 'C' unless ptype.has_key?(t)
			}
			#tmp[3..-1].each { |t| ptype[t] = 'B' unless ptype.has_key?(t) }
		end
	}
	f.close

	# (B) 教育部重編國語辭典 *A已收錄之文字捨棄 *C已收的文字，讀音順序排在後面
	f = File.open('phonic_table_B.txt', 'r:utf-8')
	f.each { |s|
		s.chomp!
		tmp = s.split(/\t/)
		#unless read.has_key?(tmp[0])
		if !src.has_key?(tmp[0]) || src[tmp[0]] == 'C'
			if read.has_key?(tmp[0])
				src[tmp[0]] = 'CB'
			else
				src[tmp[0]] = 'B'
				read[tmp[0]] = {}
			end
			tmp[3..-1].each { |t| 
				read[tmp[0]][t] = 0 unless read[tmp[0]].has_key?(t)
				ptype[t] = 'B' unless ptype.has_key?(t)
			}
			#tmp[3..-1].each { |t| ptype[t] = 'B' unless ptype.has_key?(t) }
		end
	}
	f.close

	# (D) 新酷音與全字庫的交集 *ABC已收錄之文字捨棄
	f = File.open('phonic_table_D.txt', 'r:utf-8')
	f.each { |s|
		s.chomp!
		tmp = s.split(/\t/)
		unless read.has_key?(tmp[0])
			read[tmp[0]] = {}
			tmp[3..-1].each { |t| 
				read[tmp[0]][t] = 0
				src[tmp[0]] = 'D'
				ptype[t] = 'D' unless ptype.has_key?(t)
			}
			#tmp[3..-1].each { |t| ptype[t] = 'B' unless ptype.has_key?(t) }
		end
	}
	f.close
	
	# 新酷音輸入法辭庫 (用來推測讀音常用順序)
	f = File.open('source/tsi.src.txt', 'r:utf-8') 
	f.each { |s|
		s.chomp!
		tmp = s.split(/ /)
		word = tmp.shift
		score = tmp.shift.to_i
		
		word.length.times { |i|
			c = word[i]
			r = tmp[i]
			r = '˙' + r[0..-2] if r[-1] == '˙'
			next unless read.has_key?(c)
			next unless read[c].has_key?(r)
			read[c][r] += score
		}
	}
	
	f = File.open('phonic_table_Z.txt', 'w:utf-8')
	read.sort_by{|k, v| k}.each { |k, v|
		ln = k + "\t" + k.ord.to_s(16).upcase + "\t" + src[k]
		puts "#{k} #{src[k]}  #{v.size}" if v.size > 5
		v.sort_by {|r, sc| -sc}.each { |r, sc|
			ln += "\t" + r
		}
		f.puts src[k] == 'A' ? alist[k] : ln
		
		if src[k] == 'A' && ln != alist[k]
			puts alist[k]
			puts ln
		end
	}
	f.close
	
	puts "Z: Type count #{ptype.count}"
	
	# 生成所有可能出現的注音排列組合
	pmapsrc = {}
	pyset = Set.new
	pmapobj = {}
	f = File.open('source/pinyin_map.txt', 'r:utf-8')
	f.each { |s|
		s.chomp!
		zy, py = s.split(/\t/)
		puts "duplicated! #{py}" if pyset.include?(py)
		pmapsrc[zy] = py
		pyset << py
	}
	f.close
	
	tonemap = { 'ˊ' => '2', 'ˇ' => '3', 'ˋ' => '4', '˙' => '5' }
	ptype.keys.each { |z|
		zy = z.gsub(/([ˊˇˋ˙])/, '')
		tone = $1
		if !pmapsrc.has_key?(zy)
			p zy
		else
			py = pmapsrc[zy] + (tone == nil ? '1' : tonemap[tone])
			pmapobj[z] = py
		end
	}
	
	f = File.open('phonic_types.txt', 'w:utf-8')
	pmapobj.sort_by{|k, v| v}.each { |k, v|
		f.puts "#{k}\t#{v}\t#{ptype[k]}"
	}
	f.close	
end

make_tableA
make_tableB
make_tableC
make_tableD1
make_tableZ