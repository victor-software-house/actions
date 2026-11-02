package workflow_concurrency_test

import data.workflow_concurrency
import data.workflow_fixtures as f
import rego.v1

denied(input_lines) := result if {
	result := workflow_concurrency.deny_concurrency with input as input_lines with data.conftest.file as f.file
}

test_valid_workflow_passes if count(denied(f.lines(f.workflow))) == 0

test_group_per_commit_fails if {
	denied(f.edited("${{ github.event.pull_request.number || github.ref_name }}", "${{ github.sha }}")) == {"concurrency.group must end in ${{ github.event.pull_request.number || github.ref_name }}"}
}

test_no_cancel_fails if {
	denied(f.edited("  cancel-in-progress: true", "  cancel-in-progress: false")) == {"concurrency must set cancel-in-progress: true"}
}

test_missing_concurrency_fails if {
	count(denied(f.edited("concurrency:\n  group: ci-${{ github.workflow }}-${{ github.event_name }}-${{ github.event.pull_request.number || github.ref_name }}\n  cancel-in-progress: true\n", ""))) == 2
}

test_push_only_workflow_is_out_of_scope if {
	count(denied(f.edited("  pull_request:\n    types: [opened, synchronize, reopened, ready_for_review]\n", "  push:\n"))) == 0
}

test_exception_applies if {
	ex := workflow_concurrency.exception with input as f.lines(f.workflow)
		with data.conftest.file as f.file
		with data.workflow_exceptions.exceptions as {{"rule": "concurrency", "file": "ci.yml", "reason": "every run must finish"}}
	ex == {["concurrency"]}
}

test_key_must_come_last if {
	denied(f.edited("|| github.ref_name }}\n", "|| github.ref_name }}-${{ github.sha }}\n")) == {"concurrency.group must end in ${{ github.event.pull_request.number || github.ref_name }}"}
}
