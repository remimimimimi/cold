⎕IO←0

U32←{⍵+(2*32)×⍵<0} ⋄ U64←{(U32 ⍺[;⍵])+(2*32)×U32 ⍺[;⍵+1]}
S64←{(U32 ⍺[;⍵])+(2*32)×⍺[;⍵+1]} ⋄ SB←{0=≢⍵:⍬ ⋄ b←,⍉⊖(⍺⍴256)⊤⍵ ⋄ b-256×b≥128}
ZSTR←{80⎕DR(⍵⍳0)↑⍵} ⋄ ZSTRU←{⎕UCS(⍵⍳0)↑⍵}
ALIGN←{⍵+⍺|-⍵}
RELA←{(off info add)←⍵ ⋄ at←24×⍳≢off
    (8SB add)@(,at∘.+16+⍳8)⊢(8SB info)@(,at∘.+8+⍳8)⊢(8SB off)@(,at∘.+⍳8)⊢0⍴⍨24×≢off}

⍝ Entry point
LNK←{o←PS∆ARGS ⍵
    0=≢o.input: 'Expected at least one input file to link'⎕SIGNAL 200

    paths fb direct shared archives optional←INPUTS o

    ⍝ Decode the initial ELF views.
    (files h ds soname)←DECODE fb direct shared

    ⍝ Complete object discovery and discard every parsing only representation.
    (f h s ds r n)←OBJECTS paths archives files h ds
    ⍝ Resolve symbols, then replace ELF special section indices by h rows.
    (h s r startsym)←RESOLVE n h s ds r

    ⍝ Record PLT, GOT and TLS descriptor slots directly on their symbol rows.
    (s r)←SLOTS o h s r

    ⍝ Construct the generated tables from h and s.
    d←DYNAMIC o shared optional soname h s r n

    ⍝ Assign output slices and derive ELF metadata.
    (h s im)←IMAGE o d n.special h s startsym
    (im sh ph)←HEADERS o d h im
    WRITE o f h s r n.special d im sh ph}

PS∆ARGS←{args←⍵
    ∨/'-h' '--help'∊args:'There is no help'⎕SIGNAL 200
    ∨/'-v' '--version'∊args:'0.1.0 or smth'⎕SIGNAL 200

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
    begin←paren∨2</0,atom
    tokens←((+\begin)×(atom∨paren))⊆src
    head←⊃¨tokens ⋄ t←'('(-⍥(head∘=))')' ⋄ d←+\t ⋄ b←d-t
    (0>⌊/0,d)∨0≠⊢/0,d:'Unbalanced linker script parentheses'⎕SIGNAL 200

    o←⍸t=1
    0=≢o:'Linker script contains no supported inputs'⎕SIGNAL 200
    0∨.≠(1,t)[o]:'Expected command before ('⎕SIGNAL 200
    cmd←1⎕C tokens[o-1]
    ~∧/cmd∊'INPUT' 'GROUP' 'AS_NEEDED' 'OUTPUT_FORMAT':'Unsupported linker script command'⎕SIGNAL 200
    (cmd∊⊂'AS_NEEDED')∨.∧b[o]=0:'AS_NEEDED must be inside INPUT or GROUP'⎕SIGNAL 200
    (cmd∊'INPUT' 'GROUP' 'OUTPUT_FORMAT')∨.∧b[o]≠0:'Nested linker script command'⎕SIGNAL 200

    command←1@(o-1)⊢t≢⍛⍴0
    command∨.<(t=0)∧b=0:'Unexpected text outside linker script command'⎕SIGNAL 200
    top←o/⍨b[o]=0 ⋄ topcmd←cmd/⍨b[o]=0
    owner←+\1@top⊢t≢⍛⍴0

    arg←command<(t=0)∧(b>0)∧owner⊂⍛⌷0,topcmd∊'INPUT' 'GROUP'
    ~∨/arg:'Linker script contains no supported inputs'⎕SIGNAL 200
    (arg/tokens)(arg/b>1)}

⍝ Expand command line inputs and scripts, map them, and return only format views.
INPUTS←{o←⍵ ⋄ ext←o.static↓'.so' '.a'
    libs←{spec←⍵ ⋄ lib←{'-l'≡2↑⍵}¨spec
        ~∨/lib:spec
        0=≢o.path:'Cannot resolve libraries without -L'⎕SIGNAL 200
        ({name←2↓⍵ ⋄ candidates←,o.path∘.{⍺,'/lib',name,⍵}ext
            ~∨/exists←⎕NEXISTS¨candidates:('Cannot find ',⍵)⎕SIGNAL 200
            (exists⍳1)⊃candidates}¨lib/spec)@{lib}⊢spec}

    q←⎕NS⍬ ⋄ q.(paths fb kind thin optional)←⊂⍬
    q.spec←o.input,('-l'∘,¨o.lib) ⋄ q.specopt←q.spec≢⍛⍴0
    q←{q←⍵ ⋄ spec specopt←q.(spec specopt)
        input←libs spec ⋄ mapped←{83 ¯1⎕MAP⍵'R'}¨input ⋄ head←↑64∘↑¨mapped
        elf←head[;⍳4]∧.=127 69 76 70 ⋄ etype←head[;16]+256×head[;17]
        elf∨.∧~etype∊1 3:'Unsupported ELF file type'⎕SIGNAL 200
        thick←head[;⍳8]∧.=33 60 97 114 99 104 62 10
        thin←head[;⍳8]∧.=33 60 116 104 105 110 62 10
        script←~binary←elf∨thick∨thin

        parsed←{SCRIPT ⎕UCS 256|⍵}¨(0⍴⊂⍬),script/mapped
        members←(0⍴⊂'.'),⊃,/(0⊃¨parsed),⊂⍬ ⋄ asneeded←⊃,/(1⊃¨parsed),⊂⍬ ⋄ count←≢∘⊃¨parsed
        candidate←(count/{⊃1⎕NPARTS ⍵}¨script/input),¨members
        check←(×≢¨members)∧('-'≠⊃¨members)∧'/'≠⊃¨members
        local←(⎕NEXISTS¨check/candidate)@{check}⊢members≢⍛⍴0
        members←(local/candidate)@{local}⊢members

        search←('-'≠⊃¨members)∧~⎕NEXISTS¨members
        members←{found←{candidates←o.path,¨⊂'/',⍵ ⋄ exists←⎕NEXISTS¨candidates
                ~∨/exists:('Cannot find linker script input ',⍵)⎕SIGNAL 200
                (exists⍳1)⊃candidates}¨search/⍵
            found@{search}⊢⍵}⍣(∨/search)⊢members

        q.paths,←binary/input ⋄ q.fb,←binary/mapped ⋄ q.kind,←binary/etype×elf
        q.thin,←binary/thin ⋄ q.optional,←binary/specopt
        q.spec←members ⋄ q.specopt←(count/script/specopt)∨asneeded ⋄ q
    }⍣{0=≢⍺.spec}⊢q

    paths fb kind thin optional←q.(paths fb kind thin optional)
    vm←⍳≢fb ⋄ vx←fb≢⍛⍴0 ⋄ ve←≢¨fb
    rel←kind=1 ⋄ dyn←kind=3 ⋄ ar←kind=0
    paths fb((rel/vm)(rel/vx)(rel/ve))((dyn/vm)(dyn/vx)(dyn/ve))((ar/vm)(ar/vx)(ar/ve)(ar/thin))optional}

LAYOUT←{group size align←⍵ ⋄ ⍺←0 ⍝ optional origin
    0=n←≢size:⍬ ⍬ ⍺
    p←⍋group ⋄ g←group[p] ⋄ s←size[p] ⋄ a←align[p]
    a[⍸2≠/¯1,g]←g{⌈/⍵}⌸a
    x←⍺+0,¯1↓+\s ⋄ M←⌈/a
    F←{⍺≥M:⍵ ⋄ m←a>⍺ ⋄ v←2|⌊(m/⍵)÷⍺ ⋄ (2×⍺)∇⍵+⍺×+\m\2≠/0,v}
    x←1 F x ⋄ z←x@p⊢n⍴0
    p z(⊃⌽x+s)}

OUT∆INIT←{size←⍺ ⋄ file←⍵
    _←1⎕NDELETE file
    t←file ⎕NCREATE 0
    _←size ⎕NRESIZE t
    _←⎕NUNTIE t
    83 size ⎕MAP file 'W'}

ELF∆IDENT∆EXP←127 69 76 70 2 1 1 0 0

SPECIAL∆START SPECIAL∆GOT SPECIAL∆INIT SPECIAL∆FINI←⍳4
SPECIAL∆NAME←83⎕DR¨'_start' '_GLOBAL_OFFSET_TABLE_' '_init' '_fini'

GEN∆INTERP GEN∆PLT GEN∆HASH GEN∆SYM GEN∆STR GEN∆RPLT GEN∆RELA GEN∆GOT GEN∆DYNAMIC←⍳9
GEN∆NAME←'.interp' '.plt' '.hash' '.dynsym' '.dynstr' '.rela.plt' '.rela.dyn' '.got' '.dynamic'
GEN∆TYPE← 1  1 5 11 3 4 4 1 6 ⋄ GEN∆FLAGS←  2  6 2  2 2  2  2 3  3
GEN∆ALIGN←1 16 8  8 1 8 8 8 8 ⋄ GEN∆ENTSIZE←0 16 4 24 0 24 24 8 16

KIND∆INIT KIND∆TEXT KIND∆FINI KIND∆RODATA KIND∆DATA KIND∆INITARRAY KIND∆FINIARRAY KIND∆TDATA KIND∆TBSS KIND∆BSS←⍳10
KIND∆NAME←'.init' '.text' '.fini' '.rodata' '.data' '.init_array' '.fini_array' '.tdata' '.tbss' '.bss'
KIND∆TYPE←   1 1 1 1 1 14 15 1 8 8  ⋄ KIND∆FLAGS←6 6 6 2 3 3 3 1027 1027 3
KIND∆ENTSIZE←0 0 0 0 0  8  8 0 0 0  ⋄ KIND∆SEG←  0 0 0 1 2 2 2 2    2    2
GEN∆KIND←KIND∆RODATA KIND∆TEXT KIND∆RODATA KIND∆RODATA KIND∆RODATA KIND∆RODATA KIND∆RODATA KIND∆DATA KIND∆DATA

SHT∆NOBITS SHT∆INITARRAY SHT∆FINIARRAY SHT∆INIT SHT∆FINI←8 14 15 256 257
SHF∆WRITE SHF∆ALLOC SHF∆EXEC SHF∆TLS←1 2 4 1024

⍝ Decode ELF file views into section rows.
⍝ [f]ile: [b]ytes [v]iew first-[h]eader header-[n]umber
⍝ [v]iew: [m]ap offset-[x] [e]nd
⍝ section [h]eader: [n]ame [t]ype [f]lags [m]ap offset-[x] si[z]e [a]lign [e]ntsize [l]ink [i]nfo symbol-[b]ase [o]utput-offset [v]addr
ELF←{expected vbase hbase←⍺ ⋄ fb views←⍵ ⋄ (vm vx ve)←views ⋄ vz←ve-vx
    head←↑{64↑(⊃fb[vm[⍵]])[vx[⍵]+⍳64⌊vz[⍵]]}¨⍳≢vm
    bad←~head[;⍳7]∧.=7↑ELF∆IDENT∆EXP ⋄ bad∨←~head[;7]∊0 3 ⋄ bad∨←0≠head[;8]
    ∨/bad:'Unexpected ELF file identification'⎕SIGNAL 200

    words←(≢vm)16⍴323⎕DR,head ⋄ meta←U32 words[;4]
    etype←65536|meta
    expected∨.≠etype:'One of the input files is not an object file'⎕SIGNAL 200
    62∨.≠⌊meta÷65536:'One of the input files is not for AMD64'⎕SIGNAL 200

    eshoff←words U64 10
    eshnum←65536|U32 words[;15] ⋄ eshstrndx←⌊(U32 words[;15])÷65536
    64∨.≠⌊(U32 words[;14])÷65536:'Unexpected section-header entry size'⎕SIGNAL 200
    ∨/(eshoff>vz)∨(64×eshnum)>vz-eshoff:'Section headers outside input view'⎕SIGNAL 200

    words←(+/eshnum)16⍴323⎕DR∊(vx+eshoff+⍳¨64×eshnum)(⊂⍛⌷)¨fb[vm]
    (hn ht hl hi)←{U32 words[;⍵]}¨0 1 10 11
    (hf hx hz ha he)←words∘U64¨2 6 8 12 14
    first←(+\-⊢)eshnum ⋄ fh←hbase+first ⋄ own←eshnum/⍳≢eshnum
    ∨/eshstrndx≥eshnum:'Invalid section-name string table index'⎕SIGNAL 200
    shstr←first+eshstrndx
    ∨/hn≥hz[shstr[own]]:'Section name outside string table'⎕SIGNAL 200

    rows←⍸(ht=1)∧(2|⌊hf÷SHF∆ALLOC)∧2|⌊hf÷SHF∆EXEC
    obj←own[rows] ⋄ map←vm[obj] ⋄ at←vx[obj]+hx[shstr[obj]]+hn[rows]
    name←(≢rows)6⍴0 ⋄ full←6≤hz[shstr[obj]]-hn[rows]
    _←{r←⍸full∧map=⍵ ⋄ index←,at[r]∘.+⍳6
        name[r;]←(≢r)6⍴(⊃fb[⍵])[index] ⋄ ⍬}¨∪full/map
    ht←SHT∆FINI@(rows/⍨name∧.=(83⎕DR'.fini'),0)⊢SHT∆INIT@(rows/⍨name∧.=(83⎕DR'.init'),0)⊢ht

    hm←vbase+own ⋄ hb←ht≢⍛⍴¯1
    (fb views fh eshnum)(hn ht hf hm hx hz ha he hl hi hb)}

⍝ Decode object symbol tables and retain raw name slices.
⍝ [s]ymbol: [n]ame [b]inding [t]ype visibilit[y] [s]ection [v]alue si[z]e
SYMBOLS←{sbase hbase←⍺ ⋄ files h←⍵
    (hn ht hf hm hx hz ha he hl hi hb)←h ⋄ (fb fv fh fn)←files ⋄ (vm vx ve)←fv
    symsh←⍸ht=2 ⋄ symobj←hm[symsh] ⋄ symz←hz[symsh]
    count←symz÷24
    ∨/24≠he[symsh]:'Unexpected symbol entry size'⎕SIGNAL 200
    ∨/0≠24|symz:'Invalid symbol table size'⎕SIGNAL 200

    words←(+/count)6⍴323⎕DR∊(vx[symobj]+hx[symsh]+⍳¨symz)(⊂⍛⌷)¨fb[vm[symobj]]
    (info other shndx)←(256 256 65536){⍺|⌊words[;1]÷⍵}¨1 256 65536
    sb←1@(10∘=)⊢⌊info÷16 ⋄ st←16|info ⋄ sn←U32 words[;0]
    (sv sz)←words∘U64¨2 4 ⋄ sy←4|other

    reg←(0<shndx)∧shndx<65280
    abs←shndx=65521 ⋄ com←shndx=65522 ⋄ xnd←shndx=65535
    ∨/xnd:'Extended symbol section indices are not supported yet'⎕SIGNAL 200
    ∨/(shndx≥65280)∧~(abs∨com∨xnd):'Unsupported reserved symbol section index'⎕SIGNAL 200

    start←(+\-⊢)count ⋄ own←count/⍳≢count ⋄ obj←symobj[own]
    ⍝ Symbol-table section → first row in the global symbol arena.
    localbase←start@symsh⊢ht≢⍛⍴¯1 ⋄ hb←(sbase+start)@symsh⊢hb

    ss←sn≢⍛⍴¯1 ⋄ ss[⍸abs]←¯2 ⋄ ss[⍸com]←¯3
    ss[rows]←fh[obj[rows]]+shndx[rows←⍸reg]
    strsh←fh[symobj]+hl[symsh]
    ∨/hm[strsh-hbase]≠symobj:'Symbol table links outside its object'⎕SIGNAL 200
    strx←hx[strsh-hbase] ⋄ strz←hz[strsh-hbase] ⋄ strstart←(+\-⊢)strz
    sn∨.≥strz[own]:'Symbol name outside string table'⎕SIGNAL 200
    named←sb≠0 ⋄ gsh←⍸ht=17
    named[localbase[fh[hm[gsh]]+hl[gsh]-hbase]+hi[gsh]]←1
    pool←∊(vx[symobj]+strx+⍳¨strz)(⊂⍛⌷)¨fb[vm[symobj]]
    0∨.≠pool[strstart+strz-1]:'Invalid symbol string table'⎕SIGNAL 200
    at←strstart[own]+sn ⋄ zero←⍸pool=0 ⋄ namelen←sn≢⍛⍴0
    rows←⍸named ⋄ namelen[rows]←zero[(zero⍸at[rows])+0≠pool[at[rows]]]-at[rows]

    (hn ht hf hm hx hz ha he hl hi hb)((sn≢⍛⍴0)sb st sy ss sv sz)(pool at namelen)}

⍝ Decode visible definitions and SONAMEs exported by shared objects.
⍝ [d]ynamic symbol: [m]ap [n]ame [b]inding [t]ype visibilit[y] [v]alue si[z]e
DSYMBOLS←{files h←⍵
    (hn ht hf hm hx hz ha he hl hi hb)←h ⋄ (fb fv fh fn)←files ⋄ (vm vx ve)←fv
    0=≢vm:(7⍴⊂⍬)⍬

    symsh←⍸ht=11
    vm≠⍥≢symsh:'Expected one dynamic symbol table per shared object'⎕SIGNAL 200
    symobj←hm[symsh] ⋄ symz←hz[symsh]
    (⍳≢vm)≢symobj:'Dynamic symbol tables are not one per shared object'⎕SIGNAL 200
    24∨.≠he[symsh]:'Unexpected dynamic symbol entry size'⎕SIGNAL 200
    0∨.≠24|symz:'Invalid dynamic symbol table size'⎕SIGNAL 200

    words←(+/count←symz÷24)6⍴323⎕DR∊(vx[symobj]+hx[symsh]+⍳¨symz)(⊂⍛⌷)¨fb[vm[symobj]]
    sn←U32 words[;0] ⋄ info←256|words[;1] ⋄ other←256|⌊words[;1]÷256
    sb←⌊info÷16 ⋄ st←16|info ⋄ sy←4|other ⋄ shndx←65536|⌊words[;1]÷65536
    (sv sz)←words∘U64¨2 4

    own←count/⍳≢count ⋄ obj←symobj[own]
    keep←(sb∊1 2 10)∧(shndx≠0)∧sy∊0 3

    strsh←fh[symobj]+hl[symsh]
    hm[strsh]∨.≠symobj:'Dynamic symbol table links outside its shared object'⎕SIGNAL 200
    strz←hz[strsh] ⋄ strstart←(+\-⊢)strz
    strpool←∊(vx[symobj]+hx[strsh]+⍳¨strz)(⊂⍛⌷)¨fb[vm[symobj]]

    nameat←strstart[own]+sn
    sn∨.≥strz[own]:'Dynamic symbol name outside string table'⎕SIGNAL 200
    0∨.≠strpool[strstart+strz-1]:'Invalid dynamic string table'⎕SIGNAL 200
    zeros←⍸strpool=0
    namelen←zeros[(zeros⍸nameat)+0≠strpool[nameat]]-nameat
    name←{strpool[nameat[⍵]+⍳namelen[⍵]]}¨⍸keep

    dynsh←⍸ht=6
    vm≠⍥≢dynsh:'Expected one dynamic section per shared object'⎕SIGNAL 200
    dynobj←hm[dynsh] ⋄ dynz←hz[dynsh]
    (⍳≢vm)≢dynobj:'Dynamic sections are not one per shared object'⎕SIGNAL 200
    16∨.≠he[dynsh]:'Unexpected dynamic entry size'⎕SIGNAL 200
    0∨.≠16|dynz:'Invalid dynamic section size'⎕SIGNAL 200

    dwords←(+/dcount←dynz÷16)4⍴323⎕DR∊(vx[dynobj]+hx[dynsh]+⍳¨dynz)(⊂⍛⌷)¨fb[vm[dynobj]]
    tag←dwords U64 0 ⋄ value←dwords U64 2 ⋄ down←dcount/⍳≢dcount
    (fh[dynobj]+hl[dynsh])∨.≠strsh:'Dynamic and dynamic symbol tables use different string tables'⎕SIGNAL 200

    NAMES←{owner←⍺ ⋄ offset←⍵ ⋄ 0=≢owner:⍬
        offset∨.≥strz[owner]:'Dynamic string offset outside string table'⎕SIGNAL 200
        at←strstart[owner]+offset ⋄ len←zeros[(zeros⍸at)+0≠strpool[at]]-at
        {strpool[at[⍵]+⍳len[⍵]]}¨⍳≢at}

    sr←⍸tag=14
    vm≠⍥≢sr:'Expected one SONAME per shared object'⎕SIGNAL 200
    sowner←dynobj[down[sr]]
    (⍳≢vm)≢sowner:'SONAME entries are not one per shared object'⎕SIGNAL 200
    soname←sowner NAMES value[sr]

    ((obj[keep])name(sb/⍨keep)(st/⍨keep)(sy/⍨keep)(sv/⍨keep)(sz/⍨keep))soname}

⍝ Decode the initial object and shared object views.
DECODE←{fb direct shared←⍵
    files h←1 0 0 ELF fb direct
    sharedfiles sharedh←{
        0=≢⊃shared:(fb shared ⍬ ⍬)(11⍴⊂⍬)
        3 0 0 ELF fb shared
    }⍬
    ds soname←DSYMBOLS sharedfiles sharedh
    files h ds soname}

⍝ Decode padded decimal field from an archive member header.
AR∆DEC←{d←⍵~32
    ∨/~d∊48+⍳10:('Invalid ',⍺)⎕SIGNAL 200
    10⊥d-48}

⍝ Decode GNU archive symbol indexes.
⍝ [a]rchive view: [m]ap offset-[x] si[z]e [t]hin
AR∆INDEX←{archives files←⍵ ⋄ (am ax az at)←archives ⋄ (fb _ _ _)←files
    keep←az≠8
    (am ax az at)←keep∘/¨am ax az at
    ar←⎕NS⍬ ⋄ ar.names←⎕NS⍬
    ar.names.(length rows bytes id)←⊂⍬ ⋄ ar.names.count←0
    ar.(map off thin longx longz member symbol first)←⊂⍬
    ar.nmember←0
    0=≢am:ar
    ∨/az<68:'Archive is too small for its symbol index'⎕SIGNAL 200

    mh←↑{(⊃fb[am[⍵]])[ax[⍵]+8+⍳60]}¨⍳≢am
    47∨.≠mh[;0]:'Archive has no symbol index'⎕SIGNAL 200
    ∨/~mh[;1]∊32 47:'Invalid archive symbol index member'⎕SIGNAL 200
    ∨/~mh[;58 59]∧.=96 10:'Invalid archive member header'⎕SIGNAL 200

    size←'archive member size'∘AR∆DEC¨↓mh[;48+⍳10]
    data←ax+68
    ∨/size>az-68:'Archive symbol index outside archive view'⎕SIGNAL 200

    next←data+2 ALIGN size ⋄ limit←ax+az
    lh←↑{60↑(⊃fb[am[⍵]])[next[⍵]+⍳0⌈60⌊limit[⍵]-next[⍵]]}¨⍳≢am
    long←lh[;0 1]∧.=47 47
    z←'archive long name table size'∘AR∆DEC¨↓long⌿lh[;48+⍳10]
    longz←z@{long}⊢am≢⍛⍴0
    longx←next+60
    ∨/long∧(longz>limit-longx):'Archive long name table outside archive'⎕SIGNAL 200
    longx←¯1@{~long}⊢longx

    ⍝ The GNU/SysV index begins with big-endian u32 count.
    count←{256⊥256|(⊃fb[am[⍵]])[data[⍵]+⍳4]}¨⍳≢am
    ∨/size<4+4×count:'Invalid archive symbol index'⎕SIGNAL 200

    member←U32 323⎕DR,⌽(+/count)4⍴∊{(⊃fb[am[⍵]])[data[⍵]+4+⍳4×count[⍵]]}¨⍳≢am
    owner←count/⍳≢am ⋄ namez←size-(4+4×count)
    pools←{(⊃fb[am[⍵]])[(data[⍵]+4+4×count[⍵])+⍳namez[⍵]]}¨⍳≢am ⋄ pool←∊pools ⋄ poolstart←(+\-⊢)namez
    zeros←∊{z←⍸0=⊃pools[⍵]
        count[⍵]>≢z:'Archive symbol index count does not match its names'⎕SIGNAL 200
        poolstart[⍵]+count[⍵]↑z
    }¨⍳≢am
    head←≠owner ⋄ start←1+¯1,¯1↓zeros ⋄ start[⍸head]←poolstart[head/owner] ⋄ len←zeros-start
    ∨/member≠⍥≢start:'Archive symbol index count does not match its names'⎕SIGNAL 200

    ⍝ Bucket names by length for major cell lookup without enclosed vectors.
    length←∪len ⋄ rows←{⍸len=⍵}¨length
    name←{r←⊃rows[⍵] ⋄ index←,start[r]∘.+⍳length[⍵] ⋄ ((≢r),length[⍵])⍴pool[index]}¨⍳≢length
    origin←{m←⊃name[⍵] ⋄ m⍳m}¨⍳≢length
    uniq←{(⍳≢⍵)=⍵}¨origin ⋄ unique←+/¨uniq ⋄ number←{¯1++\⍵}¨uniq
    base←(+\-⊢)unique
    indexed←len≢⍛⍴0 ⋄ _←{indexed[⊃rows[⍵]]←base[⍵]+(⊃number[⍵])[⊃origin[⍵]] ⋄ ⍬}¨⍳≢length
    name←{(⊃uniq[⍵])⌿⊃name[⍵]}¨⍳≢length ⋄ id←{base[⍵]+⍳unique[⍵]}¨⍳≢length
    ar.names.(length rows bytes id count)←length rows name id(+/unique)
    off←ax[owner]+member ⋄ key←off+(1+⌈/¯1,off)×am[owner]
    members←∪key ⋄ recordmember←members⍳key
    lead←≠indexed ⋄ firstrow←(+/unique)⍴≢indexed ⋄ firstrow[lead/indexed]←lead/⍳≢indexed
    ar.(map off thin longx longz member symbol first)←am[owner]off(at[owner])(longx[owner])(longz[owner])recordmember indexed firstrow
    ar.nmember←≢members ⋄ ar}

⍝ Map object symbol name slices into the archive index name.
SLICEIDS←{ar files slices←⍵ ⋄ (pool at len)←slices
    length rows name id←ar.names.(length rows bytes id)
    0=≢length:len≢⍛⍴¯1
    result←len≢⍛⍴¯1
    order←⍸len>0 ⋄ order←order[⍋len[order]] ⋄ sorted←len[order] ⋄ present←∪sorted ⋄ bylength←sorted{⊂⍵}⌸order
    _←{i←⍵ ⋄ r←⊃bylength[present⍳length[i]]
        matrix←((≢r),length[i])⍴pool[,at[r]∘.+⍳length[i]]
        hit←(⊃name[i])⍳matrix ⋄ found←hit<≢⊃id[i]
        result[found/r]←(⊃id[i])[found/hit] ⋄ ⍬}¨⍸length∊present
    result}

⍝ Decode selected archive members into ELF views, mapping thin members as needed.
AR∆DEC∆MEMBERS←{ar paths files rows←⍵ ⋄ (fb _ _ _)←files
    am ax at alx alz←ar.(map off thin longx longz)
    thin←at[rows] ⋄ lx←alx[rows] ⋄ lz←alz[rows]
    map←am[rows] ⋄ off←ax[rows] ⋄ limit←≢¨fb[map]
    ∨/(off>limit)∨(60>limit-off):'Archive member header outside archive'⎕SIGNAL 200

    mh←(≢rows)60⍴0
    _←{r←⍸map=⍵ ⋄ index←,off[r]∘.+⍳60
        mh[r;]←(≢r)60⍴(⊃fb[⍵])[index] ⋄ ⍬}¨∪map
    ∨/~mh[;58 59]∧.=96 10:'Invalid archive member header'⎕SIGNAL 200

    size←'archive member size'∘AR∆DEC¨↓mh[;48+⍳10]
    data←off+60
    ∨/(~thin)∧(size>limit-data):'Archive member data outside archive'⎕SIGNAL 200

    tr←⍸thin
    memberpaths←{i←⍵ ⋄ field←mh[i;⍳16] ⋄ field←field/⍨field≠32
        0=≢field:'Empty thin archive member name'⎕SIGNAL 200

        bytes←{
            47≠⊃field:{
                47≠⊃¯1↑field:'Invalid thin archive member name'⎕SIGNAL 200
                ¯1↓field}⍬

            digits←1↓field
            (0=≢digits)∨∨/~digits∊48+⍳10:'Invalid thin archive long-name reference'⎕SIGNAL 200
            ¯1=lx[i]:'Thin archive has no long name table'⎕SIGNAL 200

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
    (map data(data+size))newfb
}

⍝ Select the archive members required by unresolved symbol name IDs.
AR∆SELECT←{ar paths files need picked←⍵
    recordmember indexed firstrow←ar.(member symbol first)
    am←ar.map
    0=≢am:(⍬ ⍬ ⍬)⍬ picked

    ⍝ Preserve unresolved symbol order while using dense archive name IDs.
    rows←firstrow[need] ⋄ rows←rows/⍨rows<≢indexed
    rows←rows/⍨~picked[recordmember[rows]]
    0=≢rows:(⍬ ⍬ ⍬)⍬ picked

    ⍝ Several symbols can select the same archive member
    rows←(≠indexed[rows])/rows
    member←recordmember[rows] ⋄ distinct←≠member ⋄ rows←distinct/rows ⋄ member←distinct/member
    unseen←~picked[member] ⋄ rows←unseen/rows ⋄ member←unseen/member
    0=≢rows:(⍬ ⍬ ⍬)⍬ picked
    picked[member]←1

    views newfb←AR∆DEC∆MEMBERS ar paths files rows
    views newfb picked
}

⍝ Select archive members reachable from unresolved strong symbols.
AR∆MEMBERS←{ar paths files h←⍵
    (h s slices)←0 0 SYMBOLS files h

    a←⎕NS⍬ ⋄ a.files←files
    (sn sb st so ss sv sz)←s ⋄ strong←sb=1
    ⍝ sid: object symbol row → archive-name ID, or ¯1.
    sid←SLICEIDS ar files slices ⋄ a.defined←ar.names.count⍴0
    ids←(strong∧(ss≠¯1))/sid ⋄ a.defined[(0≤ids)/ids]←1
    a.need←∪(strong∧(ss=¯1)∧(sid≥0))/sid ⋄ a.need←a.need/⍨~a.defined[a.need]
    a.(hpart spart slicepart idpart)←(,⊂h)(,⊂s)(,⊂slices)(,⊂sid)
    a.hbase←≢⊃h ⋄ a.views←⍬ ⍬ ⍬ ⋄ a.picked←ar.nmember⍴0

    a←{a←⍵
        ⍝ Select all members named by the frontier. None means fixed point.
        (a.views newfb a.picked)←AR∆SELECT ar paths a.files a.need a.picked
        0=≢⊃a.views:a

        ⍝ Map and decode the newly selected members as one object batch.
        (ofb ov ofh ofn)←a.files ⋄ fb←ofb,newfb
        (ovm ovx ove)←ov ⋄ vbase←≢ovm
        (nfiles nh)←1 vbase a.hbase ELF fb a.views
        (nfb nv nfh nfn)←nfiles ⋄ (nvm nvx nve)←nv
        fv←(ovm,nvm)(ovx,nvx)(ove,nve) ⋄ a.files←fb fv(ofh,nfh)(ofn,nfn)

        sbase←+/≢¨0⊃¨a.spart
        (nh ns nn)←sbase a.hbase SYMBOLS a.files nh
        (nsn nsb nst nsy nss nsv nsz)←ns
        a.hpart,←⊂nh ⋄ a.spart,←⊂ns ⋄ a.slicepart,←⊂nn
        a.hbase+←≢⊃nh

        ⍝ New definitions close names. New undefined symbols extend the frontier.
        nstrong←nsb=1 ⋄ nid←SLICEIDS ar nfiles nn ⋄ a.idpart,←⊂nid
        ids←(nstrong∧(nss≠¯1))/nid ⋄ a.defined[(0≤ids)/ids]←1
        unresolved←(nstrong∧(nss=¯1)∧(nid≥0))/nid ⋄ a.need←∪a.need,unresolved
        a.need←a.need/⍨~a.defined[a.need]
        a
    }⍣{0=≢⊃⍺.views}⊢a

    h←⊃¨,/¨↓⍉↑a.hpart ⋄ s←⊃¨,/¨↓⍉↑a.spart
    pools←0⊃¨a.slicepart
    slices←(∊pools)(∊((+\-⊢)≢¨pools)+¨1⊃¨a.slicepart)(∊2⊃¨a.slicepart)
    a.files h s slices(∊a.idpart)}

⍝ Intern object, DSO, archive and synthetic names.
⍝ Equal byte strings receive one ID. Names aren't decoded as text.
INTERN←{ar slices sid s ds←⍵
    (sn sb st sy ss sv sz)←s ⋄ (dm dn db dt dy dv dz)←ds
    (pool oat olen)←slices ⋄ x←dn,SPECIAL∆NAME ⋄ xlen←≢¨x
    alen amat aid anids←ar.names.(length bytes id count)

    (nbase nbytes objectid xid)←{
        known←x≢⍛⍴¯1
        ⍝ Reuse IDs already assigned by archive symbol indices.
        _←{0=anids:⍬ ⋄ _←{i←⍵ ⋄ q←⍸xlen=alen[i] ⋄ hit←(⊃amat[i])⍳((≢q),alen[i])⍴∊x[q]
            found←hit<≢⊃aid[i] ⋄ known[found/q]←(⊃aid[i])[found/hit] ⋄ ⍬}¨⍳≢alen ⋄ ⍬}⍬

        ⍝ Equal-width matrices make byte string interning data parallel.
        sr←⍸(sid<0)∧olen>0 ⋄ xr←⍸known<0 ⋄ length←∪olen[sr],xlen[xr]
        GROUPS←{value rows←⍵ ⋄ 0=≢rows:length≢⍛⍴⊂⍬
            p←⍋value[rows] ⋄ sorted←value[rows[p]] ⋄ present←∪sorted ⋄ group←sorted{⊂⍵}⌸rows[p]
            lookup←(1+⌈/0,length)⍴¯1 ⋄ lookup[present]←⍳≢present
            ((⊂⍬),group)[1+lookup[length]]}
        srows←GROUPS olen sr ⋄ xrows←GROUPS xlen xr

        buckets←{i←⍵ ⋄ r←⊃srows[i] ⋄ q←⊃xrows[i] ⋄ width←length[i]
            matrix←((≢r),width)⍴pool[,oat[r]∘.+⍳width]
            matrix⍪←((≢q),width)⍴∊x[q]
            origin←matrix⍳matrix ⋄ first←(⍳≢matrix)=origin
            (first⌿matrix)(¯1+(+\first)[origin])(≢r)}¨⍳≢length
        bytes←0⊃¨buckets ⋄ base←anids+(+\-⊢)≢¨bytes
        oid←sid ⋄ id←known
        _←{r←⊃srows[⍵] ⋄ q←⊃xrows[⍵] ⋄ all←base[⍵]+1⊃⊃buckets[⍵]
            oid[r]←r≢⍛↑all ⋄ id[q]←q≢⍛↑(≢r)↓all ⋄ ⍬}¨⍳≢length
        ⍝ Preserve the archive names first, then append newly interned names.
        abase abytes←{0=anids:⍬ ⍬ ⋄ (⊃¨aid)({(≠⊃aid[⍵])⌿⊃amat[⍵]}¨⍳≢alen)}⍬
        (abase,base)(abytes,bytes)oid id
    }⍬

    nd←≢dn ⋄ sn←objectid ⋄ dn←nd↑xid ⋄ specialid←nd↓xid
    n←⎕NS⍬ ⋄ n.(count base bytes special)←(+/≢¨nbytes)nbase nbytes specialid
    (sn sb st sy ss sv sz)(dm dn db dt dy dv dz)n}

⍝ Select one definition of each COMDAT group and rewrite discarded symbols.
COMDAT←{files h s←⍵
    (hn ht hf hm hx hz ha he hl hi hb)←h ⋄(fb fv fh fn)←files ⋄ (vm vx ve)←fv ⋄ (sn sb st sy ss sv sz)←s
    keep←ht≢⍛⍴1
    gsh←⍸ht=17 ⋄ gobj←hm[gsh] ⋄ goff←hx[gsh] ⋄ glen←hz[gsh]
    ∨/(glen<4)∨0≠4|glen:'Invalid SHT_GROUP size'⎕SIGNAL 200

    first←(+\-⊢)length←1+count←¯1+glen÷4
    words←323⎕DR∊(vx[gobj]+goff+⍳¨glen)(⊂⍛⌷)¨fb[vm[gobj]]
    ∨/words[first]≠1:'Unsupported section group flags'⎕SIGNAL 200

    mem←(~1@first⊢words≢⍛⍴0)/words ⋄ owner←count/⍳≢gsh
    ∨/~∧/(0<mem)∧mem<fn[gobj[owner]]: 'Invalid section group member'⎕SIGNAL 200

    gsymsh←fh[gobj]+hl[gsh]
    ∨/¯1=hb[gsymsh]: 'SHT_GROUP does not reference a symbol table'⎕SIGNAL 200

    lose←~≠sn[hb[gsymsh]+hi[gsh]]
    keep[lose/gsh]←0 ⋄ keep[(lose[owner])/mem+fh[gobj[owner]]]←0

    ss←¯1@(rows/⍨~keep[ss[rows←⍸ss≥0]])⊢ss
    (sn sb st sy ss sv sz)keep
}

⍝ Decode the relocations belonging to retained object sections.
⍝ [r]elocation: target-[h]eader offset-[x] [s]ymbol [t]ype [a]ddend [k]ind
RELOCATIONS←{files h keep←⍵ ⋄ (hn ht hf hm hx hz ha he hl hi hb)←h ⋄ (fb fv fh fn)←files ⋄ (vm vx ve)←fv
    relash←⍸ht=4 ⋄ target←fh[hm[relash]]+hi[relash] ⋄ relash←(keep[relash]∧keep[target])/relash
    relaobj←hm[relash] ⋄ relax←hx[relash] ⋄ relaz←hz[relash]
    count←relaz÷24
    ∨/24≠he[relash]:'Unexpected RELA entry size'⎕SIGNAL 200
    ∨/0≠24|relaz:'Unexpected RELA section size'⎕SIGNAL 200

    map←vm[relaobj] ⋄ src←vx[relaobj]+relax ⋄ dst←(+\-⊢)relaz ⋄ raw←(+/relaz)⍴0
    _←{0=≢map:⍬ ⋄ _←{r←⍸map=⍵ ⋄ z←relaz[r] ⋄ at←(+\-⊢)z ⋄ batch←⌊at÷2*20
        _←{q←(batch=⍵)/r ⋄ n←relaz[q] ⋄ base←(+\-⊢)n ⋄ i←⍳+/n
            raw[i+n/dst[q]-base]←(⊃fb[map[⊃q]])[i+n/src[q]-base] ⋄ ⍬}¨∪batch ⋄ ⍬}¨∪map ⋄ ⍬}⍬
    words←(+/count)6⍴323⎕DR raw
    rx←words U64 0 ⋄ rt←U32 words[;2] ⋄ ra←words S64 4
    own←count/⍳≢count ⋄ rh←(fh[relaobj]+hi[relash])[own]

    symsh←fh[relaobj]+hl[relash] ⋄ base←hb[symsh]
    ∨/¯1=base:'RELA does not reference a symbol table'⎕SIGNAL 200
    rs←base[own]+U32 words[;3]
    rh rx rs rt ra
}

⍝ Discover the complete object set and discard parsing-only representations.
⍝ Returns f: mapped files ⋄ h: sections ⋄ s: symbols ⋄ ds: DSO symbols ⋄ r: relocations.
OBJECTS←{(paths archives files h ds)←⍵
    ar←AR∆INDEX archives files
    (files h s slices sid)←AR∆MEMBERS ar paths files h
    (s ds n)←INTERN ar slices sid s ds
    (s seckeep)←COMDAT files h s
    r←RELOCATIONS files h seckeep

    ⍝ Discard dead COMDAT sections once and globalise every surviving section reference.
    ⍝ secid: original section row → retained section row.
    secid←¯1++\seckeep
    (sn sb st sy ss sv sz)←s ⋄ ss←{secid[⍵]}@{⍵≥0}⊢ss ⋄ s←sn sb st sy ss sv sz
    (rh rx rs rt ra)←r ⋄ rh←secid[rh] ⋄ r←rh rx rs rt ra
    h←seckeep∘/¨h

    ⍝ After parsing is complete normalize every section to a mapped file and absolute offset.
    (fb fv _ _)←files ⋄ (vm vx ve)←fv
    (hn ht hf hm hx hz ha he hl hi hb)←h
    hx←vx[hm]+hx ⋄ hm←vm[hm] ⋄ h←hn ht hf hm hx hz ha he hl hi hb ⋄ f←fb
    f h s ds r n
}

⍝ Allocate and normalize COMMON symbols in NOBITS section.
COMMONS←{h s def byname←⍵
    (hn ht hf hm hx hz ha he hl hi hb)←h ⋄ (sn sb st sy ss sv sz)←s
    com←ss=¯3 ⋄ ext←sb∊1 2

    ⍝ Allocate selected common definitions inside one synthetic NOBITS section.
    cdef←def/⍨com[def] ⋄ crow←⍸ext∧com
    cid←sn[cdef]⍳sn[crow]
    cid←(keep←cid<≢cdef)/cid ⋄ crow←keep/crow ⋄ ids←∪cid
    cz←(cid{⌈/⍵}⌸sz[crow])@ids⊢cdef≢⍛⍴0
    ca←(cid{⌈/⍵}⌸sv[crow])@ids⊢cdef≢⍛⍴1
    local←⍸com∧~ext ⋄ nc←≢cdef
    _ coff comsize←0 LAYOUT((nc+≢local)⍴0)(cz,sz[local])(ca,sv[local])

    ⍝ UND and ABS are zero address pseudo sections; COMMON is ordinary BSS.
    hund habs hcom←(≢ht)+⍳3
    ss[⍸ss=¯2]←habs
    rows←⍸com∧ext ⋄ chosen←byname[sn[rows]] ⋄ ci←sn[cdef]⍳sn[chosen]
    common←ci<≢cdef
    ss[common/rows]←hcom ⋄ sv[common/rows]←coff[common/ci]
    ss[(~common)/rows]←ss[(~common)/chosen] ⋄ sv[(~common)/rows]←sv[(~common)/chosen]
    ss[local]←hcom ⋄ sv[local]←nc↓coff

    h←(hn,0 0 0 ⋄ ht,0 0 8 ⋄ hf,0 0 3 ⋄ hm,0 0 0 ⋄ hx,0 0 0
       hz,0 0 comsize ⋄ ha,1 1(1⌈⌈/1,ca) ⋄ he,0 0 0 ⋄ hl,0 0 0 ⋄ hi,0 0 0 ⋄ hb,¯1 ¯1 ¯1)
    h(sn sb st sy ss sv sz)
}

⍝ Resolve symbols and replace special section indices by real section rows.
⍝ Extends s with (DSO dynsym PLT GOT TLS), then redirects every relocation once.
RESOLVE←{n h s ds r←⍵ ⋄ (rh rx rs rt ra)←r
    (hn ht hf hm hx hz ha he hl hi hb)←h
    (sn sb st sy ss sv sz)←s ⋄ (dm dn db dt dy dv dz)←ds

    reg←ss≥0 ⋄ abs←ss=¯2 ⋄ com←ss=¯3
    weak←sb=2 ⋄ strong←sb=1 ⋄ ext←strong∨weak
    defd←reg∨abs∨com
    gotdef←sn=(n.special)[SPECIAL∆GOT]
    ∨/~≠(strong∧defd∧~com)/sn:'Multiple strong symbol definitions'⎕SIGNAL 200

    def←⍸ext∧defd ⋄ def←def[⍋com[def]+2×weak[def]] ⋄ def←(≠sn[def])/def

    ⍝ byname: interned name ID → selected object definition, or none.
    none←≢sn ⋄ byname←def@(sn[def])⊢n.count⍴none

    ⍝ Resolve external symbol rows against objects, then DSOs.
    urow←⍸ext∧~defd ⋄ local←byname[sn[urow]] ⋄ drow←dn⍳sn[urow]
    imp←(local=none)∧(drow<≢dn) ⋄ required←gotdef[urow]⍱(weak[urow]∧0=sy[urow])
    ∨/(local=none)∧(~imp)∧required:'Undefined symbol'⎕SIGNAL 200

    ⍝ Deduplicate imports in first occurrence order.
    isym←imp/urow ⋄ idrow←imp/drow
    in←∪sn[isym] ⋄ ii←in⍳sn[isym]
    idrow←idrow[ii⍳⍳≢in]
    ib im it iy iz←(db[idrow])(dm[idrow])(dt[idrow])(dy[idrow])(dz[idrow])

    ⍝ Begin the symbol row redirection map with appended import rows.
    ns←≢sn ⋄ irow←1+ns+⍳≢in ⋄ redirect←irow[ii]@isym⊢⍳ns

    ⍝ redirect: original symbol row → object, import, or zero row.
    use←~gotdef[urow]
    ∨/st[(use∧local≠none)/local]=10:'GNU IFUNC relocation is not supported yet'⎕SIGNAL 200
    target←local ⋄ target[⍸imp]←redirect[imp/urow]
    redirect[use/urow]←use/target ⋄ rdef←redirect[rs]

    ⍝ Identify entry point
    startsym←byname[(n.special)[SPECIAL∆START]]
    startsym=none:'Undefined symbol: _start'⎕SIGNAL 200

    ⍝ Normalize COMMON and append the three synthetic section rows.
    (h s)←COMMONS h s def byname
    (sn sb st sy ss sv sz)←s ⋄ hund←(≢⊃h)-3

    ⍝ Redirect undefined rows to their local definition or the UND pseudo row.
    found←local≠none
    ss[found/urow]←ss[found/local] ⋄ sv[found/urow]←sv[found/local]
    ss[(~found)/urow]←hund ⋄ sv[(~found)/urow]←0
    undef←ss=¯1 ⋄ ss[⍸undef]←hund ⋄ sv[⍸undef]←0

    ⍝ Append imports once, in relation order.
    count←1+ns+≢in ⋄ nn←n.count
    s←(sn,nn,in ⋄ sb,0,ib ⋄ st,0,it ⋄ sy,0,iy ⋄ ss,hund,in≢⍛⍴hund
       sv,(1+≢in)⍴0 ⋄ sz,0,iz ⋄ ((1+ns)⍴¯1),im ⋄ ((1+ns)⍴¯1),1+⍳≢in
       count⍴¯1 ⋄ count⍴¯1 ⋄ count⍴¯1)
    r←rh rx rdef rt ra
    h s r startsym
}

⍝ Assign each referenced symbol its PLT, GOT, or TLS descriptor slot.
⍝ Extended [s]ymbol: DSO-[m]ap dynsym-[i]ndex [p]LT [g]OT TLS-inde[x] [a]ddress
SLOTS←{o h s r←⍵ ⋄ (hn ht hf hm hx hz ha he hl hi hb)←h
    (sn sb st sy ss sv sz sm si sp sg sx)←s ⋄ (rh rx rs rt ra)←r
    backed←(ht≠SHT∆NOBITS)∧2|⌊hf÷SHF∆ALLOC ⋄ live←backed[rh] ⋄ imported←sm[rs]≥0 ⋄ gottypes←9 41 42

    use←live∧imported
    ∨/use∧~(rt∊1 4 19,gottypes):'Unsupported dynamic relocation type'⎕SIGNAL 200

    plt←∪rs/⍨use∧(rt=4) ⋄ gi←∪rs/⍨use∧rt∊gottypes
    gl←∪rs/⍨live∧(~imported)∧rt∊gottypes
    gd←∪rs/⍨use∧(rt=19) ⋄ hasld←∨/live∧rt=20

    rk←rt≢⍛⍴0 ⋄ rk[⍸use∧(rt=1)]←1 ⋄ rk[⍸o.pie∧live∧(~imported)∧(rt=1)]←2 ⋄ rk[⍸live∧(rt=20)]←3

    sp[plt]←⍳≢plt
    sg[gi]←(≢plt)+⍳≢gi
    sg[gl]←(≢plt)+(≢gi)+⍳≢gl
    sx[gd]←hasld+⍳≢gd
    (sn sb st sy ss sv sz sm si sp sg sx)(rh rx rs rt ra rk)
}

⍝ Build dynamic tables and their final sizes.
DYNAMIC←{o shared optional soname h s r n←⍵ ⋄ special←n.special
    name←{b←n.base⍸⍵ ⋄ (⊃n.bytes[b])[⍵-n.base[b];]}
    (sn sb st sy ss sv sz sm si sp sg sx)←s ⋄ (hn ht hf hm hx hz ha he hl hi hb)←h
    (rh rx rs rt ra rk)←r ⋄ (fm fx fz)←shared
    d←⎕NS⍬

    imp←⍸sm≥0 ⋄ used←(⍳≢fm)∊sm[imp] ⋄ keep←used∨~optional[fm]
    strings←(name¨sn[imp]),keep/soname ⋄ x←1+(+\-⊢)len←1+≢¨strings
    ix←imp≢⍛↑x ⋄ d.need←(≢imp)↓x ⋄ d.str←0,∊(,∘0)¨strings
    ni←≢imp ⋄ at←24+24×⍳ni
    info←st[imp]+16×sb[imp] ⋄ info←info-256×info≥128
    d.sym←(8SB sz[imp])@(,at∘.+16+⍳8)⊢info@(at+4)⊢(4SB ix)@(,at∘.+⍳4)⊢(24×1+ni)⍴0

    und abs←(≢ht)-3 2
    defined←(~ss∊und abs)/sn
    hasinit hasfini←special[SPECIAL∆INIT SPECIAL∆FINI]∊defined
    nlife←hasinit+hasfini+2×(∨/ht=SHT∆INITARRAY)+(∨/ht=SHT∆FINIARRAY)
    nplt←+/sp≥0 ⋄ nglob←+/(sg≥0)∧sm≥0 ⋄ nlocal←+/(sg≥0)∧sm<0
    ngd←+/sx≥0 ⋄ ntlsdesc←(∨/rk=3)+ngd
    local←(sg≥0)∧(sm<0)∧(ss≠und)
    nrela←nglob+(o.pie×+/local)+(+/rk=1)+(+/rk=2)+ntlsdesc+ngd

    d.emit←∨/keep
    d.interp←83⎕DR o.interp,⎕UCS 0
    d.hash←4SB 1 ndynsym(×ni),(2+⍳0⌈ni-1)@(1+⍳0⌈ni-1)⊢0⍴⍨ndynsym←1+ni

    ⍝ d.size follows the GEN∆ section arena.
    d.size←(≢d.interp)(16×nplt)(≢d.hash)(≢d.sym)(≢d.str)(24×nplt)(24×nrela)
    d.size,←(8×nplt+nglob+nlocal+2×ntlsdesc)(16×12+nlife+(3××nrela)+≢d.need)
    d}

⍝ Assign output slices to allocatable input and generated sections.
IMAGE←{o d special h s startsym←⍵
    im←⎕NS⍬
    base←4194304×~o.pie
    (hn ht hf hm hx hz ha he hl hi hb)←h ⋄ (sn sb st sy ss sv sz sm si sp sg sx)←s
    gensize←(d.emit)/d.size

    alloc←2|⌊hf÷SHF∆ALLOC ⋄ secs←⍸alloc ⋄ flags←hf[secs] ⋄ type←ht[secs]
    secz←hz[secs] ⋄ seca←1⌈ha[secs]

    write←2|⌊flags÷SHF∆WRITE ⋄ exec←2|⌊flags÷SHF∆EXEC
    ∨/write∧exec:'Writable executable sections are not supported'⎕SIGNAL 200
    ∨/~seca∊2*⍳63:'Unsupported section alignment'⎕SIGNAL 200

    ⍝ Every allocatable input and generated section becomes one layout item.
    nobits←type=SHT∆NOBITS ⋄ tls←2|⌊flags÷SHF∆TLS
    group←KIND∆TEXT+write+2×~exec
    types←SHT∆INIT SHT∆FINI SHT∆INITARRAY SHT∆FINIARRAY
    kinds←KIND∆INIT KIND∆FINI KIND∆INITARRAY KIND∆FINIARRAY
    rows←⍸type∊types ⋄ group[rows]←kinds[types⍳type[rows]]
    rows←⍸nobits ⋄ group[rows]←KIND∆BSS-tls[rows]
    group[⍸tls∧~nobits]←KIND∆TDATA
    group,←(d.emit)/GEN∆KIND ⋄ size←secz,gensize ⋄ align←seca,(d.emit)/GEN∆ALIGN

    ⍝ Output group determines both stable section order and PT_LOAD class.
    seg←KIND∆SEG[group] ⍝ RX=0, R=1, RW=2
    class←0 1 2∩(0<size)/seg ⋄ hastls←∨/group∊KIND∆TDATA KIND∆TBSS
    hdrsz←64+56×1+(≢class)+(3×d.emit)+hastls ⋄ lalign←4096∘⌈@({⊃⍸seg=⍵}¨class)⊢align

    ⍝ LAYOUT assigns every item one file-relative slice.
    (_ rel _)←hdrsz LAYOUT group size lalign ⋄ nsec←≢secs
    secrel←nsec↑rel ⋄ genrel←nsec↓rel

    filesec←(~nobits)/secs
    foff←(~nobits)/secrel

    shoff←foff@filesec⊢ht≢⍛⍴¯1
    shaddr←(base+secrel)@secs⊢ht≢⍛⍴0

    symaddr←shaddr[ss]+sv
    symaddr[⍸sn=special[SPECIAL∆GOT]]←base+GEN∆GOT⊃9↑genrel,9⍴0 ⋄ symaddr,←0

    im.(sec group size align rel)←secs group size align rel
    im.(entry off addr)←(symaddr[startsym])genrel(base+genrel)
    h←hn ht hf hm hx hz ha he hl hi hb shoff shaddr
    s←sn sb st sy ss sv sz sm si sp sg sx symaddr
    h s im
}

⍝ Derive section and program headers from final section coordinates.
HEADERS←{o d h im←⍵
    sh←⎕NS⍬ ⋄ base←4194304×~o.pie
    (hn ht hf hm hx hz ha he hl hi hb ho hv)←h
    secs allgroup size align rel←im.(sec group size align rel)
    nsec←≢secs ⋄ group←nsec↑allgroup ⋄ secz←nsec↑size ⋄ seca←nsec↑align ⋄ secrel←nsec↑rel
    gensize←nsec↓size ⋄ genalign←nsec↓align ⋄ genrel←nsec↓rel ⋄ nobits←ht[secs]=SHT∆NOBITS

    seg←KIND∆SEG[allgroup]
    class←0 1 2∩(0<size)/seg ⋄ hastls←∨/allgroup∊KIND∆TDATA KIND∆TBSS
    hdrsz←64+56×1+(≢class)+(3×d.emit)+hastls

    ⍝ Each run of input groups becomes one output section.
    regular←⍋group ⋄ g←group[regular] ⋄ x←secrel[regular]
    zsize←secz[regular] ⋄ zalign←seca[regular]
    first←2≠/¯1,g ⋄ last←2≠/g,¯1 ⋄ groups←first/g
    secoff←first/x ⋄ secsz←secoff-⍨last/x+zsize ⋄ secalign←g{⌈/⍵}⌸zalign ⋄ secaddr←base+secoff
    sectype←KIND∆TYPE[groups] ⋄ secflags←KIND∆FLAGS[groups]
    seclink←groups≢⍛⍴0 ⋄ secinfo←groups≢⍛⍴0
    secentsize←KIND∆ENTSIZE[groups] ⋄ secnames←KIND∆NAME[groups]

    ⍝ Append generated sections and their cross-references.
    dsndx←4+≢groups ⋄ dstrndx←5+≢groups
    secoff,←genrel ⋄ secaddr,←base+genrel ⋄ secsz,←gensize ⋄ secalign,←genalign
    sectype,←(d.emit)/GEN∆TYPE ⋄ secflags,←(d.emit)/GEN∆FLAGS
    seclink,←(d.emit)/0 0 dsndx dstrndx 0 dsndx dsndx 0 dstrndx
    secinfo,←(d.emit)/0 0 0 1 0(8+≢groups)0 0 0 ⋄ secentsize,←(d.emit)/GEN∆ENTSIZE ⋄ secnames,←(d.emit)/GEN∆NAME

    names←secnames,⊂'.shstrtab' ⋄ nameoff←1+(+\-⊢)len←1+≢¨names
    sh.str←z,∊names,¨z←⎕UCS 0 ⋄ secname←¯1↓nameoff ⋄ sh.name←⊃⌽nameoff
    filesz←⌈/hdrsz,((~nobits)/secrel+secz),genrel+gensize
    sh.stroff←filesz ⋄ sh.offset←8ALIGN sh.stroff+≢sh.str
    sh.count←2+≢secnames ⋄ sh.strindex←1+≢secnames
    sh.rows←secname sectype secflags secaddr secoff secsz secalign seclink secinfo secentsize
    im.size←sh.offset+64×sh.count

    ⍝ PT_LOAD extents are a projection of the same layout rows.
    span←{m←seg=⍵ ⋄ x←⌊/m/rel
        fz←(⌈/x,(m∧~(allgroup∊KIND∆TBSS KIND∆BSS))/(rel+size))-x
        mz←(⌈/m/(rel+size))-x ⋄ x fz mz}¨class
    px←0,0⊃¨span ⋄ pz←hdrsz,1⊃¨span ⋄ pm←hdrsz,2⊃¨span ⋄ pv←base+px
    pt←px≢⍛⍴1 ⋄ pf←4,5 4 6[class] ⋄ pa←px≢⍛⍴4096
    dynph←{~d.emit:8⍴⊂⍬
        x←genrel[GEN∆INTERP GEN∆DYNAMIC] ⋄ z←gensize[GEN∆INTERP GEN∆DYNAMIC]
        (3 2)(4 6)x(base+x)(base+x)z z(1 8)}⍬
    ph←(pt pf px pv pv pz pm pa),¨dynph
    tlsph←{~hastls:8⍴⊂⍬
        m←allgroup∊KIND∆TDATA KIND∆TBSS ⋄ fz←(⌈/x,(allgroup=KIND∆TDATA)/rel+size)-x←⌊/m/rel
        mz←(⌈/m/rel+size)-x ⋄ a←⌈/m/align
        (,7)(,4)(,x)(,base+x)(,base+x)(,fz)(,mz)(,a)
    }⍬
    ph←ph,¨tlsph
    phdr←{~d.emit:8⍴⊂⍬
        z←56×1+≢⊃ph
        (,6)(,4)(,64)(,base+64)(,base+64)(,z)(,z)(,8)}⍬
    ph←phdr,¨ph ⍝ [p]rogram header: [t]ype [f]lags offset-[x] [v]addr [p]addr file-si[z]e [m]emsz [a]lign
    im sh ph
}

⍝ Write resulting image.
WRITE←{o f h s r special d im sh ph←⍵
    out←im.size OUT∆INIT o.out

    ⍝ Coalesce adjacent input ranges and copy in bounded batches.
    _←{f h←⍵
        (hn ht hf hm hx hz ha he hl hi hb ho hv)←h
        rows←⍸(ho≥0)∧(ht≠SHT∆NOBITS) ⋄ fm←hm[rows] ⋄ fx←hx[rows] ⋄ fz←hz[rows] ⋄ ox←ho[rows]
        keep←fz>0 ⋄ (fm fx fz ox)←keep∘/¨fm fx fz ox
        join←((1↓fm)=¯1↓fm)∧((1↓fx)=¯1↓fx+fz)∧(1↓ox)=¯1↓ox+fz
        first←⍸1,~join ⋄ last←⍸(~join),1
        fm←fm[first] ⋄ fx←fx[first] ⋄ fz←ox[last]+fz[last]-ox[first] ⋄ ox←ox[first]
        chunksz←2*19 ⋄ small←fz≤chunksz
        order←⍋ox
        ∨/(1↓ox[order])<¯1↓ox[order]+fz[order]:'Overlapping input section copy'⎕SIGNAL 200
        _←{r←⍸small∧(fm=⍵) ⋄ start←(+\-⊢)fz[r] ⋄ batch←⌊start÷chunksz
            _←{q←r/⍨batch=⍵ ⋄ z←fz[q] ⋄ at←(+\-⊢)z ⋄ i←⍳+/z
                out[i+z/ox[q]-at]←(⊃f[fm[⊃q]])[i+z/fx[q]-at]
            ⍬}¨∪batch
        ⍬}¨∪small/fm
        _←{row←⍵ ⋄ n←fz[row]
            pos←chunksz×⍳⌈n÷chunksz ⋄ obj←⊃f[fm[row]]
            _←{p←⍵ ⋄ k←chunksz⌊n-p ⋄ i←⍳k
                out[ox[row]+p+i]←obj[fx[row]+p+i]
            ⍬}¨pos
        ⍬}¨⍸~small
    ⍬}f h

    ⍝ Write generated dynamic sections at slices given by IMAGE.
    _←{o h s r special d im←⍵
        ~d.emit:⍬
        dx da←im.(off addr)
        (rh rx rs rt ra rk)←r ⋄ (hn ht hf hm hx hz ha he hl hi hb ho hv)←h ⋄ (sn sb st sy ss sv sz sm si sp sg sx sa)←s

        _←GEN∆INTERP GEN∆HASH GEN∆SYM GEN∆STR{out[dx[⍺]+⍳≢⍵]←⍵ ⋄ ⍬}¨d.interp d.hash d.sym d.str

        order←{q←⍸⍵≥0 ⋄ q[⍋⍵[q]]}
        pltrow←order sp ⋄ gotrow←order sg
        gi←gotrow/⍨sm[gotrow]≥0 ⋄ gl←gotrow/⍨sm[gotrow]<0 ⋄ gd←order sx
        sym rel←(⍸rk=1)(⍸rk=2) ⋄ hasld←∨/rk=3
        und abs←(≢ht)-3 2
        row←{q←⍸(~ss∊und abs)∧sn=⍵ ⋄ ⊃q,¯1}
        init fini←(row special[SPECIAL∆INIT])(row special[SPECIAL∆FINI])
        isec fsec←(⍸ht=SHT∆INITARRAY)(⍸ht=SHT∆FINIARRAY)

        nplt←≢pltrow ⋄ nglob←≢gi ⋄ nlocal←≢gl ⋄ ngd←≢gd ⋄ ntlsdesc←hasld+ngd
        pltaddr←da[GEN∆PLT]+16×⍳nplt ⋄ gotaddr←da[GEN∆GOT]+8×⍳nplt+nglob+nlocal
        pltgotaddr←gotaddr[sp[pltrow]] ⋄ globaddr←gotaddr[sg[gi]] ⋄ localaddr←gotaddr[sg[gl]]
        local←ss[gl]≠und
        tlsdescaddr←da[GEN∆GOT]+8×(nplt+nglob+nlocal)+16×⍳ntlsdesc ⋄ tlsgdaddr←tlsdescaddr[sx[gd]]

        ⍝ Construct TLS dynamic relocations
        tlsdynoffset←tlsdescaddr,tlsgdaddr+8
        tlsdyninfo←16+(2*32)×(hasld/0),si[gd] ⋄ tlsdyninfo,←17+(2*32)×si[gd]

        ⍝ PLT entries are jmp *disp32(%rip) followed by padding.
        at←16×⍳nplt
        plt← (4SB pltgotaddr-pltaddr+6)@(,at∘.+2+⍳4)⊢37@(at+1)⊢¯1@at⊢¯112⍴⍨16×nplt

        info←7+(2*32)×si[pltrow]
        relaplt←RELA (⊂pltgotaddr),(⊂info),⊂nplt⍴0
        globinfo←6+(2*32)×si[gi] ⋄ symbolinfo←1+(2*32)×si[rs[sym]]

        off←tlsdynoffset,globaddr,(o.pie/(local/localaddr)),(hv[rh[sym]]+rx[sym]),hv[rh[rel]]+rx[rel]
        info←tlsdyninfo,globinfo,(8⍴⍨o.pie×+/local),symbolinfo,rel≢⍛⍴8
        add←(tlsdynoffset≢⍛⍴0),(nglob⍴0),(o.pie/(local/sa[gl])),ra[sym],sa[rs[rel]]+ra[rel]
        dynrela←RELA(⊂off),(⊂info),⊂add

        got←(0⍴⍨8×nplt+nglob),(8SB sa[gl]×~o.pie),0⍴⍨16×ntlsdesc

        out[dx[GEN∆PLT]+⍳≢plt]←plt ⋄ out[dx[GEN∆RPLT]+⍳≢relaplt]←relaplt
        out[dx[GEN∆RELA]+⍳≢dynrela]←dynrela ⋄ out[dx[GEN∆GOT]+⍳≢got]←got

        range←{0=≢⍵:0 0 ⋄ start((⌈/x+hz[⍵])-start←⌊/x←hv[⍵])}
        initarray←range isec ⋄ finiarray←range fsec
        hasinit←init≥0 ⋄ hasfini←fini≥0 ⋄ hasinitarray←×≢isec ⋄ hasfiniarray←×≢fsec
        lifetags←(hasinit/12),(hasfini/13),(hasinitarray/25 27),hasfiniarray/26 28
        lifevalues←(hasinit/sa[0⌈init]),(hasfini/sa[0⌈fini]),(hasinitarray/initarray),hasfiniarray/finiarray

        hasrela←×≢dynrela
        tags←(d.need≢⍛⍴1),4 5 6 10 11 3 2 20 23,(hasrela/7 8 9),lifetags,30 1879048187 0
        values←d.need,da[GEN∆HASH GEN∆STR GEN∆SYM],(≢d.str),24,da[GEN∆GOT],(≢relaplt),7,da[GEN∆RPLT],(hasrela/da[GEN∆RELA](≢dynrela)24),lifevalues,8 1 0

        at←16×⍳≢tags
        dyntab←d.size[GEN∆DYNAMIC]⍴0
        dyntab[,at∘.+⍳8]←8SB tags ⋄ dyntab[,at∘.+8+⍳8]←8SB values
        out[dx[GEN∆DYNAMIC]+⍳≢dyntab]←dyntab
    ⍬}o h s r special d im

    ⍝ Apply relocations, batched by encoded width.
    _←{o h s r im←⍵
        (hn ht hf hm hx hz ha he hl hi hb ho hv)←h ⋄ (sn sb st sy ss sv sz sm si sp sg sx sa)←s ⋄ (rh rx rs rt ra rk)←r
        dx da←im.(off addr) ⋄ da←9↑da,9⍴0

        rr←⍸0≤ho[rh] ⋄ type←rt[rr] ⋄ gottypes←9 41 42
        ∨/~type∊1 2 4 9 19 20 21 41 42:'Unsupported relocation type'⎕SIGNAL 200

        tlsbase←{0=≢⍵:0 ⋄ ⌊/hv[⍵]}⍸(0≤ho)∧2|⌊hf÷SHF∆TLS
        nplt←+/sp≥0 ⋄ nglob←+/(sg≥0)∧sm≥0 ⋄ nlocal←+/(sg≥0)∧sm<0
        ngd←+/sx≥0 ⋄ hasld←∨/rk=3 ⋄ ntlsdesc←hasld+ngd
        tlsdescaddr←da[GEN∆GOT]+8×(nplt+nglob+nlocal)+16×⍳ntlsdesc ⋄ tlsldaddr←hasld×⊃tlsdescaddr,0

        batchbytes←2*20 ⍝ avoid large allocation for temporary arrays.
        _←{w←⍵
            rows←⍸(8 4[type≠1])=w ⋄ count←≢rows ⋄ span←⌈batchbytes÷1⌈w
            _←{first←⍵×span ⋄ q←rr[rows[first+⍳span⌊count-first]]
                kind←rt[q] ⋄ target←rh[q] ⋄ offset←rx[q] ⋄ targetz←hz[target]
                ∨/(offset>targetz)∨w>targetz-offset:'Relocation target outside section'⎕SIGNAL 200
                where←ho[target]+offset ⋄ sym←rs[q] ⋄ S←sa[sym] ⋄ imported←sm[sym]≥0
                pltref←⍸imported∧(kind=4) ⋄ gotref←⍸kind∊gottypes
                tlsldref←⍸kind=20 ⋄ tlsgdref←⍸kind=19 ⋄ dtpoffref←⍸kind=21
                S[pltref]←da[GEN∆PLT]+16×sp[sym[pltref]]
                S[gotref]←da[GEN∆GOT]+8×sg[sym[gotref]]
                S[tlsldref]←tlsldaddr ⋄ S[tlsgdref]←tlsdescaddr[sx[sym[tlsgdref]]] ⋄ S[dtpoffref]←sa[sym[dtpoffref]]-tlsbase
                value←S+ra[q]-(hv[target]+offset)×kind∊2 4 9 19 20 41 42
                ∨/(w=4)∧((value<-2*31)∨value≥2*31):'Relocation value overflow'⎕SIGNAL 200
                bytes←⊖(w⍴256)⊤value
                out[(⍳w)∘.+where]←bytes-256×bytes≥128
            ⍬}¨⍳⌈count÷span
        ⍬}¨∪8 4[type≠1]
    ⍬}o h s r im

    ⍝ Serialize ELF and its program and section metadata.
    _←{o im sh ph←⍵
        secname sectype secflags secaddr secoff secsz secalign seclink secinfo secentsize←sh.rows

        ⍝ The remaining writes are metadata.
        out[⍳64+56×≢⊃ph]←{(pt pf px pv pp pz pm pa)←ph
            ∊(ELF∆IDENT∆EXP,7⍴0 ⋄ 2SB(2+o.pie)62 ⋄ 4SB 1 ⋄ 8SB im.entry 64 sh.offset ⋄ 4SB 0
              2SB 64 56(≢pt)64 sh.count sh.strindex ⋄ ∊,/4 4 8 8 8 8 8 8(SB⍤0)¨ph)
        }⍬

        out[sh.stroff+⍳≢sh.str]←83⎕DR sh.str

        out[sh.offset+⍳64×sh.count]←∊,/4 4 8 8 8 8 4 4 8 8(SB⍤0)¨(
            0,secname,sh.name ⋄ 0,sectype,3
            0,secflags,0      ⋄ 0,secaddr,0 ⋄ 0,secoff,sh.stroff ⋄ 0,secsz,≢sh.str
            0,seclink,0       ⋄ 0,secinfo,0
            0,secalign,1      ⋄ 0,secentsize,0)

    ⍬}o im sh ph
    0≠2⊃⎕SHELL 'chmod' '+x' '--' o.out:('Cannot change output file to +x: ',o.out)⎕SIGNAL 200
    ⍝BREAK
    ⍬}
