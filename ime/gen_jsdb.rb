require 'json'

db = {}

f = File.open('../phonetic/phonic_table_Z.txt', 'r:utf-8')
f.each { |s|
	s.chomp!
	next if s == ''
	next if s[0] == '#'
	
	tmp = s.split(/\t/)
	next if tmp.size == 4
	
	c = tmp.shift
	uni = tmp.shift
	grp = tmp.shift
	
	db[c] = { 'g' => grp } #, 'r' => nil } #tmp
	db[c]['r'] = {} # if grp == 'A'
	tmp.each { |r| db[c]['r'][r] = [] }
}
f.close

puts "多音字數量: #{db.count}"

f = File.open('poyin_db.txt', 'r:utf-8')
f.each { |s|
	s.chomp!
	next if s == ''
	next if s[0] == '#'
	
	c, r, vs = s.gsub('、', '/').gsub(/[\[\]]/, '').split(/\s+/)

	fuzzy = false
	if c[-1] == '}'
		c = c[0..-2]
		fuzzy = true
	end
	
	if !db.has_key?(c)
		puts "Error: '#{c}' is not in source data."
		next
	end

	if !db[c]['r'].has_key?(r)
		puts "Error: '#{c}' has no reading '#{r}'."
		next
	end

	db[c]['f'] = fuzzy

	next if vs == nil || vs == ''
	vs.split('/').each { |v|
		v.gsub!(c, '*') if v !~ /\*/
		if v !~ /\*/
			puts "Error: vocabulary '#{v}' doesn't contains char '#{c}'."
			next
		end
		db[c]['r'][r] << v
	}
}
f.close

f = File.open('poyin_db.txt', 'w:utf-8')
f.puts "# 教育部「國語一字多音審訂表(初稿)」範圍"
db.each { |c, v|
	next if v['g'] != 'A'
	
	v['r'].each { |r, vs|
		f.puts "[#{c}] #{r}\t" + vs.join('/') unless v['f']
		f.puts "[#{c}} #{r}\t" + vs.join('/') if v['f']
	}
}

f.puts
f.puts "# 國語一字多音審訂表未收錄範圍"
db.each { |c, v|
	next if v['g'] == 'A'
	
	v['r'].each { |r, vs|
		f.puts "[#{c}] #{r}\t" + vs.join('/')
	}
}
f.close


jsdb = {}
db.each { |k, v|
	jsdb[k] = { 's' => v['r'].size }
	jsdb[k]['f'] = true if v['f']
	flag = false
	vs = []
	v['r'].values.each { |x|
		vs << x.join('/')
		next if x.size == 0
		flag = true
	}
	jsdb[k]['v'] = vs if flag
}

puts "Write poyin_db.js ..."
f = File.open('poyin_db.js', 'w:utf-8')
f.puts 'var data = ' + JSON.pretty_generate(jsdb)
f.close