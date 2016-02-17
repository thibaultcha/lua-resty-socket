.PHONY: test lint

test:
		@util/reindex t/*.t
		@prove

lint:
		@luacheck lib/ --std ngx_lua --no-redefined
