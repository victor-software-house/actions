# A draft pull request runs nothing: marking it ready starts the run.
package workflow_drafts

import data.workflow_lib as lib
import rego.v1

types := object.get(lib.triggers, ["pull_request", "types"], []) if is_object(lib.triggers)

types := [] if not is_object(lib.triggers)

condition := "!github.event.pull_request.draft"

skips(job) if contains(object.get(job, "if", ""), condition)

# A job gated to one event other than pull_request, such as a daily refresh
# with if: github.event_name == 'schedule', never runs on a pull request.
skips(job) if {
	gate := object.get(job, "if", "")
	not contains(gate, "||")
	some match in regex.find_all_string_submatch_n(`github\.event_name\s*==\s*'([a-z_]+)'`, gate, -1)
	match[1] != "pull_request"
}

needs(job) := [job.needs] if is_string(job.needs)

needs(job) := job.needs if is_array(job.needs)

needs_skipper(job) if {
	some need in needs(job)
	skips(lib.jobs[need])
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
