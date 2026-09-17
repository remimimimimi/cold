⎕IO←0

U32←{⍵+(2*32)×⍵<0} ⋄ U64←{(U32 ⍺[;⍵])+(2*32)×U32 ⍺[;⍵+1]}
S64←{(U32 ⍺[;⍵])+(2*32)×⍺[;⍵+1]} ⋄ SB←{0=≢⍵:⍬ ⋄ b←,⍉⊖(⍺⍴256)⊤⍵ ⋄ b-256×b≥128}
ZSTR←{80⎕DR(⍵⍳0)↑⍵} ⋄ ZSTRU←{⎕UCS(⍵⍳0)↑⍵}
ALIGN←{⍵+⍺|-⍵}

PS∆ARGS←{args←⍵
    ∨/'-h' '--help'∊args:'There should be help printed'⎕SIGNAL 200
    ∨/'-v' '--version'∊args:'There should be version printed'⎕SIGNAL 200

    o←⎕NS⍬
    o.out←'a.out' ⋄ o.(input path lib)←⊂⍬ ⋄ o.(static pie)←0
    o.(root hashstyle buildid dependencyfile)←⊂''
    o.interp←'/lib64/ld-linux-x86-64.so.2'

    m←args∊'-L' '-l' '-dynamic-linker' '-o' '-m' '-z' '-rpath' '-rpath-link'
    (m/args),←(m,0)/1⌽args,⊂'' ⋄ args←(~0,¯1↓m)/args

    o.(path lib)←'-L' '-l'{m←⍺∘≡¨(≢⍺)↑¨⍵ ⋄ (≢⍺)↓¨m/⍵}¨⊂args
    o.(interp out root hashstyle buildid dependencyfile){
        m←⍵∘≡¨(≢⍵)↑¨args ⋄ v←(≢⍵)↓¨m/args ⋄ ⊃⌽(⊂⍺),v
    }←'-dynamic-linker' '-o' '--sysroot=' '--hash-style=' '--build-id=' '--dependency-file='
    o.(static pie)←'-static' '-pie'∊args
    o.input←args/⍨'-'≠⊃¨args ⋄ o}

SCRIPT←{0=≢⍵:⍬ ⍬ ⋄ src←' '@{'/*'∘(≠\⍷∨¯1⌽∘⌽⍷∘⌽)⍵}⊢⍵
    atom←~src∊' ,;()',⎕UCS 9 10 13 ⋄ paren←src∊'()'
    begin←paren∨(0,¯1↓atom)<atom
    tokens←((+\begin)×(atom∨paren))⊆src
    first←⊃¨tokens ⋄ t←'('(-⍥(first∘=))')' ⋄ d←+\t ⋄ b←d-t
    (0>⌊/0,d)∨0≠⊢/0,d:'Unbalanced linker-script parentheses'⎕SIGNAL 200

    o←⍸t=1
    0=≢o:'Linker script contains no supported inputs'⎕SIGNAL 200
    0∨.≠(1,t)[o]:'Expected command before ('⎕SIGNAL 200
    cmd←1⎕C tokens[o-1]
    ~∧/cmd∊'INPUT' 'GROUP' 'AS_NEEDED' 'OUTPUT_FORMAT':'Unsupported linker-script command'⎕SIGNAL 200
    (cmd∊⊂'AS_NEEDED')∨.∧b[o]=0:'AS_NEEDED must be inside INPUT or GROUP'⎕SIGNAL 200
    (cmd∊'INPUT' 'GROUP' 'OUTPUT_FORMAT')∨.∧b[o]≠0:'Nested linker-script command'⎕SIGNAL 200

    command←1@(o-1)⊢t≢⍛⍴0
    command∨.<(t=0)∧b=0:'Unexpected text outside linker-script command'⎕SIGNAL 200
    top←o/⍨b[o]=0 ⋄ topcmd←cmd/⍨b[o]=0
    owner←+\1@top⊢t≢⍛⍴0

    rows←command<(t=0)∧(b>0)∧owner⊂⍛⌷0,topcmd∊'INPUT' 'GROUP'
    ~∨/rows:'Linker script contains no supported inputs'⎕SIGNAL 200
    (rows/tokens)(rows/b>1)}

LAYOUT←{group size align←⍵ ⋄ ⍺←0 ⍝ optional origin
    0=n←≢size:⍬ ⍬ ⍺
    p←⍋group ⋄ g←group[p] ⋄ s←size[p] ⋄ a←align[p]
    a[0,1+⍸2≠/g]←g{⌈/⍵}⌸a
    x←⍺+0,¯1↓+\s ⋄ M←⌈/a
    F←{⍺≥M:⍵ ⋄ m←a>⍺ ⋄ v←2|⌊(m/⍵)÷⍺ ⋄ (2×⍺)∇⍵+⍺×+\m\2≠/0,v}
    x←1 F x ⋄ z←x@p⊢n⍴0
    p z(⊃⌽x+s)}

OUT∆INIT←{size←⍺ ⋄ file←⍵
    t←file ⎕NCREATE 0
    _←size ⎕NRESIZE t
    _←⎕NUNTIE t
    83 size ⎕MAP file 'W'}

ELF∆IDENT∆EXP←127 69 76 70 2 1 1 0 0

LNK←{o←PS∆ARGS ⍵
    0=≢o.input: 'Expected at least one input file to link'⎕SIGNAL 200

    ⍝ Resolve paths and -l
    ext←o.static↓'.so' '.a'
    RESOLVE←{spec←⍵
        lib←{'-l'≡2↑⍵}¨spec
        ~∨/lib:spec
        0=≢o.path:'Cannot resolve libraries without -L'⎕SIGNAL 200

        ({name←2↓⍵
            candidates←,o.path∘.{⍺,'/lib',name,⍵}ext
            ~∨/exists←⎕NEXISTS¨candidates:('Cannot find ',⍵)⎕SIGNAL 200
            (exists⍳1)⊃candidates
        }¨lib/spec)@{lib}⊢spec}
    spec←o.input,('-l'∘,¨o.lib)
    paths fb kind thin optional←5↑{done maps kind thins doneopt spec specopt←⍵
        paths←RESOLVE spec ⋄ mapped←{83 ¯1⎕MAP⍵'R'}¨paths ⋄ head←↑64∘↑¨mapped

        elf←head[;⍳4]∧.=127 69 76 70
        etype←head[;16]+256×head[;17]
        elf∨.∧~etype∊1 3:'Unsupported ELF file type'⎕SIGNAL 200

        thick←head[;⍳8]∧.=33 60 97 114 99 104 62 10
        thin←head[;⍳8]∧.=33 60 116 104 105 110 62 10
        script←~binary←elf∨archive←thick∨thin

        parsed←{SCRIPT ⎕UCS 256|⍵}¨(0⍴⊂⍬),script/mapped
        members←(0⍴⊂'.'),⊃,/(0⊃¨parsed),⊂⍬ ⋄ asneeded←⊃,/(1⊃¨parsed),⊂⍬ ⋄ count←{≢⊃⍵}¨parsed

        dirs←count/{⊃1⎕NPARTS ⍵}¨script/paths
        candidate←dirs,¨members
        check←(0<≢¨members)∧('-'≠⊃¨members)∧'/'≠⊃¨members
        local←(⎕NEXISTS¨check/candidate)@{check}⊢members≢⍛⍴0
        members←(local/candidate)@{local}⊢members

        search←('-'≠⊃¨members)∧~⎕NEXISTS¨members
        members←{
            found←{
                candidates←o.path,¨⊂'/',⍵
                exists←⎕NEXISTS¨candidates
                ~∨/exists:('Cannot find linker-script input ',⍵)⎕SIGNAL 200
                (exists⍳1)⊃candidates
            }¨search/⍵
            found@{search}⊢⍵
        }⍣(∨/search)⊢members

        kept←binary∘/¨paths mapped(etype×elf)thin specopt
        ((done maps kind thins doneopt),¨kept),members((count/script/specopt)∨asneeded)
    }⍣{0=≢5⊃⍺}⊢⍬ ⍬ ⍬ ⍬ ⍬ spec(spec≢⍛⍴0)

    ⍝ Classify inputs
    vm←⍳≢fb ⋄ vx←fb≢⍛⍴0 ⋄ vz←≢¨fb
    rel←kind=1 ⋄ dyn←kind=3 ⋄ ar←kind=0
    direct←(rel/vm)(rel/vx)(rel/vz)
    shared←(dyn/vm)(dyn/vx)(dyn/vz)
    archives←(ar/vm)(ar/vx)(ar/vz)(ar/thin)

    ⍝ Decode a batch of ELF views
    ELF←{expected←⍺ ⋄ fb views←⍵ ⋄ (vm vx vz)←views
        head←↑{64↑(⊃fb[vm[⍵]])[vx[⍵]+⍳64⌊vz[⍵]]}¨⍳≢vm
        bad←~head[;⍳7]∧.=7↑ELF∆IDENT∆EXP
        bad∨←~head[;7]∊0 3 ⋄ bad∨←0≠head[;8]
        ∨/bad:'Unexpected ELF file identification'⎕SIGNAL 200

        words←(≢vm)16⍴323⎕DR,head ⋄ meta←U32 words[;4]
        etype←65536|meta ⋄ emachine←⌊meta÷65536
        expected∨.≠etype:'One of the input files is not an object file'⎕SIGNAL 200
        62∨.≠emachine:'One of the input files is not for AMD64'⎕SIGNAL 200

        eshoff←words U64 10 ⋄ eshentsize←⌊(U32 words[;14])÷65536 ⋄ eshnum←65536|U32 words[;15]
        64∨.≠eshentsize:'Unexpected section-header entry size'⎕SIGNAL 200
        ∨/(eshoff>vz)∨(64×eshnum)>vz-eshoff:'Section headers outside input view'⎕SIGNAL 200

        words←(+/eshnum)16⍴323⎕DR∊(vx+eshoff+⍳¨64×eshnum)(⊂⍛⌷)¨fb[vm]
        (hn ht hl hi)←{U32 words[;⍵]}¨0 1 10 11
        (hf hx hz ha he)←words∘U64¨2 6 8 12 14
        fh0←¯1↓+\0,eshnum ⋄ hm←eshnum/⍳≢eshnum
        files←fb views fh0 eshnum
        h←hn ht hf hm hx hz ha he hl hi
        files h}
    (files h)←1 ELF fb direct
    (sharedfiles sharedh)←{
        0=≢⊃shared:(fb shared ⍬ ⍬)(10⍴⊂⍬)
        3 ELF fb shared
    }⍬

    ⍝ Decode visible definitions exported by shared objects
    (ds soname needed)←{(hn ht hf hm hx hz ha he hl hi)←sharedh ⋄ (fb view fh0 fhn)←sharedfiles ⋄ (vm vx vz)←view
        0=≢vm:(7⍴⊂⍬)⍬(⍬ ⍬)

        symsh←⍸ht=11
        (≢vm)≠≢symsh:'Expected one dynamic symbol table per shared object'⎕SIGNAL 200
        symobj←hm[symsh] ⋄ symz←hz[symsh]
        (⍳≢vm)≢symobj:'Dynamic symbol tables are not one per shared object'⎕SIGNAL 200
        24∨.≠he[symsh]:'Unexpected dynamic symbol entry size'⎕SIGNAL 200
        0∨.≠24|symz:'Invalid dynamic symbol table size'⎕SIGNAL 200

        words←(+/count←symz÷24)6⍴323⎕DR∊(vx[symobj]+hx[symsh]+⍳¨symz)(⊂⍛⌷)¨fb[vm[symobj]]

        sn←U32 words[;0]
        info←256|words[;1] ⋄ other←256|⌊words[;1]÷256
        sb←⌊info÷16 ⋄ st←16|info ⋄ so←4|other
        shndx←65536|⌊words[;1]÷65536
        (sv sz)←words∘U64¨2 4

        own←count/⍳≢count ⋄ obj←symobj[own] ⋄ keep←(sb∊1 2 10)∧shndx≠0∧so∊0 3

        strsh←fh0[symobj]+hl[symsh]
        hm[strsh]∨.≠symobj:'Dynamic symbol table links outside its shared object'⎕SIGNAL 200
        strz←hz[strsh] ⋄ strstart←¯1↓+\0,strz
        strpool←∊(vx[symobj]+hx[strsh]+⍳¨strz)(⊂⍛⌷)¨fb[vm[symobj]]

        nameat←strstart[own]+sn
        sn∨.≥strz[own]:'Dynamic symbol name outside string table'⎕SIGNAL 200
        0∨.≠strpool[strstart+strz-1]:'Invalid dynamic string table'⎕SIGNAL 200
        zeros←⍸strpool=0
        namelen←zeros[(zeros⍸nameat)+0≠strpool[nameat]]-nameat
        name←{0=≢⍵:⍬ ⋄ {strpool[nameat[⍵]+⍳namelen[⍵]]}¨⍵}⍸keep

        ⍝ Shared object, name, binding, type, visibility, value, size
        exports←(obj[keep])name(sb/⍨keep)(st/⍨keep)(so/⍨keep)(sv/⍨keep)(sz/⍨keep)

        ⍝ Decode dynamic entries
        dynsh←⍸ht=6
        (≢vm)≠≢dynsh:'Expected one dynamic section per shared object'⎕SIGNAL 200
        dynobj←hm[dynsh] ⋄ dynz←hz[dynsh]
        (⍳≢vm)≢dynobj:'Dynamic sections are not one per shared object'⎕SIGNAL 200
        16∨.≠he[dynsh]:'Unexpected dynamic entry size'⎕SIGNAL 200
        0∨.≠16|dynz:'Invalid dynamic section size'⎕SIGNAL 200

        dwords←(+/dcount←dynz÷16)4⍴323⎕DR∊(vx[dynobj]+hx[dynsh]+⍳¨dynz)(⊂⍛⌷)¨fb[vm[dynobj]]
        tag←dwords U64 0 ⋄ value←dwords U64 2 ⋄ down←dcount/⍳≢dcount

        dstrsh←fh0[dynobj]+hl[dynsh]
        dstrsh∨.≠strsh:'Dynamic and dynamic-symbol tables use different string tables'⎕SIGNAL 200

        NAMES←{owner←⍺ ⋄ offset←⍵ ⋄ 0=≢owner:⍬
            offset∨.≥strz[owner]:'Dynamic string offset outside string table'⎕SIGNAL 200
            at←strstart[owner]+offset ⋄ len←zeros[(zeros⍸at)+0≠strpool[at]]-at
            {strpool[at[⍵]+⍳len[⍵]]}¨⍳≢at}

        sr←⍸tag=14
        (≢vm)≠≢sr:'Expected one SONAME per shared object'⎕SIGNAL 200
        sowner←dynobj[down[sr]]
        (⍳≢vm)≢sowner:'SONAME entries are not one per shared object'⎕SIGNAL 200
        soname←sowner NAMES value[sr]

        nr←⍸tag=1
        nowner←dynobj[down[nr]]
        needed←nowner(nowner NAMES value[nr])

        exports soname needed
    }⍬

    ⍝ Decode GNU archive symbol indexes
    archiveindex←{(am ax az at)←archives ⋄ (fb view fh0 fhn)←files
        0=≢am:⍬ ⍬ ⍬ ⍬ ⍬ ⍬
        ∨/az<68:'Archive is too small for its symbol index'⎕SIGNAL 200

        mh←↑{(⊃fb[am[⍵]])[ax[⍵]+8+⍳60]}¨⍳≢am
        47∨.≠mh[;0]:'Archive has no symbol index'⎕SIGNAL 200
        ∨/~mh[;1]∊32 47:'Invalid archive symbol-index member'⎕SIGNAL 200
        ∨/~mh[;58 59]∧.=96 10:'Invalid archive member header'⎕SIGNAL 200

        ⍝ Decimal member size occupies bytes 48-57
        digit←mh[;48+⍳10]
        size←{d←⍵/⍨⍵≠32
            ∨/~d∊48+⍳10:'Invalid archive member size'⎕SIGNAL 200
            10⊥d-48
        }¨↓digit
        data←ax+68
        ∨/size>az-68:'Archive symbol index outside archive view'⎕SIGNAL 200

        next←data+2 ALIGN size ⋄ limit←ax+az
        lh←↑{60↑(⊃fb[am[⍵]])[next[⍵]+⍳0⌈60⌊limit[⍵]-next[⍵]]}¨⍳≢am
        long←lh[;0 1]∧.=47 47
        z←{d←⍵/⍨⍵≠32
            ∨/~d∊48+⍳10:'Invalid archive long-name table size'⎕SIGNAL 200
            10⊥d-48
        }¨↓long⌿lh[;48+⍳10]
        longz←z@(⍸long)⊢(≢am)⍴0
        longx←next+60
        ∨/long∧longz>limit-longx:'Archive long-name table outside archive'⎕SIGNAL 200
        longx←¯1@{~long}⊢longx

        ⍝ The GNU/SysV index begins with big-endian u32 count.
        count←{256⊥(⊃fb[am[⍵]])[data[⍵]+⍳4]}¨⍳≢am
        ∨/size<4+4×count:'Invalid archive symbol index'⎕SIGNAL 200

        member←U32 323⎕DR,⌽(+/count)4⍴∊{(⊃fb[am[⍵]])[data[⍵]+4+⍳4×count[⍵]]}¨⍳≢am
        owner←count/⍳≢am ⋄ namex←data+4+4×count ⋄ namez←size-(4+4×count)
        pools←{(⊃fb[am[⍵]])[namex[⍵]+⍳namez[⍵]]}¨⍳≢am ⋄ pool←∊pools ⋄ poolstart←¯1↓+\0,namez
        zeros←∊{z←⍸0=⊃pools[⍵]
            count[⍵]>≢z:'Archive symbol-index count does not match its names'⎕SIGNAL 200
            poolstart[⍵]+count[⍵]↑z
        }¨⍳≢am
        first←≠owner ⋄ start←1+¯1,¯1↓zeros ⋄ start[⍸first]←poolstart[first/owner] ⋄ len←zeros-start
        ∨/(≢member)≠≢start:'Archive symbol-index count does not match its names'⎕SIGNAL 200

        ⍝ Names remain raw byte vectors.
        name←{pool[start[⍵]+⍳len[⍵]]}¨⍳≢start
        ⍝ archive mapping, member-header offset, symbol name, thin, long-name offset and size
        am[owner](ax[owner]+member)name(at[owner])(longx[owner])(longz[owner])
    }⍬

    ⍝ Decode ELF objects tables
    TABLES←{files h←⍵
        ⍝ Decode symbols
        (s symbase)←{(hn ht hf hm hx hz ha he hl hi)←h ⋄ (fb view fh0 fhn)←files ⋄ (vm vx vz)←view
            symsh←⍸ht=2 ⋄ symobj←hm[symsh] ⋄ symx←hx[symsh] ⋄ symz←hz[symsh]
            count←symz÷24
            ∨/24≠he[symsh]:'Unexpected symbol entry size'⎕SIGNAL 200
            ∨/0≠24|symz:'Invalid symbol table size'⎕SIGNAL 200

            words←(+/count)6⍴323⎕DR∊(vx[symobj]+symx+⍳¨symz)(⊂⍛⌷)¨fb[vm[symobj]]

            (info other shndx)←(256 256 65536){⍺|⌊words[;1]÷⍵}¨1 256 65536
            sb←⌊info÷16 ⋄ st←16|info ⋄ sn←U32 words[;0]
            (sv sz)←words∘U64¨2 4 ⋄ so←4|other

            reg←(0<shndx)∧shndx<65280
            abs←shndx=65521 ⋄ com←shndx=65522 ⋄ xnd←shndx=65535
            ∨/xnd:'Extended symbol section indices are not supported yet'⎕SIGNAL 200
            ∨/(shndx≥65280)∧~abs∨com∨xnd:'Unsupported reserved symbol section index'⎕SIGNAL 200

            start←¯1↓+\0,count ⋄ own←count/⍳≢count ⋄ obj←symobj[own]
            symbase←start@symsh⊢(≢ht)⍴¯1

            ⍝ Symbols string table
            ss←(≢sn)⍴¯1 ⋄ ss[⍸abs]←¯2 ⋄ ss[⍸com]←¯3
            ss[rows]←fh0[obj[rows]]+shndx[rows←⍸reg]
            strsh←fh0[symobj]+hl[symsh]
            ∨/hm[strsh]≠symobj:'Symbol table links outside its object'⎕SIGNAL 200
            strx←hx[strsh] ⋄ strz←hz[strsh] ⋄ strstart←¯1↓+\0,strz
            strpool←∊(vx[symobj]+strx+⍳¨strz)(⊂⍛⌷)¨fb[vm[symobj]]

            nameat←strstart[own]+sn
            ∨/0≠strpool[strstart+strz-1]:'Invalid symbol string table'⎕SIGNAL 200
            zeros←⍸strpool=0 ⋄ namelen←zeros[(zeros⍸nameat)+0≠strpool[nameat]]-nameat
            sn←{strpool[nameat[⍵]+⍳namelen[⍵]]}¨⍳≢sn

            s←sn sb st so ss sv sz
            s symbase
        }⍬

        ⍝ Decode RELA
        r←{(hn ht hf hm hx hz ha he hl hi)←h ⋄ (fb view fh0 fhn)←files ⋄ (vm vx vz)←view
            relash←⍸ht=4 ⋄ relaobj←hm[relash] ⋄ relax←hx[relash] ⋄ relaz←hz[relash]
            count←relaz÷24
            ∨/24≠he[relash]:'Unexpected RELA entry size'⎕SIGNAL 200
            ∨/0≠24|relaz:'Unexpected RELA section size'⎕SIGNAL 200

            words←(+/count)6⍴323⎕DR∊(vx[relaobj]+relax+⍳¨relaz)(⊂⍛⌷)¨fb[vm[relaobj]]

            rx←words U64 0 ⋄ (rt rawsym)←{U32 words[;⍵]}¨2 3 ⋄ ra←words S64 4
            own←count/⍳≢count ⋄ rh←(fh0[relaobj]+hi[relash])[own]

            symsh←fh0[relaobj]+hl[relash] ⋄ base←symbase[symsh]
            ∨/¯1=base:'RELA does not reference a symbol table'⎕SIGNAL 200
            rs←base[own]+rawsym

            rh rx rs rt ra
        }⍬
        s r symbase
    }
    (s r symbase)←TABLES files h

    COMDAT←{files h s symbase←⍵
        (hn ht hf hm hx hz ha he hl hi)←h ⋄(fb view fh0 fhn)←files ⋄ (vm vx vz)←view ⋄ (sn sb st so ss sv sz)←s
        keep←(≢ht)⍴1
        gsh←⍸ht=17 ⋄ gobj←hm[gsh] ⋄ goff←hx[gsh] ⋄ glen←hz[gsh]
        ∨/(glen<4)∨0≠4|glen:'Invalid SHT_GROUP size'⎕SIGNAL 200

        first←¯1↓+\0,1+count←¯1+glen÷4
        words←323⎕DR∊(vx[gobj]+goff+⍳¨glen)(⊂⍛⌷)¨fb[vm[gobj]]
        ∨/words[first]≠1:'Unsupported section group flags'⎕SIGNAL 200

        member←~1@first⊢(≢words)⍴0 ⋄mem←member/words ⋄ owner←count/⍳≢gsh
        ∨/~∧/(0<mem)∧mem<fhn[gobj[owner]]: 'Invalid section group member'⎕SIGNAL 200

        gsymsh←fh0[gobj]+hl[gsh]
        ∨/¯1=symbase[gsymsh]: 'SHT_GROUP does not reference a symbol table'⎕SIGNAL 200

        lose←~≠sn[symbase[gsymsh]+hi[gsh]]
        keep[lose/gsh]←0 ⋄ keep[(lose[owner])/mem+fh0[gobj[owner]]]←0

        ss←¯1@(rows/⍨~keep[ss[rows←⍸ss≥0]])⊢ss
        s←sn sb st so ss sv sz
        s keep
    }

    ⍝ Select archive members required by direct objects
    SELECT←{files s picked←⍵ ⋄ (fb view fh0 fhn)←files ⋄ (sn sb st so ss sv sz)←s ⋄ (am ax an at alx alz)←archiveindex
        0=≢am:(⍬ ⍬ ⍬)⍬ picked

        strong←sb∊1 10 ⋄ defined←strong∧ss≠¯1 ⋄ undefined←strong∧ss=¯1
        need←∪(undefined/sn)~defined/sn

        ⍝ Select the first archive-index entry for each required name
        rows←an⍳need ⋄ rows←rows/⍨rows<≢an
        0=≢rows:(⍬ ⍬ ⍬)⍬ picked

        ⍝ Several symbols can select the same archive member
        key←am[rows],¨ax[rows]
        first←≠key ⋄ rows←first/rows ⋄ key←first/key
        new←~key∊picked ⋄ rows←new/rows ⋄ key←new/key
        0=≢rows:(⍬ ⍬ ⍬)⍬ picked

        thin←at[rows] ⋄ lx←alx[rows] ⋄ lz←alz[rows]
        map←am[rows] ⋄ off←ax[rows] ⋄ limit←≢¨fb[map]
        ∨/(off>limit)∨60>limit-off:'Archive member header outside archive'⎕SIGNAL 200

        mh←↑{(⊃fb[map[⍵]])[off[⍵]+⍳60]}¨⍳≢rows
        ∨/~mh[;58 59]∧.=96 10:'Invalid archive member header'⎕SIGNAL 200

        digit←mh[;48+⍳10]
        size←{d←⍵/⍨⍵≠32
            ∨/~d∊48+⍳10:'Invalid archive member size'⎕SIGNAL 200
            10⊥d-48
        }¨↓digit
        data←off+60
        ∨/(~thin)∧size>limit-data:'Archive member data outside archive'⎕SIGNAL 200

        tr←⍸thin
        memberpaths←{i←⍵ ⋄ field←mh[i;⍳16] ⋄ field←field/⍨field≠32
            0=≢field:'Empty thin archive member name'⎕SIGNAL 200

            bytes←{
                47≠⊃field:{
                    47≠⊃¯1↑field:'Invalid thin archive member name'⎕SIGNAL 200
                    ¯1↓field}⍬

                digits←1↓field
                (0=≢digits)∨∨/~digits∊48+⍳10:'Invalid thin archive long-name reference'⎕SIGNAL 200
                ¯1=lx[i]:'Thin archive has no long-name table'⎕SIGNAL 200

                x←10⊥digits-48
                x≥lz[i]:'Thin archive long-name reference outside table'⎕SIGNAL 200
                pool←(⊃fb[map[i]])[lx[i]+x+⍳lz[i]-x]
                end←pool⍳10
                end=≢pool:'Unterminated thin archive member name'⎕SIGNAL 200

                name←end↑pool
                (0=≢name)∨47≠⊃¯1↑name:'Invalid thin archive long name'⎕SIGNAL 200
                ¯1↓name}⍬

            path←⎕UCS bytes
            47=⊃bytes:path
            (⊃1⎕NPARTS paths[map[i]]),path
        }¨tr

        newfb←{0=≢⍵:⍬ ⋄ {83 ¯1⎕MAP⍵'R'}¨⍵}memberpaths
        map[tr]←(≢fb)+⍳≢newfb ⋄ data[tr]←0 ⋄ size[tr]←≢¨newfb

        ⍝Selected ELF views: mapping, file offset, size
        (map data size)newfb(picked,key)
    }

    ⍝ Archive-member discovery step
    (files h s r symbase selected picked)←{(files h s r symbase selected picked)←⍵
        (selected newfb picked)←SELECT files s picked
        0=≢⊃selected:files h s r symbase selected picked

        (ofb ov ofh0 ofhn)←files ⋄ fb←ofb,newfb
        (nfiles nh)←1 ELF fb selected ⋄ (ns nr nb)←TABLES nfiles nh
        (ovm ovx ovz)←ov ⋄ (nfb nv nfh0 nfhn)←nfiles ⋄ (nvm nvx nvz)←nv
        vbase←≢ovm ⋄ hbase←≢⊃h ⋄ sbase←≢⊃s

        (nhn nht nhf nhm nhx nhz nha nhe nhl nhi)←nh ⋄ nhm+←vbase ⋄ nh←nhn nht nhf nhm nhx nhz nha nhe nhl nhi
        (nsn nsb nst nso nss nsv nsz)←ns ⋄ nss←hbase∘+@{⍵≥0}⊢nss ⋄ ns←nsn nsb nst nso nss nsv nsz
        (nrh nrx nrs nrt nra)←nr ⋄ nrh+←hbase ⋄ nrs+←sbase ⋄ nr←nrh nrx nrs nrt nra
        nb←sbase∘+@{⍵≥0}⊢nb
        view←(ovm,nvm)(ovx,nvx)(ovz,nvz) ⋄ files←fb view(ofh0,hbase+nfh0)(ofhn,nfhn)
        h←h,¨nh ⋄ s←s,¨ns ⋄ r←r,¨nr ⋄ symbase,←nb

        files h s r symbase selected picked
    }⍣{(_ _ _ _ _ selected _)←⍺ ⋄ 0=≢⊃selected}⊢files h s r symbase(⍬ ⍬ ⍬)⍬

    (s seckeep)←COMDAT files h s symbase

    ⍝ Symbol resolution
    (r ri imports common startsym)←{(s ds r)←⍵ ⋄ (rh rx rs rt ra)←r
        (sn sb st so ss sv sz)←s ⋄ (dobj dn db dt dvis dv dz)←ds

        reg←ss≥0 ⋄ abs←ss=¯2 ⋄ com←ss=¯3
        weak←sb=2 ⋄ strong←(sb=1)∨sb=10 ⋄ ext←strong∨weak
        defd←reg∨abs∨com
        names←∪sn ⋄ sid←names⍳sn
        gotdef←sn∊⊂83⎕DR'_GLOBAL_OFFSET_TABLE_'
        ∨/~≠(strong∧defd∧~com)/sid:'Multiple strong symbol definitions'⎕SIGNAL 200

        def←⍸ext∧defd ⋄ def←def[⍋com[def]+2×weak[def]] ⋄ def←(≠sid[def])/def

        zero←≢sn ⋄ byname←def@(sid[def])⊢(≢names)⍴zero

        ⍝ Resolve external symbol rows against objects, then DSOs.
        erow←⍸ext∧~defd ⋄ local←byname[sid[erow]] ⋄ drow←dn⍳sn[erow]
        dynamic←(local=zero)∧drow<≢dn ⋄ missing←(local=zero)∧~dynamic ⋄ required←gotdef[erow]⍱weak[erow]∧0=so[erow]
        ∨/missing∧required:'Undefined symbol'⎕SIGNAL 200

        ⍝ Deduplicate imports in first-occurence order.
        isym←dynamic/erow ⋄ idrow←dynamic/drow
        in←∪sn[isym] ⋄ ii←in⍳sn[isym]
        idrow←idrow[ii⍳⍳≢in]
        imports←(in⋄db[idrow]⋄dobj[idrow]⋄dt[idrow]⋄dz[idrow])

        ⍝ Map symbol rows and then relocations to imports.
        simport←ii@isym⊢sn≢⍛⍴¯1 ⋄ ri←simport[rs]

        ⍝ Redirect locally resolved relocation symbols.
        rdef←rs ⋄ refs←rdef[rows←⍸ext[rdef]∧~gotdef[rdef]]
        resolved←byname[sid[refs]] ⋄ imported←simport[refs]≥0
        rdef←zero@(imported/rows)⊢resolved@rows⊢rdef
        real←rdef≠zero
        ∨/st[real/rdef]=10:'GNU IFUNC relocation is not supported yet'⎕SIGNAL 200

        ⍝ Identify entry point
        start←names⍳⊂83⎕DR'_start'
        start=≢names:'Undefined symbol: _start'⎕SIGNAL 200
        startsym←byname[start]
        startsym=zero:'Undefined symbol: _start'⎕SIGNAL 200

        ⍝ Common symbols
        cdef←def/⍨com[def] ⋄ crow←⍸ext∧com
        cid←sid[cdef]⍳sid[crow]
        cid←(keep←cid<≢cdef)/cid ⋄ crow←keep/crow ⋄ ids←∪cid
        cz←(cid{⌈/⍵}⌸sz[crow])@ids⊢(≢cdef)⍴0
        ca←(cid{⌈/⍵}⌸sv[crow])@ids⊢(≢cdef)⍴1

        r←rh rx rdef rt ra ⋄ common←cdef cz ca
        r ri imports common startsym
    }s ds r

    ⍝ Dynamic relocation plan
    dplan←{(h r ri imports)←⍵ ⋄ (hn ht hf hm hx hz ha he hl hi)←h ⋄ (rh rx rs rt ra)←r ⋄ (in ib idso it iz)←imports
        backed←(ht≠8)∧2|⌊hf÷2 ⋄ live←seckeep[rh]∧backed[rh] ⋄ imported←ri≥0 ⋄ gottypes←9 41 42

        use←live∧imported
        ∨/use∧~rt∊1 4 19,gottypes:'Unsupported dynamic relocation type'⎕SIGNAL 200

        pltimport←∪ri/⍨use∧rt=4 ⋄ gotimport←∪ri/⍨use∧rt∊gottypes
        zero←≢⊃s
        localgotsym←∪rs/⍨live∧(~imported)∧(rs≠zero)∧rt∊gottypes
        gdimport←∪ri/⍨use∧rt=19 ⋄ hasld←live∨.∧rt=20

        symbolic←⍸use∧rt=1 ⋄ relative←⍸o.pie∧live∧(~imported)∧(rs≠zero)∧rt=1

        ip←(⍳≢pltimport)@pltimport⊢in≢⍛⍴¯1 ⋄ ig←(⍳≢gotimport)@gotimport⊢in≢⍛⍴¯1
        lg←(⍳≢localgotsym)@localgotsym⊢(≢⊃s)⍴¯1 ⋄ igt←(⍳≢gdimport)@gdimport⊢in≢⍛⍴¯1

        pltimport gotimport localgotsym gdimport hasld symbolic relative ip ig lg igt
    }h r ri imports

    ⍝ Dynamic symbols and strings
    dynamic←{(imports dplan)←⍵ ⋄ (in ib idso it iz)←imports ⋄ (sm sx sz)←shared
        (pltimport gotimport localgotsym gdimport hasld symbolic relative ip ig lg igt)←dplan

        used←(⍳≢sm)∊idso ⋄ dkeep←used∨~optional[sm] ⋄ neededname←dkeep/soname

        strings←in,neededname ⋄ x←1+¯1↓+\0,len←1+≢¨strings
        ix←in≢⍛↑x ⋄ nx←in≢⍛↓x ⋄ dynstr←0,∊{⍵,0}¨strings
        n←≢in ⋄ at←24+24×⍳n
        dynsym←(8SB iz)@(,at∘.+16+⍳8)⊢(it+16×ib)@(at+4)⊢(4SB ix)@(,at∘.+⍳4)⊢(24×1+n)⍴0

        dkeep nx dynstr dynsym
    }imports dplan

    ⍝ Lifecycle inputs
    life←{(s h)←⍵ ⋄ (sn sb st so ss sv sz)←s ⋄ (hn ht hf hm hx hz ha he hl hi)←h
        live←(ss≥0)∧seckeep[0⌈ss]

        ROW←{r←⍸live∧sn∊⊂83⎕DR⍵ ⋄ ⊃r,¯1}
        initrow←ROW'_init' ⋄ finirow←ROW'_fini'
        initsec←⍸seckeep∧ht=14 ⋄ finisec←⍸seckeep∧ht=15
        initrow finirow initsec finisec
    }s h

    ⍝ Generated dynamic sections
    dynparts←{(imports dplan dynamic)←⍵ ⋄ (in ib idso it iz)←imports ⋄ (dkeep nx dynstr dynsym)←dynamic
        (pltimport gotimport localgotsym gdimport hasld symbolic relative ip ig lg igt)←dplan
        (initrow finirow initsec finisec)←life
        nlife←(initrow≥0)+(finirow≥0)+2×(0<≢initsec)+0<≢finisec
        (nplt nglob ngd nlocal)←≢¨pltimport gotimport gdimport localgotsym ⋄ ntlsdesc←hasld+ngd

        nrela←nglob+(o.pie×nlocal)+(≢symbolic)+(≢relative)+ntlsdesc+ngd
        hasdynamic←∨/dkeep
        interp←83⎕DR o.interp,⎕UCS 0
        hash←4SB 1 ndynsym(×≢in),(2+⍳0⌈(≢in)-1)@(1+⍳0⌈(≢in)-1)⊢0⍴⍨ndynsym←1+≢in

        plt←0⍴⍨16×nplt ⋄ relaplt←0⍴⍨24×nplt ⋄ dynrela←0⍴⍨24×nrela
        got←0⍴⍨8×nplt+nglob+nlocal+2×ntlsdesc ⋄ dyntab←0⍴⍨16×12+nlife+(3××nrela)+≢nx

        hasdynamic interp plt hash dynsym dynstr relaplt dynrela got dyntab
    }imports dplan dynamic

    ⍝ Layout
    base←4194304×~o.pie
    (layout copies sections segments)←{(h s common startsym)←⍵
        (hn ht hf hm hx hz ha he hl hi)←h ⋄ (sn sb st so ss sv sz)←s ⋄ (cs cz ca)←common
        (fb view fh0 fhn)←files ⋄ (vm vx vz)←view
        (hasdynamic interp plt hash dynsym dynstr relaplt dynrela got dyntab)←dynparts
        gen←hasdynamic/interp plt hash dynsym dynstr relaplt dynrela got dyntab ⋄ gensize←≢¨gen
        gengroup←hasdynamic/1 0 1 1 1 1 1 2 2 ⋄ genalign←hasdynamic/1 16 8 8 1 8 8 8 8

        alloc←seckeep∧2|⌊hf÷2 ⋄ secs←⍸alloc ⋄ flags←hf[secs] ⋄ type←ht[secs]
        secz←hz[secs] ⋄ seca←1⌈ha[secs]

        write←2|flags ⋄ exec←2|⌊flags÷4
        ∨/write∧exec:'Writable executable sections are not supported'⎕SIGNAL 200
        ∨/~seca∊2*⍳63:'Unsupported section alignment'⎕SIGNAL 200

        nobits←type=8 ⋄ tls←1024≤2048|flags
        group←7@{nobits∧~tls}⊢6@{tls∧nobits}⊢5@{tls∧~nobits}⊢4@{type=15}⊢3@{type=14}⊢write+~exec
        group,←(cs≢⍛⍴7),gengroup ⋄ size←secz,cz,gensize ⋄ align←seca,ca,genalign

        ⍝ Segments
        ne←0<size ⋄ seg←(group=1)+2×group≥2 ⍝RX=0,R=1,RW=2
        class←0 1 2∩ne/seg ⋄ hastls←∨/group∊5 6 ⋄ segstart←{⊃⍸seg=⍵}¨class
        hdrsz←64+56×1+(≢class)+3×hasdynamic+hastls ⋄ lalign←4096∘⌈@segstart⊢align

        ⍝ Actual layouting
        (order rel memsz)←hdrsz LAYOUT group size lalign ⋄ nsec←≢secs
        secrel←nsec↑rel ⋄ rest←nsec↓rel
        comrel←cs≢⍛↑rest ⋄ genrel←cs≢⍛↓rest

        file←~nobits ⋄ filesec←file/secs
        foff←file/secrel ⋄ fsz←hz[filesec]

        src←hm[filesec]
        copies←(vm[src])(vx[src]+hx[filesec])fsz foff

        shoff←foff@filesec⊢(≢ht)⍴¯1
        shaddr←(base+secrel)@secs⊢(≢ht)⍴0
        filesz←⌈/hdrsz,(foff+fsz),genrel+gensize

        reg←ss≥0 ⋄ abs←ss=¯2
        symaddr←reg\(shaddr[reg/ss]+reg/sv) ⋄ symaddr[⍸abs]←abs/sv
        symaddr[cs]←base+comrel ⋄ symaddr[⍸sn∊⊂83⎕DR'_GLOBAL_OFFSET_TABLE_']←base+7⊃9↑genrel,9⍴0 ⋄ symaddr,←0

        ⍝ Segments continuation
        span←{
            m←seg=⍵ ⋄ x←⌊/m/rel
            fz←(⌈/x,(m∧~group∊6 7)/(rel+size))-x
            mz←(⌈/m/(rel+size))-x
            x fz mz
        }¨class

        px←0,0⊃¨span ⋄ pfz←hdrsz,1⊃¨span ⋄ pmz←hdrsz,2⊃¨span ⋄ pv←base+px
        pt←(≢px)⍴1 ⋄ pf←4,5 4 6[class] ⋄ pa←(≢px)⍴4096

        ⍝ Output sections
        regular←order/⍨order<nsec+≢cs
        g←group[regular] ⋄ x←rel[regular] ⋄ zsize←size[regular] ⋄ zalign←align[regular]
        first←≠g ⋄ last←1⌽first ⋄ groups←first/g

        secoff←first/x ⋄ secsz←secoff-⍨last/x+zsize ⋄ secalign←g{⌈/⍵}⌸zalign ⋄ secaddr←base+secoff
        sectype←(1 1 1 14 15 1 8 8)[groups] ⋄ secflags←(6 2 3 3 3 1027 1027 3)[groups]
        seclink←groups≢⍛⍴0 ⋄ secinfo←groups≢⍛⍴0 ⋄ secentsize←(0 0 0 8 8 0 0 0)[groups]
        secnames←('.text' '.rodata' '.data' '.init_array' '.fini_array' '.tdata' '.tbss' '.bss')[groups]

        ⍝Generated dynamic sections
        gennames←hasdynamic/'.interp' '.plt' '.hash' '.dynsym' '.dynstr' '.rela.plt' '.rela.dyn' '.got' '.dynamic'
        genndx←1+(≢groups)+⍳≢gennames

        gentype←hasdynamic/1 1 5 11 3 4 4 1 6 ⋄ genflags←hasdynamic/2 6 2 2 2 2 2 3 3
        genentsize←hasdynamic/0 16 4 24 0 24 24 8 16 ⋄ gotndx←8+≢groups ⋄ geninfo←hasdynamic/0 0 0 1 0 gotndx 0 0 0
        dsndx←4+≢groups ⋄ dstrndx←5+≢groups
        genlink←hasdynamic/0 0 dsndx dstrndx 0 dsndx dsndx 0 dstrndx

        secoff,←genrel ⋄ secaddr,←base+genrel ⋄ secsz,←gensize ⋄ secalign,←genalign ⋄ sectype,←gentype
        secflags,←genflags ⋄ seclink,←genlink ⋄ secinfo,←geninfo ⋄ secentsize,←genentsize ⋄ secnames,←gennames

        extra←3 4 5 6∩groups ⋄ extranames←('.init_array' '.fini_array' '.tdata' '.tbss')[extra-3]
        nameoff←1+¯1↓+\0,1+≢¨names←'.text' '.rodata' '.data' '.bss',extranames,gennames,⊂'.shstrtab' ⋄ shstr←z,∊names,¨z←⎕UCS 0
        secname←nameoff[(0 1 2 0 0 0 0 3)[groups]] ⋄ secname[rows]←nameoff[4+extra⍳groups[rows←⍸groups∊3 4 5 6]]
        secname,←nameoff[4+(≢extra)+hasdynamic/⍳9] ⋄ shstrname←⊃⌽nameoff

        shstroff←filesz ⋄ shtoff←8ALIGN shstroff+≢shstr ⋄ shnum←2+≢secnames ⋄ shstrndx←1+≢secnames

        outfilesz←shtoff+64×shnum ⋄ entry←symaddr[startsym]
        dynlayout←genrel(base+genrel)
        layout←shoff shaddr symaddr filesz memsz entry dynlayout
        osec←secname sectype secflags secaddr secoff secsz secalign seclink secinfo secentsize
        special←{~hasdynamic:8⍴⊂⍬
            x←genrel[0 8] ⋄ z←gensize[0 8]
            (3 2)(4 6)x(base+x)(base+x)z z(1 8)}⍬
        segments←(pt pf px pv pv pfz pmz pa),¨special
        tlsseg←{~hastls:8⍴⊂⍬
            m←group∊5 6 ⋄ fz←(⌈/x,(group=5)/rel+size)-x←⌊/m/rel
            mz←(⌈/m/rel+size)-x ⋄ a←⌈/m/align
            (,7)(,4)(,x)(,base+x)(,base+x)(,fz)(,mz)(,a)
        }⍬
        segments←segments,¨tlsseg
        phdr←{~hasdynamic:8⍴⊂⍬
            z←56×1+≢⊃segments
            (,6)(,4)(,64)(,base+64)(,base+64)(,z)(,z)(,8)}⍬
        segments←phdr,¨segments
        sections←shnum shstr shstrname shstroff shtoff shstrndx outfilesz osec
        layout copies sections segments
    }h s common startsym
    out←{(shnum shstr shstrname shstroff shtoff shstrndx outfilesz osec)←sections
        outfilesz OUT∆INIT o.out}⍬

    ⍝ Copy sections
    _←{(fb view fh0 fhn)←files ⋄ (fm fx fz ox)←copies
        chunksz←2*20
        _←{row←⍵ ⋄ n←fz[row]
            pos←chunksz×⍳⌈n÷chunksz ⋄ obj←⊃fb[fm[row]]
            _←{p←⍵ ⋄ k←chunksz⌊n-p ⋄ i←⍳k
                out[ox[row]+p+i]←obj[fx[row]+p+i]
            ⍬}¨pos
        ⍬}¨⍳≢fz
    ⍬}⍬

    ⍝ Write dynamic sections
    _←{(hasdynamic interp plt hash dynsym dynstr relaplt dynrela got dyntab)←dynparts
        ~hasdynamic:⍬
        (lx la ls lfz lmz le ld)←layout ⋄ (dx da)←ld ⋄ (dkeep nx dynstr dynsym)←dynamic
        (pltimport gotimport localgotsym gdimport hasld symbolic relative ip ig lg igt)←dplan
        (rh rx rs rt ra)←r ⋄ (hn ht hf hm hx hz ha he hl hi)←h ⋄ (initrow finirow initsec finisec)←life

        parts←interp hash dynsym dynstr
        rows←0 2 3 4
        _←rows{p←⍺ ⋄ r←⍵
            out[dx[p]+⍳≢⊃parts[r]]←⊃parts[r]
        ⍬}¨⍳≢rows

        nplt←≢pltimport ⋄ nglob←≢gotimport ⋄ nlocal←≢localgotsym ⋄ ngd←≢gdimport ⋄ ntlsdesc←hasld+ngd
        pltaddr←da[1]+16×⍳nplt ⋄ gotaddr←da[7]+8×⍳nplt+nglob+nlocal
        pltgotaddr←gotaddr[ip[pltimport]] ⋄ globaddr←gotaddr[nplt+ig[gotimport]] ⋄ localaddr←gotaddr[nplt+nglob+⍳nlocal]
        tlsdescaddr←da[7]+8×(nplt+nglob+nlocal)+2×⍳ntlsdesc ⋄ tlsldaddr←hasld×⊃tlsdescaddr,0 ⋄ tlsgdaddr←hasld↓tlsdescaddr

        ⍝ Construct TLS dynamic relocations
        tlsdynoffset←tlsdescaddr,tlsgdaddr+8 ⋄ tlsdynsym←(hasld/0),1+gdimport
        tlsdyninfo←16+(2*32)×tlsdynsym ⋄ tlsdyninfo,←17+(2*32)×1+gdimport ⋄ tlsdynadd←tlsdynoffset≢⍛⍴0

        ⍝ PLT entries are jmp *disp32(%rip) followed by padding.
        at←16×⍳nplt
        plt← (4SB pltgotaddr-pltaddr+6)@(,at∘.+2+⍳4)⊢37@(at+1)⊢¯1@at⊢¯112⍴⍨16×nplt

        RELA←{(off info add)←⍵ ⋄ at←24×⍳≢off
            (8SB add)@(,at∘.+16+⍳8)⊢(8SB info)@(,at∘.+8+⍳8)⊢(8SB off)@(,at∘.+⍳8)⊢0⍴⍨24×≢off}

        info←7+(2*32)×1+pltimport
        relaplt←RELA (⊂pltgotaddr),(⊂info),⊂nplt⍴0
        globinfo←6+(2*32)×1+gotimport ⋄ symbolinfo←1+(2*32)×1+ri[symbolic]

        symboloff←la[rh[symbolic]]+rx[symbolic] ⋄ relativeoff←la[rh[relative]]+rx[relative]

        off←tlsdynoffset,globaddr,(o.pie/localaddr),symboloff,relativeoff
        info←tlsdyninfo,globinfo,(8⍴⍨o.pie×nlocal),symbolinfo,relative≢⍛⍴8
        add←tlsdynadd,(nglob⍴0),(o.pie/ls[localgotsym]),ra[symbolic],ls[rs[relative]]+ra[relative]
        dynrela←RELA(⊂off),(⊂info),⊂add

        localvalue←ls[localgotsym]×~o.pie
        got←(0⍴⍨8×nplt+nglob),(8 SB localvalue),0⍴⍨16×ntlsdesc

        out[dx[1]+⍳≢plt]←plt ⋄ out[dx[5]+⍳≢relaplt]←relaplt
        out[dx[6]+⍳≢dynrela]←dynrela ⋄ out[dx[7]+⍳≢got]←got

        RANGE←{0=≢⍵:0 0 ⋄ start((⌊/x+hz[⍵])-start←⌈/x←la[⍵])}
        initarray←RANGE initsec ⋄ finiarray←RANGE finisec
        hasinit←initrow≥0 ⋄ hasfini←finirow≥0 ⋄ hasinitarray←0<≢initsec ⋄ hasfiniarray←0<≢finisec
        lifetags←(hasinit/12),(hasfini/13),(hasinitarray/25 27),hasfiniarray/26 28
        lifevalues←(hasinit/ls[0⌈initrow]),(hasfini/ls[0⌈finirow]),(hasinitarray/initarray),hasfiniarray/finiarray

        hasrela←0<≢dynrela
        tags←(nx≢⍛⍴1),4 5 6 10 11 3 2 20 23,(hasrela/7 8 9),lifetags,30 1879048187 0
        values←nx,da[2 4 3],(≢dynstr),24,da[7],(≢relaplt),7,da[5],(hasrela/da[6](≢dynrela)24),lifevalues,8 1 0

        at←16×⍳≢tags
        dyntab[,at∘.+⍳8]←8SB tags ⋄ dyntab[,at∘.+8+⍳8]←8SB values
        out[dx[8]+⍳≢dyntab]←dyntab
    ⍬}⍬

    ⍝ Apply relocations
    _←{(hn ht hf hm hx hz ha he hl hi)←h ⋄ (rh rx rs rt ra)←r ⋄ (lx la ls lfz lmz le ld)←layout
        (dx da)←ld ⋄ da←9↑da,9⍴0
        (pltimport gotimport localgotsym gdimport hasld symbolic relative ip ig lg igt)←dplan
        (hasdynamic interp plt hash dynsym dynstr relaplt dynrela got dyntab)←dynparts

        rr←⍸0≤lx[rh] ⋄ type←rt[rr] ⋄ gottypes←9 41 42
        ∨/~type∊1 2 4 9 19 20 21 41 42:'Unsupported relocation type'⎕SIGNAL 200

        pc32←type∊2 4 9 19 20 41 42
        width←8 4[type≠1] ⋄ target←rh[rr] ⋄ offset←rx[rr] ⋄ targetz←hz[target]
        ∨/(offset>targetz)∨width>targetz-offset:'Relocation target outside section'⎕SIGNAL 200

        tlssec←⍸(0≤lx)∧1024≤2048|hf ⋄ tlsbase←{0=≢⍵:0 ⋄ ⌊/la[⍵]}tlssec
        (nplt nglob nlocal ngd)←≢¨pltimport gotimport localgotsym gdimport ⋄ ntlsdesc←hasld+ngd
        tlsdescaddr←da[7]+8×(nplt+nglob+nlocal)+2×⍳ntlsdesc ⋄ tlsldaddr←hasld×⊃tlsdescaddr,0 ⋄ tlsgdaddr←hasld↓tlsdescaddr


        where←lx[target]+offset ⋄ S←ls[rs[rr]] ⋄ A←ra[rr] ⋄ P←la[target]+offset
        import←ri[rr] ⋄ imported←import≥0
        pltref←⍸imported∧type=4 ⋄ gotref←⍸imported∧type∊gottypes ⋄ localgotref←⍸(~imported)∧type∊gottypes
        nplt←≢pltimport ⋄ nglob←≢gotimport
        tlsldref←⍸type=20 ⋄ tlsgdref←⍸type=19 ⋄ dtpoffref←⍸type=21
        S[pltref]←da[1]+16×ip[import[pltref]]
        S[gotref]←da[7]+8×nplt+ig[import[gotref]]
        S[localgotref]←da[7]+8×nplt+nglob+lg[rs[rr[localgotref]]]
        S[tlsldref]←tlsldaddr ⋄ S[tlsgdref]←tlsgdaddr[igt[import[tlsgdref]]] ⋄ S[dtpoffref]←ls[rs[rr[dtpoffref]]]-tlsbase
        value←S+A-P×pc32
        ∨/(width=4)∧(value<-2*31)∨value≥2*31:'Relocation value overflow'⎕SIGNAL 200

        batchbytes←2*20 ⍝ avoid large allocation for temporary arrays.
        _←{w←⍵
            rows←⍸width=w ⋄ count←≢rows ⋄ span←⌈batchbytes÷1⌈w
            _←{first←⍵×span ⋄ sel←rows[first+⍳span⌊count-first]
                bytes←⊖(w⍴256)⊤value[sel]
                out[(⍳w)∘.+where[sel]]←bytes-256×bytes≥128
            ⍬}¨⍳⌈count÷span
        ⍬}¨∪width
    ⍬}⍬

    (shnum shstr shstrname shstroff shtoff shstrndx outfilesz osec)←sections
    secname sectype secflags secaddr secoff secsz secalign seclink secinfo secentsize←osec

    ⍝ Construct headers
    header←{(lx la ls lfz lmz le ld)←layout ⋄ (pt pf px pv pp pfz pmz pa)←segments
        ident←ELF∆IDENT∆EXP,7⍴0
        ehdr←,ident
        ehdr,←2 SB(2+o.pie)62
        ehdr,←4 SB 1
        ehdr,←8 SB le 64 shtoff
        ehdr,←4 SB 0
        ehdr,←2 SB 64 56(≢pt)64 shnum shstrndx
        phdr←∊,/4 4 8 8 8 8 8 8{⍺SB⍤0⊢⍵}¨segments
        ehdr,phdr
    }⍬
    out[⍳≢header]←header

    ⍝ Write .shstrtab
    out[shstroff+⍳≢shstr]←83⎕DR shstr

    ⍝ Construct sections at the end
    sht←{
        sh_name      ←(4 SB 0)⍪(4SB⍤0⊢secname)   ⍪(4 SB shstrname)
        sh_type      ←(4 SB 0)⍪(4SB⍤0⊢sectype)   ⍪(4 SB 3)
        sh_flags     ←(8 SB 0)⍪(8SB⍤0⊢secflags)  ⍪(8 SB 0)
        sh_addr      ←(8 SB 0)⍪(8SB⍤0⊢secaddr)   ⍪(8 SB 0)
        sh_offset    ←(8 SB 0)⍪(8SB⍤0⊢secoff)    ⍪(8 SB shstroff)
        sh_size      ←(8 SB 0)⍪(8SB⍤0⊢secsz)     ⍪(8 SB ≢shstr)
        sh_link      ←(4 SB 0)⍪(4SB⍤0⊢seclink)   ⍪(4 SB 0)
        sh_info      ←(4 SB 0)⍪(4SB⍤0⊢secinfo)   ⍪(4 SB 0)
        sh_addralign ←(8 SB 0)⍪(8SB⍤0⊢secalign)  ⍪(8 SB 1)
        sh_entsize   ←(8 SB 0)⍪(8SB⍤0⊢secentsize)⍪(8 SB 0)
        ∊,/sh_name sh_type sh_flags sh_addr sh_offset sh_size sh_link sh_info sh_addralign sh_entsize
    }⍬
    out[shtoff+⍳≢sht]←sht

    ⍝ Set expected file permissions
    chmod←⎕SHELL 'chmod' '+x' '--' o.out
    0≠2⊃chmod:('Cannot change output file to +x: ',o.out)⎕SIGNAL 200

    ⍝BREAK
    ⍬}
