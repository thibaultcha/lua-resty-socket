.PHONY: test lint

test:
		@busted -v -o gtest spec
		@t/reindex t/*.t
		@prove

lint:
		@luacheck lib --std ngx_lua --no-redefined
