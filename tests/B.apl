⍝ Basic correctness tests
test_norela←{
    (expected object)←AssetPaths 'test_norela.elf.expected' 'test_norela_start.o'
    expected CheckOutput(⊂object)}
