⎕IO←0

PS_ARGS←{args←⍵
    ∨/'-h' '--help'∊args:'There should be help printed'⎕SIGNAL 200
    ∨/'-v' '--version'∊args:'There should be version printed'⎕SIGNAL 200

    o←⎕NS⍬
    o.out←'a.out' ⋄ o.root←'' ⋄ o.interp←''
    o.hashstyle←'' ⋄ o.buildid←'' ⋄ o.dependencyfile←''
    o.input o.path o.lib←3⍴⊂⍬ ⋄ o.static o.pie←2⍴0

    m←args∊'-L' '-l' '-dynamic-linker' '-o'
    (m/args),←(m,0)/1⌽args,⊂'' ⋄ args←(~0,¯1↓m)/args

    o.path o.lib←'-L' '-l'{m←⍺∘≡¨(≢⍺)↑¨⍵ ⋄ (≢⍺)↓¨m/⍵}¨⊂args
    o.interp o.out o.root o.hashstyle o.buildid o.dependencyfile←o.interp o.out o.root o.hashstyle o.buildid o.dependencyfile{
        m←⍵∘≡¨(≢⍵)↑¨args ⋄ v←(≢⍵)↓¨m/args ⋄ ⊃¯1↑(⊂⍺),v
    }¨'-dynamic-linker' '-o' '--sysroot=' '--hash-style=' '--build-id=' '--dependency-file='
    o.(static pie)←'-static' '-pie'∊args
    o.input←(~{⊃'-'⍷⍵}¨args)/args ⋄ o}
