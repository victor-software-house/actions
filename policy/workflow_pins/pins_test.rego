package workflow_pins_test

import data.workflow_fixtures as f
import data.workflow_pins
import rego.v1

denied(input_lines) := result if {
	result := workflow_pins.deny_pins with input as input_lines with data.conftest.file as f.file
}

# A local action needs no pin.
test_valid_workflow_passes if count(denied(f.lines(f.workflow))) == 0

test_tag_fails if {
	denied(f.edited("actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1", "actions/checkout@v7")) == {"line 16: uses actions/checkout@v7 must pin a commit SHA and name its release in a comment, such as @<sha> # v1.2.3"}
}

test_sha_without_comment_fails if {
	denied(f.edited(" # v7.0.1", "")) == {"line 16: uses actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 must pin a commit SHA and name its release in a comment, such as @<sha> # v1.2.3"}
}

test_branch_comment_needs_a_date if {
	denied(f.edited(" # main, 2026-11-02", " # main")) == {"line 26: uses org/actions/.github/workflows/rust-ci.yml@0123456789abcdef0123456789abcdef01234567 # main must pin a commit SHA and name its release in a comment, such as @<sha> # v1.2.3"}
}

test_exception_applies if {
	ex := workflow_pins.exception with input as f.lines(f.workflow)
		with data.conftest.file as f.file
		with data.workflow_exceptions.exceptions as {{"rule": "pins", "file": "ci.yml", "reason": "a vendored action"}}
	ex == {["pins"]}
}
