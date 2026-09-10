⍝ Basic correctness tests
test_norela←{
    (expected object)←AssetPaths 'test_norela.elf.expected' 'test_norela_start.o'
    expected CheckOutput(⊂object)}

test_addend←{
    (expected object)←AssetPaths 'test_addend.elf.expected' 'test_addend_start.o'
    expected CheckOutput(⊂object)}
