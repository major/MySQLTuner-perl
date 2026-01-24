VERSION=$(shell grep '\- Version ' mysqltuner.pl | awk '{ print $$NF}')
UPDATE_SUB_VERSION=$(shell echo $(VERSION) | awk -F. '{ print $$1"."$$2"."$$3+1 }')
UPDATE_MINOR_VERSION=$(shell echo $(VERSION) | awk -F. '{ print $$1"."$$2+1".0" }')
UPDATE_MAJOR_VERSION=$(shell echo $(VERSION) | awk -F. '{ print $$1+1".0.0" }')

all: generate_cve generate_features generate_usage tidy increment_sub_version 

help:
	@echo "Usage: make <target>"
	@echo "  help:              Show this help"
	@echo "  generate_usage:    Generate USAGE.md"
	@echo "  generate_cve:      Generate vulnerabilities.csv"
	@echo "  generate_features: Generate FEATURES.md"
	@echo "  tidy:              Tidy mysqltuner.pl"
	@echo "  installdep_debian: Install dependencies on Debian"
	@echo "  increment_sub_version: Increment sub version"
	@echo "  increment_minor_version: Increment minor version"
	@echo "  increment_major_version: Increment major version"
	@echo "  push:              Push to GitHub"
	@echo "  vendor_setup:      Setup external test repositories (multi-db-docker-env, test_db)"
	@echo "  test:              Run database lab tests (mysql84, mariadb1011, percona80)"
	@echo "  test-all:          Run all database lab tests"
	@echo "  test-container:    Run tests against a specific CONTAINER (e.g. CONTAINER=my_db)"
	@echo "  audit:             Run audit on remote HOST (e.g. HOST=db-server.com)"
	@echo "  unit-tests:        Run unit and regression tests in tests/ directory"
	@echo "  clean_examples:    Cleanup examples directory (KEEP=n, default 5)"
	@echo "  setup_commits:     Install Conventional Commits tools (Node.js)"


installdep_debian: setup_commits
	sudo apt install -y cpanminus libfile-util-perl libpod-markdown-perl libwww-mechanize-gzip-perl perltidy dos2unix
	curl -sL https://raw.githubusercontent.com/slimtoolkit/slim/master/scripts/install-slim.sh | sudo -E bash -

setup_commits:
	@echo "Installing Conventional Commits tools..."
	npm install

tidy:
	dos2unix ./mysqltuner.pl
	perltidy -b ./mysqltuner.pl
	git add ./mysqltuner.pl
	git commit -m "Indenting mysqltuner at $(shell date --iso=seconds)"

generate_usage:
	pod2markdown mysqltuner.pl >USAGE.md
	git add ./USAGE.md
	git commit -m "Generate USAGE.md at $(shell date --iso=seconds)"

generate_cve:
	perl ./build/updateCVElist.pl
	git add ./vulnerabilities.csv
	git commit -m "Generate CVE list at $(shell date --iso=seconds)"

generate_version_file:
	rm -f CURRENT_VERSION.txt
	grep "# mysqltuner.pl - Version" ./mysqltuner.pl | awk '{ print $$NF}' > CURRENT_VERSION.txt
	git add ./CURRENT_VERSION.txt
	git commit -m "Generate CURRENT_VERSION.txt at $(shell date --iso=seconds)"

generate_eof_files:
	bash ./build/endoflife.sh mariadb 
	bash ./build/endoflife.sh mysql
	git add ./*_support.md
	git commit -m "Generate End Of Life (endoflive.date) at $(shell date --iso=seconds)" || echo "No changes to commit"

generate_features:
	perl ./build/genFeatures.sh
	git add ./FEATURES.md
	git commit -m "Generate FEATURES.md at $(shell date --iso=seconds)"

increment_sub_version:
	@echo "Incrementing sub version from $(VERSION) to $(UPDATE_SUB_VERSION)"
	sed -i "s/$(VERSION)/$(UPDATE_SUB_VERSION)/" mysqltuner.pl *.md .github/workflows/*.yml
	git add ./*.md ./mysqltuner.pl
	git commit -m "Generate $(UPDATE_SUB_VERSION) sub version at $(shell date --iso=seconds)"
	git tag -a v$(UPDATE_SUB_VERSION) -m "Generate $(UPDATE_SUB_VERSION) sub version at $(shell date --iso=seconds)"
	git push --tags

increment_minor_version:
	@echo "Incrementing minor version from $(VERSION) to $(UPDATE_MINOR_VERSION)"
	sed -i "s/$(VERSION)/$(UPDATE_MINOR_VERSION)/" mysqltuner.pl *.md .github/workflows/*.yml
	git add ./*.md ./mysqltuner.pl
	git commit -m "Generate $(UPDATE_MINOR_VERSION) minor version at $(shell date --iso=seconds)"
	git tag -a v$(UPDATE_MINOR_VERSION) -m "Generate $(UPDATE_MINOR_VERSION) minor version at $(shell date --iso=seconds)"
	git push --tags

increment_major_version:
	@echo "Incrementing major version from $(VERSION) to $(UPDATE_MAJOR_VERSION)"
	sed -i "s/$(VERSION)/$(UPDATE_MAJOR_VERSION)/" mysqltuner.pl *.md .github/workflows/*.yml
	git add ./*.md ./mysqltuner.pl
	git commit -m "Generate $(UPDATE_SUB_VERSION) major version at $(shell date --iso=seconds)"
	git tag -a v$(UPDATE_MINOR_VERSION) -m "Generate $(UPDATE_MAJOR_VERSION) major version at $(shell date --iso=seconds)"
	git push --tags

docker_build:
	docker build . -t jmrenouard/mysqltuner:latest -t jmrenouard/mysqltuner:$(VERSION)

docker_slim:
	docker run --rm -it --privileged -v /var/run/docker.sock:/var/run/docker.sock -v $(PWD):/root/app -w /root/app jmrenouard/mysqltuner:latest slim build

docker_push: docker_build
	bash build/publishtodockerhub.sh $(VERSION)
	

vendor_setup:
	@echo "Setting up vendor repositories..."
	mkdir -p vendor
	if [ ! -d "vendor/multi-db-docker-env" ]; then \
		git clone https://github.com/jmrenouard/multi-db-docker-env vendor/multi-db-docker-env; \
	else \
		cd vendor/multi-db-docker-env && git pull; \
	fi
	if [ ! -d "vendor/test_db" ]; then \
		git clone https://github.com/jmrenouard/test_db vendor/test_db; \
	else \
		cd vendor/test_db && git pull; \
	fi

test: vendor_setup
	@echo "Running MySQLTuner Lab Tests..."
	bash build/test_envs.sh $(CONFIGS)

test-all: vendor_setup
	@echo "Running all MySQLTuner Lab Tests..."
	bash build/test_envs.sh

test-container:
	@echo "Running MySQLTuner against container: $(CONTAINER)..."
	bash build/test_envs.sh -e "$(CONTAINER)"

audit:
	@echo "Running MySQLTuner Audit on host: $(HOST)..."
	bash build/test_envs.sh -r "$(HOST)" -a

unit-tests:
	@echo "Running unit and regression tests..."
	prove -r tests/

clean_examples:
	@echo "Cleaning up examples..."
	bash build/clean_examples.sh $(KEEP)

push:
	git push

pull:
	git pull
