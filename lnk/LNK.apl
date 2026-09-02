⎕IO←0

∇ o←PS∆ARGS args;NEXT;a;np;v
    NEXT←{0=≢⍵:('Missing value after ',⍺)⎕SIGNAL 11 ⋄ (⊃⍵)(1↓⍵)}

    o←⎕NS⍬
    o.out←'a.out' ⋄ o.root←'' ⋄ o.interp←''
    o.input o.path←2⍴⊂⍬
    o.static o.pie o.help o.version←4⍴0

    :While 0<≢args
        a←⊃args
        args←1↓args

        :If '-'≢⊃a
            o.input,←⊂a ⋄ :Continue
        :EndIf

        np←≢path

        :If (⊂a)∊'-h' '--help' ⋄ o.help←1
        :ElseIf (⊂a)∊'-v' '--version' ⋄ o.version←1
        :ElseIf a≡'--export-dynamic'
        :ElseIf a≡'--eh-frame-hdr'
        :ElseIf a≡'-static' ⋄ o.static←1
        :ElseIf a≡'-pie' ⋄ o.pie←1
        :ElseIf (⊂a)∊'--as-needed' '--no-as-needed'
        :ElseIf a≡'-o' ⋄ v args←a NEXT args ⋄ o.out←v
        :ElseIf a≡'-m' ⋄ v args←a NEXT args
            :If 'elf_x86_64'≢v
                'Invalid value for -m'⎕SIGNAL 11
            :EndIf
        :ElseIf a≡'-dynamic-linker' ⋄ v args←a NEXT args ⋄ o.interp←v
        :ElseIf a≡'-rpath-link' ⋄ v args←a NEXT args
        :ElseIf a≡'-rpath' ⋄ v args←a NEXT args
        :ElseIf a≡'-z' ⋄ v args←a NEXT args
            :If 'pack-relative-relocs'≢v
                'Unsupported value for -z'⎕SIGNAL 11
            :EndIf
        :ElseIf a≡'-L' ⋄ v args←a NEXT args ⋄ o.path,←⊂v
        :ElseIf '-L'≡2↑a ⋄ o.path,←⊂2↓a
        :ElseIf a≡'-l' ⋄ v args←a NEXT args ⋄ o.input,←⊂v static np root
        :ElseIf '-l'≡2↑a ⋄ o.input,←(2↓a)static np root
        :Else
            sysroot←'--sysroot='
            hashstyle←'--hash-style='
            buildid←'--build-id='
            depfile←'--dependency-file='

            :If sysroot≡(≢sysroot)↑a
                v←(≢sysroot)↓a
                :If 0=≢v
                    'Missing value for --sysroot='⎕SIGNAL 11
                :EndIf
                root←v
            :ElseIf hashstyle≡(≢hashstyle)↑a
                v←(≢hashstyle)↓a
                :If 0=≢v
                    'Missing value for --hash-style='⎕SIGNAL 11
                :EndIf
                :If 'gnu'≢v
                    'We don''t support hash style other than gnu'⎕SIGNAL 11
                :EndIf
            :ElseIf buildid≡(≢buildid)↑a
                :If 0=≢(≢buildid)↓a
                    'Missing value for --build-id='⎕SIGNAL 11
                :EndIf
            :ElseIf depfile≡(≢depfile)↑a
                :If 0=≢(≢depfile)↓a
                    'Missing value for --dependency-file='⎕SIGNAL 11
                :EndIf
            :ElseIf a≡'--build-id'
            :ElseIf '-'=⊃a
                ('Unknown option: ',a)⎕SIGNAL 11
            :Else
                o.input,←⊂a
            :EndIf
        :EndIf
    :EndWhile
∇
