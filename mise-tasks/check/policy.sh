#!/bin/sh
#MISE description="Every Rego package in policy/ passes its conftest verify --data policy/defaults.yaml tests"
conftest verify --data policy/defaults.yaml
