package workflow_drafts_test

import data.workflow_drafts
import data.workflow_fixtures as f
import rego.v1

denied(input_lines) := result if {
	result := workflow_drafts.deny_drafts with input as input_lines with data.conftest.file as f.file
}

test_valid_workflow_passes if count(denied(f.lines(f.workflow))) == 0

test_missing_type_fails if {
	denied(f.edited("reopened, ready_for_review", "reopened")) == {"pull_request types must list ready_for_review, so marking a draft ready starts the run"}
}

test_job_without_draft_skip_fails if {
	denied(f.edited("  changes:\n    if: ${{ !github.event.pull_request.draft }}\n", "  changes:\n")) == {
		"job changes must skip drafts with if: ${{ !github.event.pull_request.draft }}, or need a job that does",
		"job build must skip drafts with if: ${{ !github.event.pull_request.draft }}, or need a job that does",
	}
}

# A job that needs a job that skips drafts is skipped with it.
test_needs_a_skipping_job_passes if count(denied(f.edited("    needs: changes", "    needs: [changes]"))) == 0

# The short forms of `on` name pull_request with no types.
test_short_triggers_are_pull_requests if {
	count(denied(f.edited("on:\n  pull_request:\n    types: [opened, synchronize, reopened, ready_for_review]\n  merge_group:", "on: pull_request"))) == 4
	count(denied(f.edited("on:\n  pull_request:\n    types: [opened, synchronize, reopened, ready_for_review]\n  merge_group:", "on: [push, pull_request]"))) == 4
}

test_push_only_workflow_is_out_of_scope if {
	count(denied(f.edited("  pull_request:\n    types: [opened, synchronize, reopened, ready_for_review]\n", "  push:\n"))) == 0
}

test_exception_with_reason_applies if {
	ex := workflow_drafts.exception with input as f.edited("reopened, ready_for_review", "reopened")
		with data.conftest.file as f.file
		with data.workflow_exceptions.exceptions as {{"rule": "drafts", "file": "ci.yml", "reason": "a scheduled job"}}
	ex == {["drafts"]}
}

test_exception_needs_a_reason if {
	ex := workflow_drafts.exception with input as f.lines(f.workflow)
		with data.conftest.file as f.file
		with data.workflow_exceptions.exceptions as {{"rule": "drafts", "file": "ci.yml", "reason": " "}}
	count(ex) == 0
}

test_exception_names_its_file if {
	ex := workflow_drafts.exception with input as f.lines(f.workflow)
		with data.conftest.file as f.file
		with data.workflow_exceptions.exceptions as {{"rule": "drafts", "file": "release.yml", "reason": "tags only"}}
	count(ex) == 0
}
