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
	count(denied(f.edited("    runs-on: ubuntu-26.04", "    runs-on: macos-latest"), {})) == 3
	denied(f.edited("    runs-on: ubuntu-26.04", "    runs-on: macos-latest"), f.labels) == set()
}

# Ubuntu 26.04 is the only standard hosted Ubuntu, on both architectures.
test_ubuntu_26_needs_no_listing if {
	denied(f.lines(f.workflow), f.labels) == set()
	denied(f.edited("    runs-on: ubuntu-26.04", "    runs-on: ubuntu-26.04-arm"), f.labels) == set()
}

# ubuntu-latest still means 24.04, so it and every older image are refused.
test_superseded_ubuntu_fails if {
	every label in ["ubuntu-latest", "ubuntu-24.04", "ubuntu-22.04", "ubuntu-24.04-arm", "ubuntu-22.04-arm"] {
		denied(f.edited("    runs-on: ubuntu-26.04", concat("", ["    runs-on: ", label])), f.labels) == {sprintf("job changes runs on %s; GitHub-hosted Ubuntu runners must be ubuntu-26.04 or ubuntu-26.04-arm", [label])}
	}
}

# A larger hosted runner bills even on a public repository.
test_larger_hosted_runner_fails if {
	denied(f.edited("    runs-on: ubuntu-26.04", "    runs-on: ubuntu-latest-8-cores"), f.labels) == {"job changes runs on ubuntu-latest-8-cores, which is not a GitHub-hosted runner and .github/actionlint.yaml does not list"}
}

test_expression_is_not_checked if count(denied(f.edited("    runs-on: ubuntu-26.04", "    runs-on: ${{ matrix.os }}"), f.labels)) == 0

test_runs_on_object_labels_are_checked if {
	denied(f.edited("    runs-on: nscloud-ubuntu-24.04-amd64-2x4", "    runs-on:\n      group: builders\n      labels: [nscloud-ubuntu-24.04-amd64-2x8]"), f.labels) == {"job build runs on nscloud-ubuntu-24.04-amd64-2x8, which is not a GitHub-hosted runner and .github/actionlint.yaml does not list"}
	count(denied(f.edited("    runs-on: nscloud-ubuntu-24.04-amd64-2x4", "    runs-on:\n      group: builders"), f.labels)) == 0
}

# macOS 27 is the xcode-27 preview image, a standard hosted runner.
test_xcode_27_needs_no_listing if {
	denied(f.edited("    runs-on: ubuntu-26.04", "    runs-on: xcode-27"), f.labels) == set()
}
