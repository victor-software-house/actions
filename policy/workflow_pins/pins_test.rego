package workflow_pins_test

import data.workflow_fixtures as f
import data.workflow_pins
import rego.v1

# The pins rule reads the text texts.sh writes, beside the parsed workflow.
denied(text) := result if {
	result := workflow_pins.deny_pins with input as f.lines(text)
		with data.conftest.file as f.file
		with data.workflow_texts as {"ci.yml": text}
}

# A local action needs no pin.
test_valid_workflow_passes if count(denied(f.workflow)) == 0

test_tag_fails if {
	denied(f.edited_text("actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1", "actions/checkout@v7")) == {"line 16: uses actions/checkout@v7 must pin a commit SHA and name its release in a comment, such as @<sha> # v1.2.3"}
}

test_sha_without_comment_fails if {
	denied(f.edited_text(" # v7.0.1", "")) == {"line 16: uses actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 must pin a commit SHA and name its release in a comment, such as @<sha> # v1.2.3"}
}

test_branch_comment_needs_a_date if {
	denied(f.edited_text(" # main, 2026-11-02", " # main")) == {"line 26: uses org/actions/.github/workflows/rust-ci.yml@0123456789abcdef0123456789abcdef01234567 # main must pin a commit SHA and name its release in a comment, such as @<sha> # v1.2.3"}
}

# A line that ends in a backslash, which panics conftest's ignore parser, is
# read like any other line.
test_backslash_continuation_is_read if {
	denied(replace(f.workflow, "      - uses: ./.github/actions/setup", "      - uses: ./.github/actions/setup\n      - run: |\n          echo one \\\n            two")) == set()
}

test_missing_text_fails if {
	workflow_pins.deny_pins == {"the workflow's text is not loaded; pass policy/texts.sh's output with --data"} with input as f.lines(f.workflow)
		with data.conftest.file as f.file
		with data.workflow_texts as {}
}
