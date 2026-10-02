.PHONY: install run bots dashboard test

install:
	npm install
	pip install -r requirements.txt

run:
	bash start.sh

bots:
	node bot/manager.js

dashboard:
	python3 server/server.py

test:
	node --check bot/main.js
	node --check bot/manager.js
	node --check bot/bal_tracker.js
	node --check bot/fish_detector.js
	node --check bot/logger.js
	python3 -c "import ast; ast.parse(open('server/server.py').read())"
	@echo "All syntax checks passed."
