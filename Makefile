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


installdep_debian:
	sudo apt install -y cpanminus libpod-markdown-perl libwww-mechanize-gzip-perl perltidy dos2unix
	sudo cpanm File::Util
	curl -sL https://raw.githubusercontent.com/slimtoolkit/slim/master/scripts/install-slim.sh | sudo -E bash -

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

generate_eof_files:
	bash ./build/endoflife.sh mariadb 
	bash ./build/endoflife.sh mysql
	git add ./*_support.md
	git commit -m "Generate End Of Life (endoflive.date) at $(shell date --iso=seconds)"

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
	

push:
	git push

pull:
	git pull
