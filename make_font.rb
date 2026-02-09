# encoding: utf-8
require 'json'
require 'set'
require 'fileutils'

# --- CONFIGURATION & PATHS ---

# We rely on the system PATH in GitHub Actions. 
# If running locally on Windows, ensure these are in your PATH or update strictly for local use.
$otfccdump = 'otfccdump'
$otfccbuild = 'otfccbuild'
$ttx = 'ttx'
# On Linux (GitHub Actions), the command is usually '7z'. On Windows, it might be '7z.exe'
$zip = '7z' 

$bpmfsrc = 'f_bpmfgen.json'
$font_vendor = 'But Ko'
$font_designer = 'But Ko'
$font_url = 'https://github.com/ButTaiwan/bpmfvs'

# Ensure directories exist
FileUtils.mkdir_p('tmp')
FileUtils.mkdir_p('outputs')
FileUtils.mkdir_p('source')

$adw = 1500 

$pos = [
    nil, [180, 440], [380, 30, 640], [500, 210, -80, 760]
]

$bpmfname = {
    'ㄅ' => 'b', 'ㄆ' => 'p', 'ㄇ' => 'm', 'ㄈ' => 'f', 'ㄉ' => 'd', 'ㄊ' => 't', 'ㄋ' => 'n', 'ㄌ' => 'l',
    'ㄍ' => 'g', 'ㄎ' => 'k', 'ㄏ' => 'h', 'ㄐ' => 'j', 'ㄑ' => 'q', 'ㄒ' => 'x',
    'ㄓ' => 'zh', 'ㄔ' => 'ch', 'ㄕ' => 'sh', 'ㄖ' => 'r', 'ㄗ' => 'z', 'ㄘ' => 'c', 'ㄙ' => 's',
    'ㄚ' => 'a', 'ㄛ' => 'o', 'ㄜ' => 'e', 'ㄝ' => 'eh', 'ㄞ' => 'ai', 'ㄟ' => 'ei', 'ㄠ' => 'ao', 'ㄡ' => 'ou',
    'ㄢ' => 'an', 'ㄣ' => 'en', 'ㄤ' => 'ang', 'ㄥ' => 'eng', 'ㄦ' => 'er',
    'ㄧ' => 'i', 'ㄨ' => 'u', 'ㄩ' => 'iu'
}

def create_bpmf_glypfs(fnt, use_src_bpmf, spmode = nil)
    puts "Now create bpmf glyphs..."
    $z = {}

    unless use_src_bpmf
        (0x3105..0x3129).each { |i| 
            gn = 'uni' + i.to_s(16).upcase
            $order_sym << gn
            fnt['glyf'][gn]['advanceWidth'] = $adw
            fnt['glyf'][gn]['advanceHeight'] = 1000
            fnt['glyf'][gn]['verticalOrigin'] = 880
        }
        ['uni02CA', 'uni02C7', 'uni02CB', 'uni02D9'].each { |gn| 
            $order_sym << gn
            fnt['glyf'][gn]['advanceWidth'] = $adw
            fnt['glyf'][gn]['advanceHeight'] = 1000
            fnt['glyf'][gn]['verticalOrigin'] = 880
        }
    end

    $bpmfname.each { |k, v| $order_zy << 'zy' + v}
    (2..5).each { |i| $order_zy << 'tone' + i.to_s }

    $verts['uniF000'] = 'uniF000.vert'
    $order_zy << 'uniF000'
    zyv = ['uniF000.vert']
    zyPua = 0xf001
    
    # Check if file exists to prevent crash
    unless File.exist?('phonetic/phonic_types.txt')
        puts "Error: phonetic/phonic_types.txt not found."
        exit 1
    end

    f = File.open('phonetic/phonic_types.txt', 'r:utf-8')
    f.each { |s|
        s.chomp!
        zy, py, grp = s.split(/\t/)
        $z[zy] = py
        
        refs = []
        zy = zy.gsub(/[ˊˇˋ˙]/, '')
        len = zy.length
        len.times { |i|
            refs << { 'glyph' => "zy" + $bpmfname[zy[i]], 'x' => (spmode != 'none' ? -500 : -668), 'y' => $pos[len][i] + (py[-1] == '5' ? -60 : 0)}
        }
        refs << { 'glyph' => "tone" + py[-1], 'x' => (spmode != 'none' ? -200 : -368), 'y' => $pos[len][-2]+(py[-1]=='2' ? 280 : 200) } if py[-1] =~ /[234]/
        refs << { 'glyph' => "tone5", 'x' => (spmode != 'none' ? -500 : -668), 'y' => $pos[len][-1]} if py[-1] == '5'
        
        gn = 'z_' + py
        fnt['glyf'][gn] = { 'advanceWidth' => 0, 'advanceHeight' => 1000, 'verticalOrigin' => 880, 'references' => refs }
        $order_zy << gn
        fnt['cmap'][zyPua] = gn
        zyPua += 1

        gvn = 'z_' + py + '.vert'
        fnt['glyf'][gvn] = { 'advanceWidth' => $adw, 'advanceHeight' => 1, 'verticalOrigin' => -120, 'references' => [{ 'glyph' => gn, 'x' => $adw, 'y' => 0 }] }
        zyv << gvn
        $verts[gn] = gvn
    }
    $order_zy += zyv
    f.close
end

$ivs = 0xe01e0 
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
                'advanceWidth' => $adw, 
                'advanceHeight' => 1000, 
                'verticalOrigin' => fnt['glyf'][hangn]['verticalOrigin'],
                'references' => [
                    { 'glyph' => "z_" + $z[zy], 'x' => $adw, 'y' => 0 },
                    { 'glyph' => hangn, 'x' => 0, 'y' => 0 }
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
    unless File.exist?('phonetic/phonic_table_Z.txt')
        puts "Error: phonetic/phonic_table_Z.txt not found."
        exit 1
    end
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
    off = ($adw-400) - max if dir == 'L'
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

def shift contours, off, xy = 'y'
    return nil if contours == nil
    contours.each_with_index { |path, i|
        path.each_with_index { |node, j|
            contours[i][j][xy] += off
        }
    }
    contours
end

def gen_rotate_glyph sg, input, reverse_map
    # Flatten the glyph using the reverse map to find components
    flat_contours = get_flattened_contours(sg, input, reverse_map)
    
    h = sg['advanceWidth']
    paths = []
    
    flat_contours.each { |sp|
        path = []
        sp.each { |sn|
            path << {'x' => sn['y'] + 120, 'y' => h-sn['x'], 'on' => sn['on']}
        }
        paths << path
    }

    return {
        'advanceWidth' => $adw,
        'advanceHeight' => h,
        'verticalOrigin' => h,
        'contours' => paths
    }
end

# Helper to flatten composites into simple contours for rotation
def get_flattened_contours(g, input_json, reverse_map)
    contours = []
    
    # 1. Get raw contours if they exist
    if g['contours']
        contours += Marshal.load(Marshal.dump(g['contours']))
    end
    
    # 2. Get contours from references (recursive)
    if g['references']
        g['references'].each do |ref|
            target_name = ref['glyph']
            
            # KEY FIX: Look up the Source Name using the Target Name
            src_name = reverse_map[target_name]
            
            # Fallback: Check specific source name, or try target name directly if no map exists
            ref_g = input_json['glyf'][src_name] || input_json['glyf'][target_name]
            
            next unless ref_g
            
            # Recurse with the same map
            ref_contours = get_flattened_contours(ref_g, input_json, reverse_map)
            
            # Apply offsets
            dx = ref['x'] || 0
            dy = ref['y'] || 0
            
            if dx != 0 || dy != 0
                ref_contours.each do |contour|
                    contour.each do |point|
                        point['x'] += dx
                        point['y'] += dy
                    end
                end
            end
            contours += ref_contours
        end
    end
    
    return contours
end

def read_font fnt, font_file, c_family, e_family, version, use_src_bpmf, offy, spmode
    puts "Now dump font to JSON..."
    unless File.exist?("srcfonts/#{font_file}")
        puts "Error: srcfonts/#{font_file} not found."
        exit 1
    end

    system("#{$otfccdump} --pretty \"srcfonts/#{font_file}\" -o tmp/src_font.js")

    # 1. Prepare Target List
    $clist = {}
    $ccfg = {}
    (0x20..0x7e).each { |i| $clist[sprintf('%04x', i).upcase] = false}
    
    f = File.open('allchars.txt', 'r:utf-8')
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
    
    # 1. Sync the UPM
    fnt['head']['unitsPerEm'] = input['head']['unitsPerEm']

    # 2. Sync the Vertical Metrics (Windows)
    fnt['OS_2']['sTypoAscender']  = input['OS_2']['sTypoAscender']
    fnt['OS_2']['sTypoDescender'] = input['OS_2']['sTypoDescender']
    fnt['OS_2']['sTypoLineGap']   = input['OS_2']['sTypoLineGap']

    fnt['OS_2']['usWinAscent'] = input['OS_2']['usWinAscent']
    fnt['OS_2']['usWinDescent'] = input['OS_2']['usWinDescent']

    # 3. Sync the Vertical Metrics (Mac)
    fnt['hhea']['ascent']  = input['hhea']['ascent']
    fnt['hhea']['descent'] = input['hhea']['descent']

    # adding a method to preserve the existing BASE table if it is present in the upstream font. 
    if input.has_key?('BASE')
        puts "Adjusting BASE table..."
        fnt['BASE'] = Marshal.load(Marshal.dump(input['BASE']))
        scale = 1000.0 / input['head']['unitsPerEm'].to_f
        
        ['horizontal', 'vertical'].each do |direction|
            next unless fnt['BASE'][direction] && fnt['BASE'][direction]['scripts']
            
            fnt['BASE'][direction]['scripts'].each do |script_tag, data|
                # otfcc can store these in 'baselines' OR 'baseValues' 
                # Depending on the version and font source
                target_hash = data['baselines'] || data['baseValues']
                next unless target_hash
                
                puts "  Processing #{direction} script: #{script_tag}"
                
                # 2. Specifically shift vertical alignment
                if direction == 'vertical'
                    ['icft', 'idtp', 'ideo'].each do |tag|
                        if target_hash.has_key?(tag)
                            old_val = target_hash[tag]
                            target_hash[tag] += 500
                            puts "    Updated #{tag}: #{old_val} -> #{target_hash[tag]}"
                        end
                    end
                end
            end
        end
    else
        add_base_table(fnt, spmode)
    end

    # 2. Setup Helper Maps
    # Reverse CMap: helps us find the Unicode for a raw glyph name (e.g. "gravecomb" -> "768")
    src_rev_cmap = {}
    input['cmap'].each { |u, g| src_rev_cmap[g] = u }
    
    # Imported Map: Keeps track of "Source Name" -> "Target Name" to resolve references
    $imported_src_map = {}

    # 3. Define Recursive Component Resolver
    # This lambda copies a component, renames it correctly, and ensures it exists in the output
    resolve_component = lambda do |comp_name|
        # If we already imported this component, return its new name
        return $imported_src_map[comp_name] if $imported_src_map.has_key?(comp_name)

        # Determine target name (Try to match Unicode, otherwise keep original)
        u_dec = src_rev_cmap[comp_name]
        if u_dec
            target_name = 'uni' + u_dec.to_i.to_s(16).upcase.rjust(4, '0')
        else
            target_name = comp_name
        end

        # Register mapping immediately to prevent infinite loops
        $imported_src_map[comp_name] = target_name

        # Copy the glyph data
        if input['glyf'].has_key?(comp_name)
            comp_g = input['glyf'][comp_name].dup
            
            # Recursively fix references inside this component
            if comp_g['references']
                comp_g['references'].each do |ref|
                    ref['glyph'] = resolve_component.call(ref['glyph'])
                end
            end

            # Apply standard shifts (same as main logic)
            comp_g['contours'] = shift(comp_g['contours'], offy) if offy != 0 && comp_g.has_key?('contours')

            # Add to output font
            fnt['glyf'][target_name] = comp_g
            # Optional: Add to CMap if it has a unicode (ensures components like space/grave are valid chars)
            fnt['cmap'][u_dec] = target_name if u_dec
        else
            puts "Warning: Referenced component #{comp_name} missing in source."
        end

        return target_name
    end

    # 4. Standard Font Metadata Setup
    set_font_name fnt, input['name'], c_family, e_family, version
    fnt['OS_2']['panose'][2] = input['OS_2']['panose'][2]
    fnt['OS_2']['usWeightClass'] = input['OS_2']['usWeightClass']
    
    src_verts = {}
    if input['GSUB'] && input['GSUB']['lookups']
        input['GSUB']['lookups'].each { |lkn, lkup|
            next unless lkn =~ /_vert_/
            lkup['subtables'].each { |lktb|
                lktb.each { |n1, n2| src_verts[n1] = n2 }
            }
        }
    end

    src_salts = {}
    if input['GSUB'] && input['GSUB']['lookups']
        input['GSUB']['lookups'].each { |lkn, lkup|
            next unless lkn =~ /_salt_/
            lkup['subtables'].each { |lktb|
                lktb.each { |n1, n2| src_salts[n1] = n2 }
            }
        }
    end

    fnt['glyf']['emptyBox']['advanceWidth'] = $adw
    fnt['glyf']['uniF000.vert']['advanceWidth'] = $adw
    fnt['glyf']['uniF000']['contours'] = shift(fnt['glyf']['uniF000']['contours'], -250, 'x') if spmode == 'none'
    fnt['glyf']['uniF000.vert']['contours'] = shift(fnt['glyf']['uniF000.vert']['contours'], -750, 'x') if spmode == 'none'

    # 5. Main Glyph Loop
    $clist.keys.each { |uniHex|
        uniDec = uniHex.to_i(16).to_s
        next unless input['cmap'].has_key?(uniDec)

        $clist[uniHex] = true
        
        c = uniDec.to_i.chr(Encoding::UTF_8)
        fgn = input['cmap'][uniDec]
        fgn = src_salts[fgn] if src_salts.has_key?(fgn)
        
        g = input['glyf'][fgn].dup # Dup is important to avoid modifying original input if referenced later
        g['contours'] = shift(g['contours'], offy) if offy != 0 && g.has_key?('contours')

        if $zhuyin.has_key?(c)
            g['contours'] = fnt['glyf']['emptyBox']['contours'] if spmode == 'box'
            g['contours'] = [] if spmode == 'none' || spmode == 'nonehf'
            g['advanceWidth'] = $adw
            g['advanceHeight'] = 1000
            gn = 'uni' + uniHex + '.ss00'
            fnt['glyf'][gn] = g
            $order_han << gn
            fnt['cmap_uvs'][uniDec + ' ' + ($ivs).to_s] = gn
            $sslist[0]['uni' + uniHex] = gn
            
            # Map this for consistency (though zhuyin logic handles references manually)
            $imported_src_map[fgn] = gn 

        elsif g['advanceWidth'] == 1000
            gn = 'uni' + uniHex
            g['advanceWidth'] = $adw
            g['advanceHeight'] = 1000
            g['contours'] = align_pos(g['contours'], $1) if $ccfg[uniHex] =~ /,([LRTB]),/ && $adw > 1000
            
            # Resolve References (in case fullwidth symbols use components)
            if g['references']
                g['references'].each { |ref| ref['glyph'] = resolve_component.call(ref['glyph']) }
            end

            fnt['glyf'][gn] = g
            fnt['cmap'][uniDec] = gn
            $order_sym << gn
            $imported_src_map[fgn] = gn

        else 
            # Standard Glyph (Latin, etc)
            gn = 'uni' + uniHex
            
            # 1. Register Name FIRST
            $imported_src_map[fgn] = gn
            
            # 2. Recursively Resolve References
            if g['references']
                g['references'].each { |ref| ref['glyph'] = resolve_component.call(ref['glyph']) }
            end

            fnt['glyf'][gn] = g
            fnt['cmap'][uniDec] = gn
            $order_sym << gn
            
            # Generate vertical variant for ALL glyphs (including composites)
            # Create a reverse map (Target Name -> Source Name) so we can find component data
            reverse_map = $imported_src_map.invert
            
            gv = gen_rotate_glyph(g, input, reverse_map)
            
            # Only generate if it looks like a proportional Latin glyph and resulted in contours
            if g['advanceWidth'] < 1000 && !gv['contours'].empty?
                gvn = gn+'.vrt2'
                fnt['glyf'][gvn] = gv
                $vrt2s[gn] = gvn
            end
        end

        next unless $ccfg[uniHex] =~ /,vert,/
        next unless src_verts.has_key?(fgn)
        
        fvgn = src_verts[fgn]
        gv = input['glyf'][fvgn].dup
        gv['contours'] = shift(gv['contours'], offy) if offy != 0 && gv.has_key?('contours')
        
        # Resolve references in vertical alternates too
        if gv['references']
             gv['references'].each { |ref| ref['glyph'] = resolve_component.call(ref['glyph']) }
        end

        gvn = 'uni' + uniHex + '.vert'
        gv['advanceWidth'] = $adw
        gv['advanceHeight'] = 1000
        fnt['glyf'][gvn] = gv
        $order_sym << gvn
        $verts[gn] = gvn
    }

    return unless use_src_bpmf

    # BPMF Logic
    [(0x3105..0x3129).to_a, 0x02CA, 0x02C7, 0x02CB, 0x02D9].flatten.each { |uni|
        uniHex = sprintf('%04x', uni).upcase
        uniDec = uni.to_s
        
        $clist[uniHex] = true
        c = uniDec.to_i.chr(Encoding::UTF_8)
        fgn = input['cmap'][uniDec]
        g = input['glyf'][fgn].dup
        g['contours'] = shift(g['contours'], offy) if offy != 0 && g.has_key?('contours')

        gn = 'uni' + uniHex
        g['advanceWidth'] = $adw
        g['advanceHeight'] = 1000
        
        # Resolve References
        if g['references']
            g['references'].each { |ref| ref['glyph'] = resolve_component.call(ref['glyph']) }
        end

        fnt['glyf'][gn] = g
        fnt['cmap'][uniDec] = gn
        $order_sym << gn
        $imported_src_map[fgn] = gn

        next unless src_verts.has_key?(fgn)
        
        fvgn = src_verts[fgn]
        gv = input['glyf'][fvgn].dup
        gv['contours'] = shift(gv['contours'], offy) if offy != 0 && gv.has_key?('contours')
        
        # Resolve References
        if gv['references']
            gv['references'].each { |ref| ref['glyph'] = resolve_component.call(ref['glyph']) }
        end

        gvn = 'uni' + uniHex + '.vert'
        gv['advanceWidth'] = $adw
        gv['advanceHeight'] = 1000
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
    # Only map platform 3 names (Windows)
    src_name.each { |ne| $nmap[ne['nameID']] = ne['nameString'] if ne['platformID'] == 3 }

    weight = $nmap[17] || $nmap[2] || 'Regular'
    license = $nmap[13] || nil
    license_url = $nmap[14] || nil
    $psname = e_family.gsub(/\s/, '') + '-' + weight
    
    identifier = (version+';'+$psname).gsub(/\s/, '')

    # --- LOGIC UPDATE: Handle NameID 1 (Family Name) ---
    # If weight is "Regular" or "Bold", NameID 1 should just be the Family Name.
    # Otherwise, it is "Family Weight" (for styling groups).
    if ['Regular', 'Bold'].include?(weight)
        c_family_nameid1 = c_family
        e_family_nameid1 = e_family
    else
        c_family_nameid1 = c_family + ' ' + weight
        e_family_nameid1 = e_family + ' ' + weight
    end

    fnt['head']['fontRevision'] = version.to_f
    
    copyright = "Copyright 2025 The Bpmf Project Authors (https://github.com/ButTaiwan/bpmfvs)"

    # Completely rebuild the name table (overriding old entries)
    # Note: We are strictly adding Platform ID 3 (Windows). 
    # Platform ID 1 entries are intentionally omitted.
    fnt['name'] = [
        # --- Chinese (Traditional) - Language ID 1028 ---
        { 'platformID' => 3, 'encodingID' => 1, 'languageID' => 1028, 'nameID' =>  1, 'nameString' => c_family_nameid1 },
        { 'platformID' => 3, 'encodingID' => 1, 'languageID' => 1028, 'nameID' =>  2, 'nameString' => weight },
        { 'platformID' => 3, 'encodingID' => 1, 'languageID' => 1028, 'nameID' =>  4, 'nameString' => c_family + ' ' + weight },
        { 'platformID' => 3, 'encodingID' => 1, 'languageID' => 1028, 'nameID' => 16, 'nameString' => c_family },
        { 'platformID' => 3, 'encodingID' => 1, 'languageID' => 1028, 'nameID' => 17, 'nameString' => weight },

        # --- English (US) - Language ID 1033 ---
        { 'platformID' => 3, 'encodingID' => 1, 'languageID' => 1033, 'nameID' =>  0, 'nameString' => copyright },
        { 'platformID' => 3, 'encodingID' => 1, 'languageID' => 1033, 'nameID' =>  1, 'nameString' => e_family_nameid1 },
        { 'platformID' => 3, 'encodingID' => 1, 'languageID' => 1033, 'nameID' =>  2, 'nameString' => weight },
        { 'platformID' => 3, 'encodingID' => 1, 'languageID' => 1033, 'nameID' =>  3, 'nameString' => identifier },
        { 'platformID' => 3, 'encodingID' => 1, 'languageID' => 1033, 'nameID' =>  4, 'nameString' => e_family + ' ' + weight },
        { 'platformID' => 3, 'encodingID' => 1, 'languageID' => 1033, 'nameID' =>  5, 'nameString' => 'Version ' + version },
        { 'platformID' => 3, 'encodingID' => 1, 'languageID' => 1033, 'nameID' =>  6, 'nameString' => $psname },
        { 'platformID' => 3, 'encodingID' => 1, 'languageID' => 1033, 'nameID' =>  8, 'nameString' => $font_vendor },
        { 'platformID' => 3, 'encodingID' => 1, 'languageID' => 1033, 'nameID' =>  9, 'nameString' => $font_designer },
        { 'platformID' => 3, 'encodingID' => 1, 'languageID' => 1033, 'nameID' => 11, 'nameString' => $font_url },
        { 'platformID' => 3, 'encodingID' => 1, 'languageID' => 1033, 'nameID' => 16, 'nameString' => e_family },
        { 'platformID' => 3, 'encodingID' => 1, 'languageID' => 1033, 'nameID' => 17, 'nameString' => weight }
    ]

    fnt['name'] << { 'platformID' => 3, 'encodingID' => 1, 'languageID' => 1033, 'nameID' => 13, 'nameString' => license } if license && license != ''
    fnt['name'] << { 'platformID' => 3, 'encodingID' => 1, 'languageID' => 1033, 'nameID' => 14, 'nameString' => license_url } if license_url && license_url != ''
end


def add_base_table fnt, spmode      
    scripts = {'DFLT': 'ideo', 'hani': 'ideo', 'kana': 'ideo', 'latn': 'romn', 'cyrl': 'romn', 'grek': 'romn'}
    fnt['BASE'] = {'horizontal' => {}, 'vertical' => {}}
    scripts.each { |sc, tag|
        fnt['BASE']['horizontal'][sc] = {
            'defaultBaseline' => tag,
            'baselines' => {
                'icfb' => -64,
                'icft' => 824,
                'ideo' => -120,
                'idtp' => 880,
                'romn' => 0
            }
        }
        fnt['BASE']['vertical'][sc] = {
            'defaultBaseline' => tag,
            'baselines' => {
                'icfb' => 56,
                'icft' => 944 + (spmode != 'none' ? 500 : 0),
                'ideo' => 0,
                'idtp' => 1000 + (spmode != 'none' ? 500 : 0),
                'romn' => 120
            }
        }
    }
end

def make_font src_font, c_family, e_family, version, use_src_bpmf=false, spmode = nil
    read_zhuyin_data

    unless File.exist?($bpmfsrc)
        puts "Error: #{$bpmfsrc} not found."
        exit 1
    end
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

    $adw = 1500
    $adw = 1000 if spmode == 'none'

    read_font(fnt, src_font, c_family, e_family, version, use_src_bpmf, 0, spmode) 
    create_bpmf_glypfs(fnt, use_src_bpmf, spmode)
    create_zhuyin_glyphs(fnt)

    generate_gsub(fnt)



    fnt['glyph_order'] = ['.notdef'] + $order_sym.sort + $order_zy + $order_han.sort

    json_file = "tmp/#{$psname}.json"
    f = File.open(json_file, 'w:utf-8')
    f.puts JSON.pretty_generate(fnt)
    f.close

    json_zip_file = "source/#{$psname}.json.zip"
    ttf_file = "outputs/#{$psname}.ttf"

    puts "Build TrueType font... (pre)"
    system("#{$otfccbuild} \"#{json_file}\" -o \"#{ttf_file}\"")

    # --- NEW: Post-processing to remove nested components ---
    puts "Fixing nested components..."
    system("python3 decompose.py \"#{ttf_file}\"")
    # --------------------------------------------------------

    # puts "Save JSON zip as Google Fonts source code..."

    # File.delete(json_zip_file) if File.exist?(json_zip_file) 
    # # Use generic '7z' or 'zip' command logic. Here using '7z' as standard for Linux CI
    # system(%Q{"#{$zip}" a -tzip "#{File.basename(json_zip_file)}" "#{File.basename(json_file)}"}, chdir: "tmp") 
    # File.rename("tmp/#{File.basename(json_zip_file)}", json_zip_file) 

    # Uncomment if ttx is needed in the future
    # puts "Fix Cmap..."
    # system("#{$ttx} -t cmap -o tmp/otfbuild_cmap.ttx tmp/otfbuild.ttf")
    # system("#{$ttx} -m tmp/otfbuild.ttf -o outputs/#{$psname}.ttf tmp/otfbuild_cmap.ttx")
end

ver = '1.610'
make_font('Iansui-Regular.ttf', 'ㄅ注音芫荽', 'Bpmf Iansui', ver, true)
make_font('ZihiKaiStd.ttf', 'ㄅ字嗨注音標楷', 'Bpmf Zihi Kai Std', ver, true)
make_font('Huninn-Regular.ttf', 'ㄅ注音粉圓', 'Bpmf Huninn', ver, true)

# make_font('SourceHanSansTW-Bold.ttf', 'ㄅ字嗨注音黑體', 'Bpmf Zihi Sans', ver, true)
# make_font('SourceHanSansTW-ExtraLight.ttf', 'ㄅ字嗨注音黑體', 'Bpmf Zihi Sans', ver, true)
# make_font('SourceHanSansTW-Heavy.ttf', 'ㄅ字嗨注音黑體', 'Bpmf Zihi Sans', ver, true)
# make_font('SourceHanSansTW-Light.ttf', 'ㄅ字嗨注音黑體', 'Bpmf Zihi Sans', ver, true)
# make_font('SourceHanSansTW-Medium.ttf', 'ㄅ字嗨注音黑體', 'Bpmf Zihi Sans', ver, true)
# make_font('SourceHanSansTW-Regular.ttf', 'ㄅ字嗨注音黑體', 'Bpmf Zihi Sans', ver, true)
# make_font('SourceHanSerifTW-Bold.ttf', 'ㄅ字嗨注音宋體', 'Bpmf Zihi Serif', ver)
# make_font('SourceHanSerifTW-ExtraLight.ttf', 'ㄅ字嗨注音宋體', 'Bpmf Zihi Serif', ver)
# make_font('SourceHanSerifTW-Heavy.ttf', 'ㄅ字嗨注音宋體', 'Bpmf Zihi Serif', ver)
# make_font('SourceHanSerifTW-Light.ttf', 'ㄅ字嗨注音宋體', 'Bpmf Zihi Serif', ver)
# make_font('SourceHanSerifTW-Medium.ttf', 'ㄅ字嗨注音宋體', 'Bpmf Zihi Serif', ver)
# make_font('SourceHanSerifTW-Regular.ttf', 'ㄅ字嗨注音宋體', 'Bpmf Zihi Serif', ver)
# make_font('SourceHanSerifTW-SemiBold.ttf', 'ㄅ字嗨注音宋體', 'Bpmf Zihi Serif', ver)

# https://github.com/ButTaiwan/genryu-font
# make_font('GenRyuMin2TW-B.ttf', 'ㄅ源流注音明體', 'Bpmf GenRyu Min', ver, true)
# make_font('GenRyuMin2TW-EL.ttf', 'ㄅ源流注音明體', 'Bpmf GenRyu Min', ver, true)
# make_font('GenRyuMin2TW-H.ttf', 'ㄅ源流注音明體', 'Bpmf GenRyu Min', ver, true)
# make_font('GenRyuMin2TW-L.ttf', 'ㄅ源流注音明體', 'Bpmf GenRyu Min', ver, true)
# make_font('GenRyuMin2TW-M.ttf', 'ㄅ源流注音明體', 'Bpmf GenRyu Min', ver, true)
# make_font('GenRyuMin2TW-R.ttf', 'ㄅ源流注音明體', 'Bpmf GenRyu Min', ver, true)
# make_font('GenRyuMin2TW-SB.ttf', 'ㄅ源流注音明體', 'Bpmf GenRyu Min', ver, true)

# https://github.com/ButTaiwan/genseki-font
# make_font('GenSekiGothic2TW-B.ttf', 'ㄅ源石注音黑體', 'Bpmf GenSeki Gothic', ver, true)
# make_font('GenSekiGothic2TW-H.ttf', 'ㄅ源石注音黑體', 'Bpmf GenSeki Gothic', ver, true)
# make_font('GenSekiGothic2TW-L.ttf', 'ㄅ源石注音黑體', 'Bpmf GenSeki Gothic', ver, true)
# make_font('GenSekiGothic2TW-M.ttf', 'ㄅ源石注音黑體', 'Bpmf GenSeki Gothic', ver, true)
# make_font('GenSekiGothic2TW-R.ttf', 'ㄅ源石注音黑體', 'Bpmf GenSeki Gothic', ver, true)

# https://github.com/ButTaiwan/gensen-font
# make_font('GenSenRounded2TW-B.ttf', 'ㄅ源泉注音圓體', 'Bpmf GenSen Rounded', ver, true)
# make_font('GenSenRounded2TW-EL.ttf', 'ㄅ源泉注音圓體', 'Bpmf GenSen Rounded', ver, true)
# make_font('GenSenRounded2TW-H.ttf', 'ㄅ源泉注音圓體', 'Bpmf GenSen Rounded', ver, true)
# make_font('GenSenRounded2TW-L.ttf', 'ㄅ源泉注音圓體', 'Bpmf GenSen Rounded', ver, true)
# make_font('GenSenRounded2TW-M.ttf', 'ㄅ源泉注音圓體', 'Bpmf GenSen Rounded', ver, true)
# make_font('GenSenRounded2TW-R.ttf', 'ㄅ源泉注音圓體', 'Bpmf GenSen Rounded', ver, true)

# https://github.com/ButTaiwan/genwan-font
# make_font('GenWanMin2TW-EL.ttf', 'ㄅ源雲注音明體', 'Bpmf GenWan Min', ver, true)
# make_font('GenWanMin2TW-L.ttf', 'ㄅ源雲注音明體', 'Bpmf GenWan Min', ver, true)
# make_font('GenWanMin2TW-M.ttf', 'ㄅ源雲注音明體', 'Bpmf GenWan Min', ver, true)
# make_font('GenWanMin2TW-R.ttf', 'ㄅ源雲注音明體', 'Bpmf GenWan Min', ver, true)
# make_font('GenWanMin2TW-SB.ttf', 'ㄅ源雲注音明體', 'Bpmf GenWan Min', ver, true)

# https://github.com/ButTaiwan/genyo-font
# make_font('GenYoGothic2TW-B.ttf', 'ㄅ源樣注音黑體', 'Bpmf GenYo Gothic', ver, true)
# make_font('GenYoGothic2TW-EL.ttf', 'ㄅ源樣注音黑體', 'Bpmf GenYo Gothic', ver, true)
# make_font('GenYoGothic2TW-H.ttf', 'ㄅ源樣注音黑體', 'Bpmf GenYo Gothic', ver, true)
# make_font('GenYoGothic2TW-L.ttf', 'ㄅ源樣注音黑體', 'Bpmf GenYo Gothic', ver, true)
# make_font('GenYoGothic2TW-M.ttf', 'ㄅ源樣注音黑體', 'Bpmf GenYo Gothic', ver, true)
# make_font('GenYoGothic2TW-N.ttf', 'ㄅ源樣注音黑體', 'Bpmf GenYo Gothic', ver, true)
# make_font('GenYoGothic2TW-R.ttf', 'ㄅ源樣注音黑體', 'Bpmf GenYo Gothic', ver, true)

# https://github.com/ButTaiwan/genyo-font
# make_font('GenYoMin2TW-B.ttf', 'ㄅ源樣注音明體', 'Bpmf GenYo Min', ver, true)
# make_font('GenYoMin2TW-EL.ttf', 'ㄅ源樣注音明體', 'Bpmf GenYo Min', ver, true)
# make_font('GenYoMin2TW-H.ttf', 'ㄅ源樣注音明體', 'Bpmf GenYo Min', ver, true)
# make_font('GenYoMin2TW-L.ttf', 'ㄅ源樣注音明體', 'Bpmf GenYo Min', ver, true)
# make_font('GenYoMin2TW-M.ttf', 'ㄅ源樣注音明體', 'Bpmf GenYo Min', ver, true)
# make_font('GenYoMin2TW-R.ttf', 'ㄅ源樣注音明體', 'Bpmf GenYo Min', ver, true)
# make_font('GenYoMin2TW-SB.ttf', 'ㄅ源樣注音明體', 'Bpmf GenYo Min', ver, true)

# make_font('GenWanMin2TW-R.ttf', 'ㄅ字嗨注音而已', 'Bpmf Zihi Only', ver, false, 'none')
# make_font('GenWanMin2TW-R.ttf', 'ㄅ字嗨注音加框', 'Bpmf Zihi Box', ver, false, 'box')