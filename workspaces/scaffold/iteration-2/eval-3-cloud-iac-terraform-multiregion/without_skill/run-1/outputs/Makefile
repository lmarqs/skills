# Convenience wrapper around scripts/tf.sh.
#
# Pass the module via MODULE=<name>. Defaults to us-east-1.
#
# Examples:
#   make init   MODULE=us-east-1
#   make plan   MODULE=sa-east-1
#   make apply  MODULE=global
#   make fmt    MODULE=us-east-1
#   make check  MODULE=us-east-1

MODULE ?= us-east-1
TF      = ./scripts/tf.sh

.PHONY: init plan apply fmt check help

help:
	@echo "Usage: make <init|plan|apply|fmt|check> MODULE=<global|sa-east-1|us-east-1>"

init:
	$(TF) $(MODULE) init

plan:
	$(TF) $(MODULE) plan

apply:
	$(TF) $(MODULE) apply

fmt:
	$(TF) $(MODULE) fmt

check:
	$(TF) $(MODULE) check
