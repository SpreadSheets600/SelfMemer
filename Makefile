.PHONY: install run dev test

install:
	npm install
	pip install flask

run:
	bash start.sh

dev:
	python3 -c "from selfmemer import *" 2>/dev/null || true
	@echo "Use: npm start"

test:
	node --check main.js
	node --check manager.js
	node --check bal_tracker.js
	node --check fish_detector.js
	python3 -c "import ast; ast.parse(open('server.py').read())"
	@echo "All syntax checks passed."
