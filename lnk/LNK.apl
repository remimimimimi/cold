⎕IO←0

U32←{⍵+(2*32)×⍵<0} ⋄ U64←{(U32 ⍺[;⍵])+(2*32)×U32 ⍺[;⍵+1]}
S64←{(U32 ⍺[;⍵])+(2*32)×⍺[;⍵+1]} ⋄ SB←{b←,⍉⊖(⍺⍴256)⊤⍵ ⋄ b-256×b≥128}
ZSTR←{80⎕DR(⍵⍳0)↑⍵} ⋄ ZSTRU←{⎕UCS(⍵⍳0)↑⍵}
ALIGN←{⍺+⍵|-⍺}

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
        m←⍵∘≡¨(≢⍵)↑¨args ⋄ v←(≢⍵)↓¨m/args ⋄ ⊃¯1↑(⊂⍺),v
    }←'-dynamic-linker' '-o' '--sysroot=' '--hash-style=' '--build-id=' '--dependency-file='
    o.(static pie)←'-static' '-pie'∊args
    o.input←args/⍨'-'≠⊃¨args ⋄ o}

LAYOUT←{group size align←⍵ ⋄ ⍺←0 ⍝ optional origin
    0=n←≢size:⍬ ⍬ ⍺
    p←⍋group ⋄ g←group[p] ⋄ s←size[p] ⋄ a←align[p]
    a[0,1+⍸2≠/g]←g{⌈/⍵}⌸a
    x←⍺+0,¯1↓+\s ⋄ M←⌈/a
    F←{⍺≥M:⍵ ⋄ m←a>⍺ ⋄ v←2|⌊(m/⍵)÷⍺ ⋄ (2×⍺)∇⍵+⍺×+\m\2≠/0,v}
    x←1 F x ⋄ z←n⍴0 ⋄ z[p]←x
    p z(⊃⌽x+s)}

OUT∆INIT←{size←⍺ ⋄ file←⍵
    t←file ⎕NCREATE 0
    _←size ⎕NRESIZE t
    _←⎕NUNTIE t
    83 size ⎕MAP file 'W'}

ELF∆IDENT∆EXP←127 69 76 70 2 1 1 0 0

LNK←{o←PS∆ARGS ⍵
    0≡≢o.input: 'Expected at least one input file to link'⎕SIGNAL 200

    ⍝ Decode input files and sections
    (files h)←{paths←∪o.input ⋄ fb←{83 ¯1⎕MAP⍵'R'}¨paths
        headerbytes←{16↓64↑⍵}¨fb
        ∨⌿ELF∆IDENT∆EXP∘≢¨9∘↑¨fb:'Unexpected ELF file identification'⎕SIGNAL 200

        (etype emachine)←↓⍉↑163∘⎕DR¨4∘↑¨headerbytes
        ∨⌿1∘≢¨etype:'One of the input files is not an object file'⎕SIGNAL 200
        ∨⌿62∘≢¨emachine:'One of the input files is not for AMD64'⎕SIGNAL 200

        (_ _ eshoff)←↓⍉↑({256⊥⌽256|⍵}⍤1)(≢fb)3 8⍴↑{24↓48↑⍵}¨fb
        (_ _ _ eshentsize eshnum _)←↓⍉↑({256⊥⌽256|⍵}⍤1)(≢fb)6 2⍴↑{¯12↑64↑⍵}¨fb
        ∨⌿64≠eshentsize:'Unexpected section-header entry size'⎕SIGNAL 200

        ⍝ Decode section headers
        bytes←(eshoff+⍳¨64×eshnum)(⊂⍛⌷)¨fb ⋄ words←(+/eshnum)16⍴323⎕DR∊bytes
        (hn ht hl hi)←↓⍉U32⍤0⊢words[;0 1 10 11] ⋄ (hf hx hz ha he)←words∘U64¨2 6 8 12 14
        fh0←¯1↓+\0,eshnum ⋄ hm←eshnum/⍳≢eshnum

        ⍝ mapped bytes, section start, section count
        files←fb fh0 eshnum
        ⍝ name, type, flags, file, file offset, size, ailgn, entry size, link, info
        h←hn ht hf hm hx hz ha he hl hi
        files h
    }⍬

    (s r)←{
        ⍝ Decode symbols
        (s symbase)←{(hn ht hf hm hx hz ha he hl hi)←h ⋄ (fb fh0 fhn)←files
            symsh←⍸ht=2 ⋄ count←hz[symsh]÷24
            ∨⌿he[symsh]≠24:'Unexpected symbol entry size'⎕SIGNAL 200
            ∨⌿0≠24|hz[symsh]:'Invalid symbol table size'⎕SIGNAL 200

            bytes←(hx[symsh]+⍳¨hz[symsh])(⊂⍛⌷)¨fb[hm[symsh]]
            words←(+/count)6⍴323⎕DR∊bytes

            (info other shndx)←(256 256 65536){⍺|⌊words[;1]÷⍵}¨1 256 65536
            sb←⌊info÷16 ⋄ st←16|info ⋄ sn←U32 words[;0]
            (sv sz)←words∘U64¨2 4 ⋄ so←4|other

            reg←(0<shndx)∧shndx<65280
            abs←shndx=65521 ⋄ com←shndx=65522 ⋄ xnd←shndx=65535
            ∨⌿xnd:'Extended symbol section indices are not supported yet'⎕SIGNAL 200
            ∨⌿(shndx≥65280)∧~abs∨com∨xnd:'Unsupported reserved symbol section index'⎕SIGNAL 200

            start←¯1↓+\0,count ⋄ own←count/⍳≢count ⋄ obj←hm[symsh[own]]
            symbase←(≢ht)⍴¯1 ⋄ symbase[symsh]←start

            ⍝ Symbols string table
            ss←(≢sn)⍴¯1 ⋄ ss[⍸abs]←¯2 ⋄ ss[⍸com]←¯3
            ss[rows]←fh0[obj[rows]]+shndx[rows←⍸reg]
            strsh←fh0[hm[symsh]]+hl[symsh]
            ∨⌿hm[strsh]≠hm[symsh]:'Symbol table links outside its object'⎕SIGNAL 200
            strbytes←(hx[strsh]+⍳¨hz[strsh])(⊂⍛⌷)¨fb[hm[strsh]]
            strz←≢¨strbytes ⋄ strstart←¯1↓+\0,strz ⋄ strpool←∊strbytes
            ⍝BREAK
            nameat←strstart[own]+sn
            ∨⌿0≠strpool[strstart+strz-1]:'Invalid symbol string table'⎕SIGNAL 200
            zeros←⍸strpool=0 ⋄ namelen←zeros[(zeros⍸nameat)+0≠strpool[nameat]]-nameat
            sn←{strpool[nameat[⍵]+⍳namelen[⍵]]}¨⍳≢sn

            s←sn sb st so ss sv sz
            s symbase
        }⍬

        ⍝ Decode RELA
        r←{(hn ht hf hm hx hz ha he hl hi)←h ⋄ (fb fh0 fhn)←files
            relash←⍸ht=4 ⋄ count←hz[relash]÷24
            ∨⌿he[relash]≠24:'Unexpected RELA entry size'⎕SIGNAL 200
            ∨⌿0≠24|hz[relash]:'Unexpected RELA section size'⎕SIGNAL 200

            bytes←(hx[relash]+⍳¨hz[relash])(⊂⍛⌷)¨fb[hm[relash]]
            words←(+/count)6⍴323⎕DR∊bytes

            rx←words U64 0 ⋄ (rt rawsym)←↓⍉U32⍤0⊢words[;2 3] ⋄ ra←words S64 4
            own←count/⍳≢count ⋄ rh←(fh0[hm[relash]]+hi[relash])[own]

            symsh←fh0[hm[relash]]+hl[relash] ⋄ base←symbase[symsh]
            ∨⌿base=¯1:'RELA does not reference a symbol table'⎕SIGNAL 200
            rs←base[own]+rawsym

            rh rx rs rt ra
        }⍬

        s r
    }⍬

    ⍝ Symbol resolution
    (r common startsym)←{(s r)←⍵ ⋄ (sn sb st so ss sv sz)←s ⋄ (rh rx rs rt ra)←r
        reg←ss≥0 ⋄ abs←ss=¯2 ⋄ com←ss=¯3
        weak←sb=2 ⋄ strong←sb∊1 10 ⋄ ext←strong∨weak
        defd←reg∨abs∨com
        ∨⌿~≠sn[⍸strong∧defd∧~com]:'Multiple strong symbol definitions'⎕SIGNAL 200

        def←⍸ext∧defd ⋄ def←def[⍋com[def]+2×weak[def]] ⋄ def←(≠sn[def])/def
        defnames←sn[def] ⋄ find←defnames∘⍳

        rdef←rs ⋄ rows←⍸ext[rdef] ⋄ hit←find sn[rdef[rows]]
        missing←hit=≢def ⋄ required←(~weak[rdef[rows]])∨0≠so[rdef[rows]]
        ∨⌿missing∧required:'Undefined symbol'⎕SIGNAL 200

        zero←≢sn ⋄ rdef[rows]←(def,zero)[hit] ⋄ real←rdef≠zero
        ∨⌿(usedtype←st[real/rdef])=6:'TLS symbol relocation is not supported yet'⎕SIGNAL 200
        ∨⌿usedtype=10:'GNU IFUNC relocation is not supported yet'⎕SIGNAL 200

        ⍝ Identify entry point
        start←⊃find⊂83⎕DR'_start'
        start=≢defnames:'Undefined symbol: _start'⎕SIGNAL 200
        startsym←def[start]

        ⍝ Common symbols
        cdef←def/⍨com[def] ⋄ crow←⍸ext∧com
        cid←sn[cdef]∘⍳sn[crow] ⋄ cid←(keep←cid<≢cdef)/cid ⋄ crow←keep/crow
        cz←(≢cdef)⍴0 ⋄ ca←(≢cdef)⍴1 ⋄ ids←∪cid
        cz[ids]←cid{⌈/⍵}⌸sz[crow] ⋄ ca[ids]←cid{⌈/⍵}⌸sv[crow]

        r←rh rx rdef rt ra ⋄ common←cdef cz ca
        r common startsym
    }s r

    ⍝ Layout
    base←4194304
    (layout copies)←{(h s common startsym)←⍵
        (hn ht hf hm hx hz ha he hl hi)←h ⋄ (sn sb st so ss sv sz)←s ⋄ (cs cz ca)←common
        alloc←0≠2|⌊hf÷2 ⋄ secs←⍸alloc ⋄ flags←hf[secs] ⋄ type←ht[secs]
        secz←hz[secs] ⋄ seca←1⌈ha[secs]

        write←2|flags ⋄ exec←2|⌊flags÷4
        ∨⌿write∧exec:'Writable executable sections are not supported'⎕SIGNAL 200
        ∨⌿~seca∊2*⍳63:'Unsupported section alignment'⎕SIGNAL 200

        nobits←type=8 ⋄ group←((~exec)+write)+3×nobits ⋄ nsec←≢secs
        group,←(≢cs)⍴5 ⋄ size←secz,cz ⋄ align←seca,ca

        hdrsz←64+56
        (order rel memsz)←hdrsz LAYOUT group size align
        secrel←nsec↑rel ⋄ comrel←nsec↓rel

        file←~nobits ⋄ filesec←file/secs

        copies←(file/hm[secs])(file/hx[secs])(file/secz)(file/secrel)

        shoff←(≢ht)⍴¯1 ⋄ shaddr←(≢ht)⍴0
        shoff[filesec]←file/secrel ⋄ shaddr[secs]←base+secrel
        filesz←⌈/hdrsz,(file/secrel)+file/secz

        reg←ss≥0 ⋄ abs←ss=¯2
        symaddr←reg\(shaddr[reg/ss]+reg/sv) ⋄ symaddr[⍸abs]←abs/sv
        symaddr[cs]←base+comrel ⋄ symaddr,←0

        entry←symaddr[startsym]
        layout←shoff shaddr symaddr filesz memsz entry
        layout copies
    }h s common startsym
    out←{(lx la ls lfz lmz le)←layout
        lfz OUT∆INIT o.out}⍬

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
        rr←⍸(0≠2|⌊hf[rh]÷2)∧ht[rh]≠8 ⋄ type←rt[rr] ⋄ kind←(kinds←1 2)⍳type
        ∨⌿kind=≢kinds:'Unsupported relocation type'⎕SIGNAL 200
        width←8 4[kind] ⋄ target←rh[rr] ⋄ offset←rx[rr]
        ∨⌿(offset>hz[target])∨width>hz[target]-offset:'Relocation target outside section'⎕SIGNAL 200
        where←lx[target]+offset ⋄ S←ls[rs[rr]] ⋄ A←ra[rr] ⋄ P←la[target]+offset
        value←S+A-P×kind=1 ⋄ pc32←kind=1
        ∨⌿pc32∧((value<¯1×2*31)∨value>¯1+2*31):'Relocation value overflow'⎕SIGNAL 200

        batchbytes←2*20 ⍝ avoid large allocation for temporary arrays.
        _←{w←⍵
            rows←⍸width=w ⋄ count←≢rows ⋄ span←⌈batchbytes÷1⌈w
            _←{first←⍵×span ⋄ sel←rows[first+⍳span⌊count-first]
                bytes←⊖(w⍴256)⊤value[sel]
                out[(⍳w)∘.+where[sel]]←bytes-256×bytes≥128
            ⍬}¨⍳⌈count÷span
        ⍬}¨∪width
    ⍬}⍬

    ⍝ Construct headers
    header←{(lx la ls lfz lmz le)←layout
        ident←ELF∆IDENT∆EXP,7⍴0
        ehdr←,ident
        ehdr,←2 SB 2 62
        ehdr,←4 SB 1
        ehdr,←8 SB le 64 0
        ehdr,←4 SB 0
        ehdr,←2 SB 64 56 1 0 0 0
        phdr←,4 SB 1 7 ⍝ PT_LOAD and PF_R | PF_W | PF_X
        phdr,←8 SB 0 base base lfz lmz 4096
        ehdr,phdr
    }⍬
    out[⍳≢header]←header

    ⍝ Set expected file permissions
    chmod←⎕SHELL 'chmod' '+x' '--' o.out
    0≠2⊃chmod:('Cannot change output file to +x: ',o.out)⎕SIGNAL 200

    ⍝BREAK
    ⍬}
