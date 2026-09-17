⍝ Integration tests
test_clang←{
    root←ProjectRoot⍬
    env←{s←1↓¨,⊂⍨1,<\⍤=⋄{⌽⍵/⍨∨\' '≠⍵}¨⍣2↑(2=≢¨)⍛/'='s¨⊃¨'#'s¨⍵}⊃⎕NGET(root,'/.env')1
    GET←{⊃⍺[⍺[;0]⍳⊂⍵;1]}
    build←env GET'LLVM_BUILD'
    dir←##.TMP_ROOT,'clang/' ⋄ _←3⎕MKDIR dir
    args←dir,'link.args' ⋄ clang←dir,'clang' ⋄ hello←dir,'hello'
    capture←root,'/tests/clang/capture-clang-link.sh'
    shim←root,'/tests/clang'

    cmd←'"',capture,'" "',build,'" "',args,'" "',clang,'" "',shim,'"'
    r←⎕SHELL cmd
    0 0≢r[2 3]:('Could not capture clang link: ',⍕r)⎕SIGNAL 11

    args←⊃⎕NGET args 1
    base←build,'/tools/clang/tools/driver/'
    args←(base∘,¨)@{⎕NEXISTS¨base∘,¨⍵}⊢args
    _←LNK args

    r←⎕SHELL '"',clang,'" "',root,'/tests/assets/hello.c" -o "',hello,'"'
    0 0≢r[2 3]:('Linked clang failed: ',⍕r)⎕SIGNAL 11

    r←⎕SHELL '"',hello,'"'
    0 0≢r[2 3]:('Clang compiled hello world failed: ',⍕r)⎕SIGNAL 11
    ⍬}
