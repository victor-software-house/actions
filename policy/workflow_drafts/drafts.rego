# A draft pull request runs nothing: marking it ready starts the run.
package workflow_drafts

import data.workflow_lib as lib
import rego.v1

types := object.get(lib.triggers, ["pull_request", "types"], []) if is_object(lib.triggers)

types := [] if not is_object(lib.triggers)

condition := "!github.event.pull_request.draft"

# A status function such as always() makes a job run when the jobs it needs
# were skipped, and an || can bypass the draft condition beside it.
overrides_skip(job) if regex.match(`(always|cancelled|failure)\(\)`, object.get(job, "if", ""))

skips(job) if {
	gate := object.get(job, "if", "")
	contains(gate, condition)
	not contains(gate, "||")
	not overrides_skip(job)
}

# A job gated to one event that no pull request raises, such as a daily
# refresh with if: github.event_name == 'schedule', never runs on a draft.
# The gate holds no negation or ||, so the comparison is what decides, and
# every pull_request* event counts as a pull request.
skips(job) if {
	gate := object.get(job, "if", "")
	not contains(gate, "||")
	not contains(gate, "!")
	not overrides_skip(job)
	some match in regex.find_all_string_submatch_n(`github\.event_name\s*==\s*'([a-z_]+)'`, gate, -1)
	not startswith(match[1], "pull_request")
}

needs(job) := [job.needs] if is_string(job.needs)

needs(job) := job.needs if is_array(job.needs)

# GitHub skips a job whose needs were skipped, through any chain of needs,
# unless the job's own if calls a status function.
graph_of_needs := {name: object.get(needs_of, name, []) | some name, _ in lib.jobs}

needs_of := {name: needs(job) | some name, job in lib.jobs}

needs_skipper(job) if {
	not overrides_skip(job)
	some reached in graph.reachable(graph_of_needs, needs(job))
	skips(lib.jobs[reached])
}

deny_drafts contains msg if {
	lib.on_pull_request
	some type in ["opened", "synchronize", "reopened", "ready_for_review"]
	not type in types
	msg := sprintf("pull_request types must list %s, so marking a draft ready starts the run", [type])
}

deny_drafts contains msg if {
	lib.on_pull_request
	some name, job in lib.jobs
	not skips(job)
	not needs_skipper(job)
	msg := sprintf("job %s must skip drafts with if: ${{ %s }}, or need a job that does", [name, condition])
}

exception contains ["drafts"] if lib.excepted("drafts")
