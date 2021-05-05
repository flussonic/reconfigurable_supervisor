

build:
	mkdir -p ebin
	erlc -o ebin src/reconfigurable_supervisor.erl
	cp -f src/reconfigurable_supervisor.app.src ebin/reconfigurable_supervisor.app

test: build
	mkdir -p log
	ct_run -pa ebin -logdir log

clean:
	find . -name '*.beam' -delete
	rm -rf ebin log

