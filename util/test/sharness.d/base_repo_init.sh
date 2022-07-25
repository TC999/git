#!/bin/bash

# Init the base bare repo
init_base_repo() {
	rm -rf base.git &&
	rm -rf tmp-repo &&
	git -c init.defaultBranch=master init --bare base.git &&
	git clone --no-local base.git tmp-repo &&
	(
		cd tmp-repo &&
		test_tick &&
		git commit -m "initial" --allow-empty &&
		git push origin master &&
		# prepare topic-template branch
		git checkout -b topic-template &&
		printf "feature1" >feature1 &&
		git add feature1 &&
		test_tick &&
		git commit -m "add feature1" &&
		printf "feature2" >feature2 &&
		git add feature2 &&
		test_tick &&
		git commit -m "add feature2" &&
		printf "feature3" >feature3 &&
		git add feature3 &&
		test_tick &&
		git commit -m "add feature3" &&
		git push origin topic-template --tags &&
		# Prepare master
		git checkout master &&
		printf "v2.36.1" >GIT-VERSION &&
		printf "6.5.8" >PATCH-VERSION &&
		touch topic.txt &&
		git add GIT-VERSION PATCH-VERSION topic.txt &&
		test_tick &&
		git commit -m "init patchwork base files" &&
		git push origin master topic-template &&
		git branch agit-master
	) &&
	rm -rf tmp-repo
}

# Create some topic features for test
init_base_topics(){
	git clone base.git tmp &&
	(
		cd tmp &&
		git checkout topic-template &&
		git tag v2.36.1 &&
		git branch topic/0001-feature1 topic-template &&
		git checkout topic/0001-feature1 &&
		printf "append new feature on topic/0001-feature1" >>feature1 &&
		mkdir -p t &&
		printf "test execute" >t/t0001-feature1.sh
		git add feature1 t/t0001-feature1.sh &&
		test_tick &&
		git commit -m "feature1 update" &&
		git push origin topic/0001-feature1 &&
		git branch topic/0002-feature2 topic-template &&
		git checkout topic/0002-feature2 &&
		printf "append new feature on topic/0002-feature2" >>feature2 &&
		printf "feature2 new file" >feature2.keep &&
		mkdir -p t/0002
		printf "subtest" >t/0002/t0002-subtest.sh
		print "root test" >t/t0002-feature2.sh
		git add feature2 feature2.keep t/0002/t0002-subtest.sh t/t0002-feature2.sh &&
		test_tick &&
		git commit -m "add feature2" &&
		git push origin topic/0002-feature2 &&
		git branch topic/0003-feature3 topic-template &&
		git checkout topic/0003-feature3 &&
		rm -rf feature3 &&
		printf "new files on feature3" >feature3.keep &&
		mkdir -p t &&
		printf "execute test file" >t/t0003-feature3.sh
		printf "the test lib file" >t/http-curl.sh
		git add feature3.keep t/t0003-feature3.sh t/http-curl.sh &&
		test_tick
		git commit -m "update feature3"
		git checkout master &&
		printf "feature1\nfeature2\nfeature3\n" >topic.txt &&
		git add topic.txt &&
		test_tick &&
		git commit -m "update topic.txt on master" &&
		git push origin master topic/0001-feature1 topic/0002-feature2 topic/0003-feature3 --tags
	) &&
	rm -rf tmp
}