build:
	@scripts/build.sh -p default

coverage:
	@scripts/coverage.sh

test:
	@scripts/test.sh -p default

deploy:
	@scripts/deploy.sh

format:
	@node scripts/align_fmt.js

check-format:
	@node scripts/align_fmt.js --check
