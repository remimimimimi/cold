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

    ⍝ Open files
    paths←∪o.input
    objs←{83 ¯1 ⎕MAP ⍵ 'R'}¨paths
    ⍝ objs←objs,objs

    ⍝ ELF header
    headerbytes←{16↓64↑⍵}¨objs
    ∨⌿ELF∆IDENT∆EXP∘≢¨9∘↑¨objs:'Unexpected ELF file identification'⎕SIGNAl 200
    (e_type e_machine)←↓⍉↑163∘⎕DR¨4∘↑¨headerbytes
    ∨⌿1∘≢¨e_type:'One of the input files is not an object file'⎕SIGNAL 200
    ∨⌿62∘≢¨e_machine:'One of the input files is not for AMD64'⎕SIGNAL 200
    (_ _ e_shoff)←↓⍉↑({256⊥⌽256|⍵}⍤1)(≢objs)3 8⍴↑{24↓48↑⍵}¨objs
    (_ _ _ e_shentsize e_shnum e_shstrndx)←↓⍉↑({256⊥⌽256|⍵}⍤1)(≢objs)6 2⍴↑{¯12↑64↑⍵}¨objs
    ∨⌿64≠e_shentsize:'Unexpected section-header entry size'⎕SIGNAL 200

    ⍝ Sections headers
    shtbytes←(e_shoff+⍳¨64×e_shnum)(⊂⍛⌷)¨objs
    shtwords←(+/e_shnum)16⍴323⎕DR∊shtbytes
    (sh_name sh_type sh_link sh_info)←↓⍉U32⍤0⊢shtwords[;0 1 10 11]
    (sh_flags sh_offset sh_size sh_addralign sh_entsize)←shtwords∘U64¨2 6 8 12 14
    shstart←¯1↓+\0,e_shnum ⋄ shown←e_shnum/⍳≢e_shnum

    ⍝ Symbols
    sym_sh←⍸sh_type=2 ⋄ symcount←sh_size[sym_sh]÷24
    ∨⌿24≠sh_entsize[sym_sh]:'Unexpected symbol entry size'⎕SIGNAL 200
    ∨⌿0≠24|sh_size[sym_sh]:'Invalid symbol table size'⎕SIGNAL 200
    symbytes←(sh_offset[sym_sh]+⍳¨sh_size[sym_sh])(⊂⍛⌷)¨objs[shown[sym_sh]]
    symwords←(+/symcount)6⍴323⎕DR∊symbytes
    (st_info st_other st_shndx)←(256 256 65536){⍺|⌊symwords[;1]÷⍵}¨1 256 65536
    st_bind←⌊st_info÷16 ⋄ st_type←16|st_info
    st_name←U32 symwords[;0] ⋄ (st_value st_size)←symwords∘U64¨2 4 ⋄ st_vis←4|st_other
    und←st_shndx=0 ⋄ reg←(0<st_shndx)∧st_shndx<65280 ⋄ abs←st_shndx=65521
    com←st_shndx=65522 ⋄ xnd←st_shndx=65535
    ∨⌿xnd:'Extended symbol section indices are not supported yet'⎕SIGNAL 200
    ∨⌿(st_shndx≥65280)∧~abs∨com∨xnd:'Unsupported reserve symbol section index'⎕SIGNAL 200
    symstart←¯1↓+\0,symcount ⋄ symown←symcount/⍳≢symcount ⋄ symobj←shown[sym_sh[symown]]
    symtabid←(≢sh_type)⍴¯1 ⋄ symtabid[sym_sh]←⍳≢sym_sh
    st_sec←(≢st_name)⍴¯1 ⋄ rows←⍸reg ⋄ st_sec[rows]←shstart[symobj[rows]]+st_shndx[rows]

    ⍝ Symbols string table
    symstr_sh←shstart[shown[sym_sh]]+sh_link[sym_sh]
    ∨⌿shown[symstr_sh]≠shown[sym_sh]:'Symbol table links outisde its object'⎕SIGNAL 200
    symstrbytes←(sh_offset[symstr_sh]+⍳¨sh_size[symstr_sh])(⊂⍛⌷)¨objs[shown[symstr_sh]]
    strsize←≢¨symstrbytes ⋄ strstart←¯1↓+\0,strsize ⋄ strpool←∊symstrbytes
    nameat←strstart[symown]+st_name
    ∨⌿0≠strpool[strstart+strsize-1]:'Invalid symbol string table'⎕SIGNAL 200
    zero←⍸strpool=0 ⋄ namelen←zero[(zero⍸nameat)+0≠strpool[nameat]]-nameat
    names←{strpool[nameat[⍵]+⍳namelen[⍵]]}¨⍳≢st_name

    ⍝ RELA
    rela_sh←⍸sh_type=4 ⋄ relacount←sh_size[rela_sh]÷24
    ∨⌿24≠sh_entsize[rela_sh]:'Unexpected RELA entry size'⎕SIGNAL 200
    ∨⌿0≠24|sh_size[rela_sh]:'Unexpected RELA section size'⎕SIGNAL 200
    relabytes←(sh_offset[rela_sh]+⍳¨sh_size[rela_sh])(⊂⍛⌷)¨objs[shown[rela_sh]]
    relawords←(+/relacount)6⍴323⎕DR∊relabytes
    r_offset←relawords U64 0 ⋄ (r_type r_sym)←↓⍉U32⍤0⊢relawords[;2 3] ⋄ r_addend←relawords S64 4
    relastart←¯1↓+\0,relacount ⋄ relaown←relacount/⍳≢relacount ⋄ relaobj←shown[rela_sh[relaown]]
    relatargetsec←shstart[shown[rela_sh]]+sh_info[rela_sh]
    r_targetsec←relatargetsec[relaown]
    relasym_sh←shstart[shown[rela_sh]]+sh_link[rela_sh]
    rela_symtab←symtabid[relasym_sh]
    ∨⌿rela_symtab=¯1:'RELA does not reference a symbol table'⎕SIGNAL 200
    r_symrow←symstart[rela_symtab[relaown]]+r_sym

    ⍝ Global symbols table
    weak←st_bind=2 ⋄ strong←st_bind∊1 10 ⋄ ext←strong∨weak ⋄ defd←reg∨abs∨com
    ∨⌿~st_bind∊0 1 2 10:'Unsupported symbol binding'⎕SIGNAL 200
    sdef←⍸strong∧defd∧~com
    ∨⌿~≠names[sdef]:'Multiple strong symbol definitions'⎕SIGNAL 200
    def←⍸ext∧defd ⋄ def←def[⍋com[def]+2×weak[def]] ⋄ def←(≠names[def])/def
    defnames←names[def] ⋄ find←defnames∘⍳
    r_def←r_symrow ⋄ rows←⍸ext[r_def] ⋄ hit←find names[r_def[rows]]
    missing←hit=≢def ⋄ required←(~weak[r_def[rows]])∨0≠st_vis[r_def[rows]]
    ∨⌿missing∧required:'Undefined symbol'⎕SIGNAL 200
    zero←≢st_name ⋄ r_def[rows]←(def,zero)[hit] ⋄ real←r_def≠zero
    ∨⌿(usedtype←st_type[real/r_def])=6:'TLS symbol relocation is not supported yet'⎕SIGNAL 200
    ∨⌿usedtype=10:'GNU IFUNC relocation is not supported yet'⎕SIGNAL 200


    ⍝ Identify entry point
    start←⊃find⊂83⎕DR'_start'
    start=≢defnames:'Undefined symbol: _start'⎕SIGNAL 200
    startsym←def[start]

    ⍝ Common symbols
    cdef←def/⍨com[def]
    ⍝BREAK
    crow←⍸ext∧com
    cid←names[cdef]∘⍳names[crow] ⋄ cid←(keep←cid<≢cdef)/cid ⋄ crow←keep/crow
    commonsize←(≢cdef)⍴0 ⋄ commonalign←(≢cdef)⍴1 ⋄ commonid←∪cid
    commonsize[commonid]←cid{⌈/⍵}⌸st_size[crow] ⋄ commonalign[commonid]←cid{⌈/⍵}⌸st_value[crow]

    ⍝ Layout
    alloc←0≠2|⌊sh_flags÷2 ⋄ sections←⍸alloc
    flags←sh_flags[sections] ⋄ type←sh_type[sections]
    sectionsize←sh_size[sections] ⋄ sectionalign←1⌈sh_addralign[sections]
    write←2|flags ⋄ exec←2|⌊flags÷4
    ∨⌿write∧exec:'Writable executable sections are not supported'⎕SIGNAL 200
    ∨⌿~sectionalign∊2*⍳63:'Unsupported section alignment'⎕SIGNAL 200
    nobits←type=8 ⋄ group←((~exec)+write)+3×nobits ⋄ nsec←≢sections
    group,←(≢cdef)⍴5 ⋄ size←sectionsize,commonsize ⋄ align←sectionalign,commonalign
    base←4194304 ⋄ hdrsz←64+56 ⋄ (order rel memsz)←hdrsz LAYOUT group size align
    sectionrel←nsec↑rel ⋄ commonrel←nsec↓rel
    file←~nobits ⋄ file_sections←file/sections ⋄ bss_sections←nobits/sections
    sh_outoff←(≢sh_type)⍴¯1 ⋄ sh_outaddr←(≢sh_type)⍴0
    sh_outoff[file_sections]←file/sectionrel ⋄ sh_outaddr[sections]←base+sectionrel
    filesz←⌈/hdrsz,(file/sectionrel)+file/sectionsize
    symaddr←reg\(sh_outaddr[reg/st_sec]+reg/st_value)
    symaddr[⍸abs]←abs/st_value ⋄ symaddr[cdef]←base+commonrel ⋄ symaddr,←0
    entry←symaddr[startsym] ⋄ out←filesz OUT∆INIT o.out

    ⍝ Copy sections
    chunksz←2*20
    _←{s←⍵ ⋄ n←sh_size[s]
        pos←chunksz×⍳⌈n÷chunksz ⋄ obj←⊃objs[shown[s]]
        _←{p←⍵ ⋄ k←chunksz⌊n-p ⋄ i←⍳k
            out[sh_outoff[s]+p+i]←obj[sh_offset[s]+p+i]
        ⍬}¨pos
    ⍬}¨file_sections

    ⍝ Apply static relocations
    _←{rr←⍸alloc[r_targetsec]∧sh_type[r_targetsec]≠8 ⋄ type←r_type[rr] ⋄ kind←(kinds←1 2)⍳type
        ∨⌿kind=≢kinds:'Unsupported relocation type'⎕SIGNAL 200
        width←8 4[kind] ⋄ target←r_targetsec[rr] ⋄ offset←r_offset[rr]
        ∨⌿(offset>sh_size[target])∨width>sh_size[target]-offset:'Relocation target outside section'⎕SIGNAL 200
        where←sh_outoff[target]+offset ⋄ S←symaddr[r_def[rr]] ⋄ A←r_addend[rr] ⋄ P←base+where
        value←S+A-P×kind=1 ⋄ pc32←kind=1
        ∨⌿pc32∧((value<¯1×2*31)∨value>¯1+2*31):'Relocation value overflow'⎕SIGNAL 200

        batchbytes←2*20 ⍝ avoid large allocation for temporary arrays.
        _←{w←⍵
            rows←⍸width=w ⋄ count←≢rows ⋄ span←⌈batchbytes÷1⌈w
            _←{first←⍵×span ⋄ sel←rows[first+⍳span⌊count-first]
                bytes←⊖(w⍴256)⊤value[sel]
                out[(⍳w)∘.+where[sel]]←bytes-256×bytes≥128
            ⍬}¨⍳⌈count÷span
        ⍬}¨∪width ⋄ ⍬}⍬

    ⍝ Construct headers
    header←{entry base filesz memsz←⍵
        ident←ELF∆IDENT∆EXP,7⍴0
        ehdr←,ident
        ehdr,←2 SB 2 62
        ehdr,←4 SB 1
        ehdr,←8 SB entry 64 0
        ehdr,←4 SB 0
        ehdr,←2 SB 64 56 1 0 0 0
        phdr←,4 SB 1 7 ⍝ PT_LOAD and PF_R | PF_W | PF_X
        phdr,←8 SB 0 base base filesz memsz 4096
        ehdr,phdr
    }entry base filesz memsz
    out[⍳≢header]←header

    ⍝ Set expected file permissions
    chmod←⎕SHELL 'chmod' '+x' '--' o.out
    0≠2⊃chmod:('Cannot change output file to +x: ',o.out)⎕SIGNAL 200

    ⍝BREAK
    ⍬}
