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

    ⍝ Decode input files and sections
    (files h)←{paths←∪o.input ⋄ fb←{83 ¯1⎕MAP⍵'R'}¨paths
        bad←(7↑ELF∆IDENT∆EXP)∘≢¨7∘↑¨ident←9∘↑¨fb
        bad∨←~(7⊃¨ident)∊0 3 ⋄ bad∨←0≠8⊃¨ident
        ∨/bad:'Unexpected ELF file identification'⎕SIGNAL 200

        words←(≢fb)16⍴323⎕DR∊64∘↑¨fb ⋄ meta←U32 words[;4]
        etype←65536|meta ⋄ emachine←⌊meta÷65536
        ∨/1≠etype:'One of the input files is not an object file'⎕SIGNAL 200
        ∨/62≠emachine:'One of the input files is not for AMD64'⎕SIGNAL 200

        eshoff←words U64 10 ⋄ eshentsize←⌊(U32 words[;14])÷65536
        eshnum←65536|U32 words[;15]
        ∨/64≠eshentsize:'Unexpected section-header entry size'⎕SIGNAL 200

        ⍝ Decode section headers
        words←(+/eshnum)16⍴323⎕DR∊(eshoff+⍳¨64×eshnum)(⊂⍛⌷)¨fb
        (hn ht hl hi)←{U32 words[;⍵]}¨0 1 10 11
        (hf hx hz ha he)←words∘U64¨2 6 8 12 14
        fh0←¯1↓+\0,eshnum ⋄ hm←eshnum/⍳≢eshnum

        ⍝ mapped bytes, section start, section count
        files←fb fh0 eshnum
        ⍝ name, type, flags, file, file offset, size, align, entry size, link, info
        h←hn ht hf hm hx hz ha he hl hi
        files h
    }⍬

    (s r seckeep)←{
        ⍝ Decode symbols
        (s symbase)←{(hn ht hf hm hx hz ha he hl hi)←h ⋄ (fb fh0 fhn)←files
            symsh←⍸ht=2 ⋄ symobj←hm[symsh] ⋄ symx←hx[symsh] ⋄ symz←hz[symsh]
            count←symz÷24
            ∨/24≠he[symsh]:'Unexpected symbol entry size'⎕SIGNAL 200
            ∨/0≠24|symz:'Invalid symbol table size'⎕SIGNAL 200

            words←(+/count)6⍴323⎕DR∊(symx+⍳¨symz)(⊂⍛⌷)¨fb[symobj]

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
            strpool←∊(strx+⍳¨strz)(⊂⍛⌷)¨fb[symobj]

            nameat←strstart[own]+sn
            ∨/0≠strpool[strstart+strz-1]:'Invalid symbol string table'⎕SIGNAL 200
            zeros←⍸strpool=0 ⋄ namelen←zeros[(zeros⍸nameat)+0≠strpool[nameat]]-nameat
            sn←{strpool[nameat[⍵]+⍳namelen[⍵]]}¨⍳≢sn

            s←sn sb st so ss sv sz
            s symbase
        }⍬

        ⍝ COMDAT selection
        (s seckeep)←{(hn ht hf hm hx hz ha he hl hi)←h ⋄ (fb fh0 fhn)←files ⋄ (sn sb st so ss sv sz)←s
            keep←(≢ht)⍴1
            gsh←⍸ht=17 ⋄ gobj←hm[gsh] ⋄ goff←hx[gsh] ⋄ glen←hz[gsh]
            ∨/(glen<4)∨0≠4|glen:'Invalid SHT_GROUP size'⎕SIGNAL 200

            first←¯1↓+\0,1+count←¯1+glen÷4
            words←323⎕DR∊(goff+⍳¨glen)(⊂⍛⌷)¨fb[gobj]
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
        }⍬

        ⍝ Decode RELA
        r←{(hn ht hf hm hx hz ha he hl hi)←h ⋄ (fb fh0 fhn)←files
            relash←⍸ht=4 ⋄ relaobj←hm[relash] ⋄ relax←hx[relash] ⋄ relaz←hz[relash]
            count←relaz÷24
            ∨/24≠he[relash]:'Unexpected RELA entry size'⎕SIGNAL 200
            ∨/0≠24|relaz:'Unexpected RELA section size'⎕SIGNAL 200

            words←(+/count)6⍴323⎕DR∊(relax+⍳¨relaz)(⊂⍛⌷)¨fb[relaobj]

            rx←words U64 0 ⋄ (rt rawsym)←{U32 words[;⍵]}¨2 3 ⋄ ra←words S64 4
            own←count/⍳≢count ⋄ rh←(fh0[relaobj]+hi[relash])[own]

            symsh←fh0[relaobj]+hl[relash] ⋄ base←symbase[symsh]
            ∨/¯1=base:'RELA does not reference a symbol table'⎕SIGNAL 200
            rs←base[own]+rawsym

            rh rx rs rt ra
        }⍬

        s r seckeep
    }⍬

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

        copies←(hm[filesec])(hx[filesec])fsz foff

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
    _←{(fb fh0 fhn)←files ⋄ (fm fx fz ox)←copies
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
        ∨/(type≠1)∧type≠2:'Unsupported relocation type'⎕SIGNAL 200
        kind←type-1
        width←8 4[kind] ⋄ target←rh[rr] ⋄ offset←rx[rr] ⋄ targetz←hz[target]
        ∨/(offset>targetz)∨width>targetz-offset:'Relocation target outside section'⎕SIGNAL 200
        where←lx[target]+offset ⋄ S←ls[rs[rr]] ⋄ A←ra[rr] ⋄ P←la[target]+offset
        value←S+A-P×pc32←kind=1
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
