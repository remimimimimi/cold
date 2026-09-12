	.weak sym_strong
	.weak sym_unique
	.weak sym_weak

	.data

	.type sym_strong, @object
	.type sym_unique, @object
	.type sym_weak, @object

	.size sym_strong, 4
	.size sym_unique, 4
	.size sym_weak, 4
sym_strong:
	.long 1
sym_unique:
	.long 2
sym_weak:
	.long 3
