package workflow_labels_test

import data.workflow_fixtures as f
import data.workflow_labels
import rego.v1

denied(input_lines, listed) := result if {
	result := workflow_labels.deny_labels with input as input_lines
		with data.conftest.file as f.file
		with data["self-hosted-runner"] as listed
}

test_valid_workflow_passes if count(denied(f.lines(f.workflow), f.labels)) == 0

test_unlisted_runs_on_fails if {
	denied(f.edited("    runs-on: nscloud-ubuntu-24.04-amd64-2x4", "    runs-on: nscloud-ubuntu-24.04-amd64-2x8"), f.labels) == {"job build runs on nscloud-ubuntu-24.04-amd64-2x8, which is not a GitHub-hosted runner and .github/actionlint.yaml does not list"}
}

test_unlisted_runner_input_fails if {
	denied(f.edited(`'["nscloud-ubuntu-24.04-amd64-4x8"]'`, `'["nscloud-ubuntu-24.04-amd64-8x16"]'`), f.labels) == {"job verify runs on nscloud-ubuntu-24.04-amd64-8x16, which is not a GitHub-hosted runner and .github/actionlint.yaml does not list"}
}

# A public repository's actionlint.yaml is {}: only hosted runners pass.
test_hosted_runner_needs_no_listing if {
	count(denied(f.edited("    runs-on: ubuntu-latest", "    runs-on: macos-latest"), {})) == 3
	denied(f.edited("    runs-on: ubuntu-latest", "    runs-on: macos-latest"), f.labels) == set()
}

# A larger hosted runner bills even on a public repository.
test_larger_hosted_runner_fails if {
	denied(f.edited("    runs-on: ubuntu-latest", "    runs-on: ubuntu-latest-8-cores"), f.labels) == {"job changes runs on ubuntu-latest-8-cores, which is not a GitHub-hosted runner and .github/actionlint.yaml does not list"}
}

test_expression_is_not_checked if count(denied(f.edited("    runs-on: ubuntu-latest", "    runs-on: ${{ matrix.os }}"), f.labels)) == 0

test_exception_applies if {
	ex := workflow_labels.exception with input as f.lines(f.workflow)
		with data.conftest.file as f.file
		with data.workflow_exceptions.exceptions as {{"rule": "labels", "file": "ci.yml", "reason": "a runner another organization provides"}}
	ex == {["labels"]}
}

test_runs_on_object_labels_are_checked if {
	denied(f.edited("    runs-on: nscloud-ubuntu-24.04-amd64-2x4", "    runs-on:\n      group: builders\n      labels: [nscloud-ubuntu-24.04-amd64-2x8]"), f.labels) == {"job build runs on nscloud-ubuntu-24.04-amd64-2x8, which is not a GitHub-hosted runner and .github/actionlint.yaml does not list"}
	count(denied(f.edited("    runs-on: nscloud-ubuntu-24.04-amd64-2x4", "    runs-on:\n      group: builders"), f.labels)) == 0
}
