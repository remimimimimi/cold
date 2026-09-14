⍝ Basic correctness tests
AssertMatch←{⍺≢⍵:('Expected ',(⍕⍺),', got ',⍕⍵)⎕SIGNAL 11 ⋄ 1}

test_layout_empty←{
    expected←⍬ ⍬ 0
    expected AssertMatch LAYOUT ⍬ ⍬ ⍬}

test_layout_one←{
    expected←(,0)(,0)3
    expected AssertMatch LAYOUT(,0)(,3)(,1)}

test_layout_alignment←{
    expected←(0 1 2)(0 8 14)15
    expected AssertMatch LAYOUT(0 0 0)(3 6 1)(1 8 2)}

test_layout_stable_groups←{
    expected←(1 3 0 2)(8 0 12 4)13
    expected AssertMatch LAYOUT(1 0 1 0)(1 3 1 2)(8 1 4 4)}

test_layout_group_boundary_alignment←{
    expected←(0 2 1 3)(0 8 4 12)15
    expected AssertMatch LAYOUT(0 1 0 1)(3 2 1 3)(1 4 4 4)}

test_layout_many_groups←{
    group←3 0 4 1 2 0 3 4 1 2 0 4
    size←3 2 5 1 7 4 2 3 6 1 2 4
    align←2 1 8 4 2 8 1 4 16 1 2 8
    order←1 5 10 3 8 4 9 0 6 2 7 11
    offset←46 0 56 16 38 8 49 64 32 45 12 72
    (order offset 76)AssertMatch LAYOUT group size align}

test_layout_zero_sizes←{
    group←2 0 1 0 2 1
    size←0 0 3 2 1 0
    align←64 8 4 1 2 16
    order←1 3 2 5 0 4
    offset←64 0 16 0 64 32
    (order offset 65)AssertMatch LAYOUT group size align}

test_layout_one_group←{
    group←6⍴5
    size←1 1 1 1 1 1
    align←1 16 2 8 4 1
    expected←(⍳6)(0 16 18 24 28 29)30
    expected AssertMatch LAYOUT group size align}

test_layout_ordered_groups←{
    group←0 0 1 1 2 2 3 3
    size←2 3 4 5 6 7 8 9
    align←1 2 4 1 8 2 16 4
    expected←(⍳8)(0 2 8 12 24 30 48 56)65
    expected AssertMatch LAYOUT group size align}

test_layout_sparse_group_numbers←{
    group←1000 2 1000 17 2 17
    size←2 3 4 5 6 7
    align←8 4 1 16 2 4
    order←1 4 3 5 0 2
    offset←32 0 34 16 4 24
    (order offset 38)AssertMatch LAYOUT group size align}

test_norela←{
    (expected object)←AssetPaths 'test_norela.elf.expected' 'test_norela_start.o'
    expected CheckOutput object}

test_addend←{
    (expected object)←AssetPaths 'test_addend.elf.expected' 'test_addend_start.o'
    expected CheckOutput object}

test_symbols←{
    (expected start value)←AssetPaths 'test_symbols.elf.expected' 'test_symbols_start.o' 'test_symbols_value.o'
    expected CheckOutput start value}

test_weak←{
    (expected start weak strong unique)←AssetPaths 'test_weak.elf.expected' 'test_weak_start.o' 'test_weak_weak.o' 'test_weak_strong.o' 'test_weak_unique.o'
    expected CheckOutput start weak strong unique}

test_common←{
    (expected start a b)←AssetPaths 'test_common.elf.expected' 'test_common_start.o' 'test_common_a.o' 'test_common_b.o'
    expected CheckOutput start a b}

test_segments←{
    (expected object)←AssetPaths 'test_segments.elf.expected' 'test_segments_start.o'
    expected CheckOutput object}

test_comdat←{
    (expected start a b)←AssetPaths 'test_comdat.elf.expected' 'test_comdat_start.o' 'test_comdat_a.o' 'test_comdat_b.o'
    expected CheckOutput start a b}

test_archive←{
    archive←0 'test_archive.a' Archive 'test_archive_required.o' 'test_archive_unused.o'
    (expected start)←AssetPaths 'test_archive.elf.expected' 'test_archive_start.o'
    expected CheckOutput start archive}

test_archive_chain←{
    archive←0 'test_archive_chain.a' Archive 'test_archive_chain_first.o' 'test_archive_chain_second.o'
    (expected start)←AssetPaths 'test_archive_chain.elf.expected' 'test_archive_chain_start.o'
    expected CheckOutput start archive}

test_archive_lazy←{
    archive←0 'test_archive_lazy.a' Archive 'test_archive_required.o' 'test_archive_unused.s'
    (expected start)←AssetPaths 'test_archive_lazy.elf.expected' 'test_archive_start.o'
    expected CheckOutput start archive}

test_archive_thin←{
    archive←1 'test_archive_thin.a' Archive 'test_archive_required.o' 'test_archive_unused.s'
    (expected start)←AssetPaths 'test_archive_thin.elf.expected' 'test_archive_start.o'
    expected CheckOutput start archive}

test_archive_thin_chain←{
    archive←1 'test_archive_thin_chain.a' Archive 'test_archive_chain_first.o' 'test_archive_chain_second.o'
    (expected start)←AssetPaths 'test_archive_thin_chain.elf.expected' 'test_archive_chain_start.o'
    expected CheckOutput start archive}

test_archive_multi←{
    archive←0 'test_archive_multi.a' Archive 'test_archive_multi_member.o'
    (expected start)←AssetPaths 'test_archive_multi.elf.expected' 'test_archive_multi_start.o'
    expected CheckOutput start archive}

test_archive_duplicate←{
    archive←0 'test_archive_duplicate.a' Archive 'test_archive_duplicate.o' 'test_archive_duplicate.o'
    (expected start)←AssetPaths 'test_archive_duplicate.elf.expected' 'test_archive_start.o'
    expected CheckOutput start archive}

test_lib_static←{
    library←0 'libtest_lib_static.a' Archive 'test_archive_required.o'
    (expected start)←AssetPaths 'test_lib_static.elf.expected' 'test_archive_start.o'
    dir←⊃1⎕NPARTS library
    expected CheckOutput start '-static' ('-L',dir) '-ltest_lib_static'}
