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

test_job_gated_to_another_event_passes if {
	count(denied(f.edited("  changes:\n    if: ${{ !github.event.pull_request.draft }}\n", "  changes:\n    if: github.event_name == 'schedule'\n"))) == 0
}

test_job_gated_with_or_still_needs_the_skip if {
	count(denied(f.edited("  changes:\n    if: ${{ !github.event.pull_request.draft }}\n", "  changes:\n    if: github.event_name == 'schedule' || github.event_name == 'pull_request'\n"))) == 2
}

test_job_gated_to_pull_request_still_needs_the_skip if {
	count(denied(f.edited("  changes:\n    if: ${{ !github.event.pull_request.draft }}\n", "  changes:\n    if: github.event_name == 'pull_request'\n"))) == 2
}

test_status_function_overrides_the_skip if {
	denied(f.edited("    needs: changes", "    needs: changes\n    if: ${{ always() }}")) == {"job build must skip drafts with if: ${{ !github.event.pull_request.draft }}, or need a job that does"}
	count(denied(f.edited("  changes:\n    if: ${{ !github.event.pull_request.draft }}\n", "  changes:\n    if: ${{ !github.event.pull_request.draft || always() }}\n"))) == 2
}

test_chain_of_needs_passes if {
	chain := f.edited("    needs: changes", "    needs: changes\n  deploy:\n    needs: build\n    runs-on: ubuntu-latest\n    steps:\n      - run: true\n  build-two:\n    needs: changes")
	count(denied(chain)) == 0
}

test_pull_request_target_still_needs_the_skip if {
	count(denied(f.edited("  changes:\n    if: ${{ !github.event.pull_request.draft }}\n", "  changes:\n    if: github.event_name == 'pull_request_target'\n"))) == 2
}

test_negated_gate_still_needs_the_skip if {
	count(denied(f.edited("  changes:\n    if: ${{ !github.event.pull_request.draft }}\n", "  changes:\n    if: ${{ !(github.event_name == 'schedule') }}\n"))) == 2
}

test_chain_without_a_skipper_fails if {
	chain := f.edited("  changes:\n    if: ${{ !github.event.pull_request.draft }}\n", "  changes:\n  deploy:\n    needs: build\n    runs-on: ubuntu-latest\n    steps:\n      - run: true\n")
	denied(chain) == {
		"job changes must skip drafts with if: ${{ !github.event.pull_request.draft }}, or need a job that does",
		"job build must skip drafts with if: ${{ !github.event.pull_request.draft }}, or need a job that does",
		"job deploy must skip drafts with if: ${{ !github.event.pull_request.draft }}, or need a job that does",
	}
}

# build runs with always(), so deploy, which needs it, runs on drafts too.
test_status_function_in_the_chain_stops_the_skip if {
	chain := f.edited("    needs: changes", "    needs: changes\n    if: ${{ always() }}\n  deploy:\n    needs: build\n    runs-on: ubuntu-latest\n    steps:\n      - run: true\n  later:\n    needs: changes")
	denied(chain) == {
		"job build must skip drafts with if: ${{ !github.event.pull_request.draft }}, or need a job that does",
		"job deploy must skip drafts with if: ${{ !github.event.pull_request.draft }}, or need a job that does",
	}
}

test_success_forms_override_the_skip if {
	count(denied(f.edited("    needs: changes", "    needs: changes\n    if: ${{ !success() }}"))) == 1
	count(denied(f.edited("    needs: changes", "    needs: changes\n    if: ${{ success() || github.event_name == 'merge_group' }}"))) == 1
	count(denied(f.edited("    needs: changes", "    needs: changes\n    if: ${{ Always( ) }}"))) == 1
	count(denied(f.edited("    needs: changes", "    needs: changes\n    if: ${{ !(success() && github.event_name == 'merge_group') }}"))) == 1
	count(denied(f.edited("    needs: changes", "    needs: changes\n    if: ${{ success() }}"))) == 0
	count(denied(f.edited("    needs: changes", "    needs: changes\n    if: ${{ success() && !contains(github.actor, 'bot') }}"))) == 0
}

test_draft_condition_with_a_status_function_skips if {
	count(denied(f.edited("  changes:\n    if: ${{ !github.event.pull_request.draft }}\n", "  changes:\n    if: ${{ !github.event.pull_request.draft && always() }}\n"))) == 0
}

# Only a gate that is exactly one event comparison counts.
test_event_gate_with_other_terms_needs_the_skip if {
	count(denied(f.edited("  changes:\n    if: ${{ !github.event.pull_request.draft }}\n", "  changes:\n    if: github.event_name == 'schedule' && github.actor != 'bot'\n"))) == 2
	not workflow_drafts.skips({"if": "true != (github.event_name == 'schedule')"})
	not workflow_drafts.skips({"if": "github.event_name == 'schedule' == false"})
	workflow_drafts.skips({"if": "${{ github.event_name == 'schedule' }}"})
}

test_not_equal_event_gate_alone_does_not_skip if {
	not workflow_drafts.skips({"if": "github.event_name != 'push'"})
}

test_compared_parenthesised_gate_does_not_skip if {
	not workflow_drafts.skips({"if": "${{ (github.event_name == 'schedule') != true }}"})
}

test_draft_condition_must_stand_as_a_term if {
	workflow_drafts.skips({"if": "${{ !github.event.pull_request.draft }}"})
	workflow_drafts.skips({"if": "github.event_name != 'push' && !github.event.pull_request.draft"})
	not workflow_drafts.skips({"if": "${{ !github.event.pull_request.draft == false }}"})
	not workflow_drafts.skips({"if": "${{ !(!github.event.pull_request.draft) }}"})
	not workflow_drafts.skips({"if": "${{ !(github.actor == 'x' && !github.event.pull_request.draft) }}"})
	not workflow_drafts.skips({"if": "${{ !(github.actor == 'x' && !github.event.pull_request.draft && github.ref != 'y') }}"})
	not workflow_drafts.skips({"if": "${{ contains(github.ref, 'main') && !github.event.pull_request.draft }}"})
	workflow_drafts.skips({"if": "${{ always() && !github.event.pull_request.draft }}"})
}
