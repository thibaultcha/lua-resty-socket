.PHONY: test

test:
		@util/reindex t/*.t
		@prove
