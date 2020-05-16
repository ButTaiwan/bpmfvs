# 教育部重編國語字典 - 蒐集輕聲字
def make_tableE
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

# (B) 教育部重編國語辭典 *A已收錄之文字捨棄 *C已收的文字，讀音順序排在後面
f = File.open('phonic_table_B.txt', 'r:utf-8')
f.each { |s|
	s.chomp!
	tmp = s.split(/\t/)

	if src.has_key?(tmp[0])
		tmp[3..-1].each { |t|
			next if t[0] != '˙'
			puts "#{tmp[0]}\t#{t}" if !read[tmp[0]].has_key?(t)
		}
	end
}
f.close