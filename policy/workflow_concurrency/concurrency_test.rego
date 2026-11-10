package workflow_concurrency_test

import data.workflow_concurrency
import data.workflow_fixtures as f
import rego.v1

# The merge queue group: every queue entry shares one group per base branch.
queue_ending := "${{ github.event_name == 'merge_group' && format('queue-{0}', github.event.merge_group.base_ref) || format('{0}-{1}{2}', github.event_name, github.event.pull_request.number || github.ref_name, github.event.pull_request.draft && '-draft' || '') }}"

ending_message := concat(", ", [
	"concurrency.group must end in one of: ${{ github.event.pull_request.number || github.ref_name }}",
	"${{ github.event.pull_request.number || github.ref_name }}${{ github.event.pull_request.draft && '-draft' || '' }}",
	queue_ending,
])

denied(input_lines) := result if {
	result := workflow_concurrency.deny_concurrency with input as input_lines with data.conftest.file as f.file
}

test_valid_workflow_passes if count(denied(f.lines(f.workflow))) == 0

test_group_per_commit_fails if {
	denied(f.edited("${{ github.event.pull_request.number || github.ref_name }}", "${{ github.sha }}")) == {ending_message}
}

test_no_cancel_fails if {
	denied(f.edited("  cancel-in-progress: true", "  cancel-in-progress: false")) == {`concurrency must set cancel-in-progress to one of: true, ${{ github.event_name == 'pull_request' }}, ${{ github.event_name != 'push' }}`}
}

test_missing_concurrency_fails if {
	count(denied(f.edited("concurrency:\n  group: ci-${{ github.workflow }}-${{ github.event_name }}-${{ github.event.pull_request.number || github.ref_name }}\n  cancel-in-progress: true\n", ""))) == 2
}

test_push_only_workflow_is_out_of_scope if {
	count(denied(f.edited("  pull_request:\n    types: [opened, synchronize, reopened, ready_for_review]\n", "  push:\n"))) == 0
}

test_key_must_come_last if {
	denied(f.edited("|| github.ref_name }}\n", "|| github.ref_name }}-${{ github.sha }}\n")) == {ending_message}
}

test_draft_suffix_passes if {
	count(denied(f.edited("|| github.ref_name }}\n", "|| github.ref_name }}${{ github.event.pull_request.draft && '-draft' || '' }}\n"))) == 0
}

test_anything_after_the_draft_suffix_fails if {
	denied(f.edited("|| github.ref_name }}\n", "|| github.ref_name }}${{ github.event.pull_request.draft && '-draft' || '' }}-${{ github.sha }}\n")) == {ending_message}
}

# Cancelling pull request runs only lets every push to main finish.
test_pull_request_only_cancel_passes if {
	count(denied(f.edited("  cancel-in-progress: true", "  cancel-in-progress: ${{ github.event_name == 'pull_request' }}"))) == 0
}

test_cancel_parameter_changes_the_result if {
	count(workflow_concurrency.deny_concurrency) == 1 with input as f.edited("  cancel-in-progress: true", "  cancel-in-progress: ${{ github.event_name == 'pull_request' }}")
		with data.conftest.file as f.file
		with data.workflow_policy as {"concurrency": {"cancel_in_progress": [true]}}
}

test_queue_group_passes if {
	count(denied(f.edited("${{ github.event_name }}-${{ github.event.pull_request.number || github.ref_name }}", queue_ending))) == 0
}

# Only the whole queue expression ends a group; its first branch alone does not.
test_queue_group_without_pull_request_branch_fails if {
	denied(f.edited("${{ github.event_name }}-${{ github.event.pull_request.number || github.ref_name }}", "${{ format('queue-{0}', github.event.merge_group.base_ref) }}")) == {ending_message}
}
