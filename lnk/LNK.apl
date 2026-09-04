⎕IO←0

PS∆ARGS←{args←⍵
    ∨/'-h' '--help'∊args:'There should be help printed'⎕SIGNAL 200
    ∨/'-v' '--version'∊args:'There should be version printed'⎕SIGNAL 200

    o←⎕NS⍬
    o.out←'a.out' ⋄ o.(input path lib)←⊂⍬ ⋄ o.(static pie)←0
    o.(root interp hashstyle buildid dependencyfile)←''

    m←args∊'-L' '-l' '-dynamic-linker' '-o'
    (m/args),←(m,0)/1⌽args,⊂'' ⋄ args←(~0,¯1↓m)/args

    o.(path lib)←'-L' '-l'{m←⍺∘≡¨(≢⍺)↑¨⍵ ⋄ (≢⍺)↓¨m/⍵}¨⊂args
    o.(interp out root hashstyle buildid dependencyfile){
        m←⍵∘≡¨(≢⍵)↑¨args ⋄ v←(≢⍵)↓¨m/args ⋄ ⊃¯1↑(⊂⍺),v
    }←'-dynamic-linker' '-o' '--sysroot=' '--hash-style=' '--build-id=' '--dependency-file='
    o.(static pie)←'-static' '-pie'∊args
    o.input←args/⍨'-'≠⊃¨args ⋄ o}

OUT∆INIT←{size←⍺ ⋄ file←⍵
    t←file ⎕NCREATE 0
    _←size ⎕NRESIZE t
    _←⎕NUNTIE t
    83 size ⎕MAP file 'W'}
