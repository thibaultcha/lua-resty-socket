.PHONY: test lint

test:
		@busted -v -o gtest
		@util/reindex t/*.t
		@prove

lint:
		@luacheck lib --std ngx_lua --no-redefined
