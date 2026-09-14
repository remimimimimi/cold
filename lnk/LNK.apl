⎕IO←0

U32←{⍵+(2*32)×⍵<0} ⋄ U64←{(U32 ⍺[;⍵])+(2*32)×U32 ⍺[;⍵+1]}
S64←{(U32 ⍺[;⍵])+(2*32)×⍺[;⍵+1]} ⋄ SB←{b←,⍉⊖(⍺⍴256)⊤⍵ ⋄ b-256×b≥128}
ZSTR←{80⎕DR(⍵⍳0)↑⍵} ⋄ ZSTRU←{⎕UCS(⍵⍳0)↑⍵}
ALIGN←{⍵+⍺|-⍵}

PS∆ARGS←{args←⍵
    ∨/'-h' '--help'∊args:'There should be help printed'⎕SIGNAL 200
    ∨/'-v' '--version'∊args:'There should be version printed'⎕SIGNAL 200

    o←⎕NS⍬
    o.out←'a.out' ⋄ o.(input path lib)←⊂⍬ ⋄ o.(static pie)←0
    o.(root interp hashstyle buildid dependencyfile)←5⍴''

    m←args∊'-L' '-l' '-dynamic-linker' '-o'
    (m/args),←(m,0)/1⌽args,⊂'' ⋄ args←(~0,¯1↓m)/args

    o.(path lib)←'-L' '-l'{m←⍺∘≡¨(≢⍺)↑¨⍵ ⋄ (≢⍺)↓¨m/⍵}¨⊂args
    o.(interp out root hashstyle buildid dependencyfile){
        m←⍵∘≡¨(≢⍵)↑¨args ⋄ v←(≢⍵)↓¨m/args ⋄ ⊃⌽(⊂⍺),v
    }←'-dynamic-linker' '-o' '--sysroot=' '--hash-style=' '--build-id=' '--dependency-file='
    o.(static pie)←'-static' '-pie'∊args
    o.input←args/⍨'-'≠⊃¨args ⋄ o}

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

    ⍝ Map and classify inputs
    (paths fb direct archives)←{paths←∪o.input ⋄ fb←{83 ¯1⎕MAP⍵'R'}¨paths
        ⍝ view mapping, offset, size
        vm←⍳≢fb ⋄ vx←fb≢⍛⍴0 ⋄ vz←≢¨fb

        head←↑{64↑(⊃fb[vm[⍵]])[vx[⍵]+⍳64⌊vz[⍵]]}¨⍳≢vm
        elf←head[;⍳4]∧.=127 69 76 70
        thick←head[;⍳8]∧.=33 60 97 114 99 104 62 10
        thin←head[;⍳8]∧.=33 60 116 104 105 110 62 10
        ar←thick∨thin
        ∨/~elf∨ar:'Unsupported input file format'⎕SIGNAL 200

        direct←(elf/vm)(elf/vx)(elf/vz)
        archives←(ar/vm)(ar/vx)(ar/vz)(ar/thin)

        paths fb direct archives
    }⍬

    ⍝ Decode a batch of ELF views
    ELF←{fb views←⍵ ⋄ (vm vx vz)←views
        head←↑{64↑(⊃fb[vm[⍵]])[vx[⍵]+⍳64⌊vz[⍵]]}¨⍳≢vm
        bad←~head[;⍳7]∧.=7↑ELF∆IDENT∆EXP
        bad∨←~head[;7]∊0 3 ⋄ bad∨←0≠head[;8]
        ∨/bad:'Unexpected ELF file identification'⎕SIGNAL 200

        words←(≢vm)16⍴323⎕DR,head ⋄ meta←U32 words[;4]
        etype←65536|meta ⋄ emachine←⌊meta÷65536
        1∨.≠etype:'One of the input files is not an object file'⎕SIGNAL 200
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
    (files h)←ELF fb direct

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
    SELECT←{s picked←⍵ ⋄ (fb view fh0 fhn)←files ⋄ (sn sb st so ss sv sz)←s ⋄ (am ax an at alx alz)←archiveindex
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
    STEP←{(files h s r symbase selected picked)←⍵ ⋄ (selected newfb picked)←SELECT s picked
        0=≢⊃selected:files h s r symbase selected picked

        (ofb ov ofh0 ofhn)←files ⋄ fb←ofb,newfb
        (nfiles nh)←ELF fb selected ⋄ (ns nr nb)←TABLES nfiles nh
        (ovm ovx ovz)←ov ⋄ (nfb nv nfh0 nfhn)←nfiles ⋄ (nvm nvx nvz)←nv
        vbase←≢ovm ⋄ hbase←≢⊃h ⋄ sbase←≢⊃s

        (nhn nht nhf nhm nhx nhz nha nhe nhl nhi)←nh ⋄ nhm+←vbase ⋄ nh←nhn nht nhf nhm nhx nhz nha nhe nhl nhi
        (nsn nsb nst nso nss nsv nsz)←ns ⋄ nss←hbase∘+@{⍵≥0}⊢nss ⋄ ns←nsn nsb nst nso nss nsv nsz
        (nrh nrx nrs nrt nra)←nr ⋄ nrh+←hbase ⋄ nrs+←sbase ⋄ nr←nrh nrx nrs nrt nra
        nb←sbase∘+@{⍵≥0}⊢nb
        view←(ovm,nvm)(ovx,nvx)(ovz,nvz) ⋄ files←fb view(ofh0,hbase+nfh0)(ofhn,nfhn)
        h←h,¨nh ⋄ s←s,¨ns ⋄ r←r,¨nr ⋄ symbase,←nb

        files h s r symbase selected picked
    }
    DONE←{(files h s r symbase selected picked)←⍺ ⋄ 0=≢⊃selected}
    state←STEP⍣DONE⊢files h s r symbase(⍬ ⍬ ⍬)⍬
    (files h s r symbase selected picked)←state

    (s seckeep)←COMDAT files h s symbase

    ⍝ Symbol resolution
    (r common startsym)←{(s r)←⍵ ⋄ (sn sb st so ss sv sz)←s ⋄ (rh rx rs rt ra)←r
        reg←ss≥0 ⋄ abs←ss=¯2 ⋄ com←ss=¯3
        weak←sb=2 ⋄ strong←(sb=1)∨sb=10 ⋄ ext←strong∨weak
        defd←reg∨abs∨com
        names←∪sn ⋄ sid←names⍳sn
        ∨/~≠(strong∧defd∧~com)/sid:'Multiple strong symbol definitions'⎕SIGNAL 200

        def←⍸ext∧defd ⋄ def←def[⍋com[def]+2×weak[def]] ⋄ def←(≠sid[def])/def

        zero←≢sn ⋄ byname←def@(sid[def])⊢(≢names)⍴zero

        rdef←rs ⋄ rows←⍸ext[rdef] ⋄ refs←rdef[rows] ⋄ resolved←byname[sid[refs]]
        missing←resolved=zero ⋄ required←(~weak[refs])∨0≠so[refs]
        ∨/missing∧required:'Undefined symbol'⎕SIGNAL 200

        rdef[rows]←resolved ⋄ real←rdef≠zero
        ∨/(usedtype←st[real/rdef])=6:'TLS symbol relocation is not supported yet'⎕SIGNAL 200
        ∨/usedtype=10:'GNU IFUNC relocation is not supported yet'⎕SIGNAL 200

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
        r common startsym
    }s r

    ⍝ Layout
    base←4194304
    (layout copies sections segments)←{(h s common startsym)←⍵
        (hn ht hf hm hx hz ha he hl hi)←h ⋄ (sn sb st so ss sv sz)←s ⋄ (cs cz ca)←common
        (fb view fh0 fhn)←files ⋄ (vm vx vz)←view
        alloc←seckeep∧2|⌊hf÷2 ⋄ secs←⍸alloc ⋄ flags←hf[secs] ⋄ type←ht[secs]
        secz←hz[secs] ⋄ seca←1⌈ha[secs]

        write←2|flags ⋄ exec←2|⌊flags÷4
        ∨/write∧exec:'Writable executable sections are not supported'⎕SIGNAL 200
        ∨/~seca∊2*⍳63:'Unsupported section alignment'⎕SIGNAL 200

        nobits←type=8 ⋄ group←((~exec)+write)+3×nobits ⋄ nsec←≢secs
        group,←(≢cs)⍴5 ⋄ size←secz,cz ⋄ align←seca,ca
        ∨/group∊3 4:'Unsupported NOBITS output-section flags'⎕SIGNAL 200

        ⍝ Segments
        ne←0<size ⋄ seg←(group=1)+2×group∊2 5 ⍝RX=0,R=1,RW=2
        class←0 1 2∩ne/seg ⋄ segstart←{⊃⍸seg=⍵}¨class
        hdrsz←64+56×1+≢class ⋄ lalign←4096∘⌈@segstart⊢align

        ⍝ Actual layouting
        (order rel memsz)←hdrsz LAYOUT group size lalign
        secrel←nsec↑rel ⋄ comrel←nsec↓rel

        file←~nobits ⋄ filesec←file/secs
        foff←file/secrel ⋄ fsz←hz[filesec]

        src←hm[filesec]
        copies←(vm[src])(vx[src]+hx[filesec])fsz foff

        shoff←foff@filesec⊢(≢ht)⍴¯1
        shaddr←(base+secrel)@secs⊢(≢ht)⍴0
        filesz←⌈/hdrsz,foff+fsz

        reg←ss≥0 ⋄ abs←ss=¯2
        symaddr←reg\(shaddr[reg/ss]+reg/sv) ⋄ symaddr[⍸abs]←abs/sv
        symaddr[cs]←base+comrel ⋄ symaddr,←0

        ⍝ Segments continuation
        span←{
            m←seg=⍵ ⋄ x←⌊/m/rel
            fz←(⌈/x,(m∧group≠5)/(rel+size))-x
            mz←(⌈/m/(rel+size))-x
            x fz mz
        }¨class

        px←0,0⊃¨span ⋄ pfz←hdrsz,1⊃¨span ⋄ pmz←hdrsz,2⊃¨span ⋄ pv←base+px
        pt←(≢px)⍴1 ⋄ pf←4,5 4 6[class] ⋄ pa←(≢px)⍴4096

        ⍝ Output sections
        g←group[order] ⋄ x←rel[order]
        first←≠g ⋄ last←1⌽first

        groups←first/g
        secoff←first/x ⋄ secsz←(last/(x+size[order]))-secoff
        secalign←g{⌈/⍵}⌸align[order] ⋄ secaddr←base+secoff

        sectype←(1 1 1 0 0 8)[groups] ⋄ secflags←(6 2 3 0 0 3)[groups]

        shstr←z,'.text',z,'.rodata',z,'.data',z,'.bss',z,'.shstrtab',z←⎕UCS 0
        nameoff←⍸¯1⌽z=shstr ⋄ secname←nameoff[(1 2 3 0 0 4)[groups]] ⋄ shstrname←nameoff[5]

        shstroff←filesz ⋄ shtoff←8 ALIGN shstroff+≢shstr
        shnum←2+≢groups ⋄ shstrndx←1+≢groups
        outfilesz←shtoff+64×shnum

        entry←symaddr[startsym]
        layout←shoff shaddr symaddr filesz memsz entry
        osec←secname sectype secflags secaddr secoff secsz secalign
        segments←pt pf px pv pv pfz pmz pa
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

    ⍝ Apply static relocations
    _←{(hn ht hf hm hx hz ha he hl hi)←h ⋄ (rh rx rs rt ra)←r ⋄ (lx la ls lfz lmz le)←layout
        rr←⍸0≤lx[rh] ⋄ type←rt[rr]
        ∨/~type∊1 2 4:'Unsupported relocation type'⎕SIGNAL 200
        pc32←type∊2 4
        width←8 4[pc32] ⋄ target←rh[rr] ⋄ offset←rx[rr] ⋄ targetz←hz[target]
        ∨/(offset>targetz)∨width>targetz-offset:'Relocation target outside section'⎕SIGNAL 200
        where←lx[target]+offset ⋄ S←ls[rs[rr]] ⋄ A←ra[rr] ⋄ P←la[target]+offset
        value←S+A-P×pc32
        ∨/pc32∧((value<¯1×2*31)∨value>¯1+2*31):'Relocation value overflow'⎕SIGNAL 200

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
    secname sectype secflags secaddr secoff secsz secalign←osec

    ⍝ Construct headers
    header←{(lx la ls lfz lmz le)←layout ⋄ (pt pf px pv pp pfz pmz pa)←segments
        ident←ELF∆IDENT∆EXP,7⍴0
        ehdr←,ident
        ehdr,←2 SB 2 62
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
        sh_name      ←(4 SB 0)⍪(4SB⍤0⊢secname) ⍪(4 SB shstrname)
        sh_type      ←(4 SB 0)⍪(4SB⍤0⊢sectype) ⍪(4 SB 3)
        sh_flags     ←(8 SB 0)⍪(8SB⍤0⊢secflags)⍪(8 SB 0)
        sh_addr      ←(8 SB 0)⍪(8SB⍤0⊢secaddr) ⍪(8 SB 0)
        sh_offset    ←(8 SB 0)⍪(8SB⍤0⊢secoff)  ⍪(8 SB shstroff)
        sh_size      ←(8 SB 0)⍪(8SB⍤0⊢secsz)   ⍪(8 SB ≢shstr)
        sh_link      ←(4 SB 0)⍪({4⍴0}⍤0⊢secsz) ⍪(4 SB 0)
        sh_info      ←(4 SB 0)⍪({4⍴0}⍤0⊢secsz) ⍪(4 SB 0)
        sh_addralign ←(8 SB 0)⍪(8SB⍤0⊢secalign)⍪(8 SB 1)
        sh_entsize   ←(8 SB 0)⍪({8⍴0}⍤0⊢secsz) ⍪(8 SB 0)
        ∊,/sh_name sh_type sh_flags sh_addr sh_offset sh_size sh_link sh_info sh_addralign sh_entsize
    }⍬
    out[shtoff+⍳≢sht]←sht

    ⍝ Set expected file permissions
    chmod←⎕SHELL 'chmod' '+x' '--' o.out
    0≠2⊃chmod:('Cannot change output file to +x: ',o.out)⎕SIGNAL 200

    ⍝BREAK
    ⍬}
