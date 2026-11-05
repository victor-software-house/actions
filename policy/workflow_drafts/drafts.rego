# A draft pull request runs nothing: marking it ready starts the run.
package workflow_drafts

import data.workflow_lib as lib
import rego.v1

types := object.get(lib.triggers, ["pull_request", "types"], []) if is_object(lib.triggers)

types := [] if not is_object(lib.triggers)

condition := lib.param("drafts", "condition")

# A status function in a job's if stops GitHub skipping the job when a job
# it needs was skipped: always(), cancelled() and failure() outright, and
# success() when negated or beside an ||. Function names ignore case.
overrides_skip(job) if regex.match(`(?i)(always|cancelled|failure)\s*\(\s*\)`, object.get(job, "if", ""))

overrides_skip(job) if regex.match(`(?i)!\s*success\s*\(\s*\)`, object.get(job, "if", ""))

# A negated group anywhere beside success() may hold it, so it counts too.
overrides_skip(job) if {
	gate := object.get(job, "if", "")
	regex.match(`(?i)success\s*\(\s*\)`, gate)
	regex.match(`!\s*\(`, gate)
}

overrides_skip(job) if {
	gate := object.get(job, "if", "")
	regex.match(`(?i)success\s*\(\s*\)`, gate)
	contains(gate, "||")
}

# The draft condition skips drafts when it is one of the terms the if joins
# with &&, even next to a status function: written exactly, not compared,
# negated again, or beside an ||. The if may hold no parenthesis other than
# an empty call such as always(), so no group or argument can hide the
# condition inside a term that negates or compares it.
skips(job) if {
	gate := object.get(job, "if", "")
	not contains(gate, "||")
	bare := trim_space(trim_suffix(trim_prefix(trim_space(gate), "${{"), "}}"))

	# A string literal holds no term, whatever its text.
	unquoted := regex.replace(bare, `'[^']*'`, "''")
	not regex.match(`[()]`, regex.replace(unquoted, `\w+\s*\(\s*\)`, ""))
	some term in split(unquoted, "&&")
	trim_space(term) == condition
}

# A job gated to one event that no pull request raises, such as a daily
# refresh with if: github.event_name == 'schedule', never runs on a draft.
# The whole if must be that one comparison, optionally inside ${{ }}: any
# other term could negate it or bypass it, so such a job needs the draft
# condition or an exception. Every pull_request* event counts as a pull
# request.
skips(job) if {
	match := regex.find_all_string_submatch_n(`^\s*(?:\$\{\{\s*)?github\.event_name\s*==\s*'([a-z_]+)'\s*(?:\}\})?\s*$`, object.get(job, "if", ""), 1)
	count(match) == 1
	not startswith(match[0][1], "pull_request")
}

needs(job) := [job.needs] if is_string(job.needs)

needs(job) := job.needs if is_array(job.needs)

# GitHub skips a job whose needs were skipped, through any chain of needs,
# unless the job's own if calls a status function: such a job runs, so the
# skip stops there and passes on to nothing that needs it.
graph_of_needs := {name: passed_on(name, job) | some name, job in lib.jobs}

passed_on(name, job) := [] if overrides_skip(job)

passed_on(name, job) := object.get(needs_of, name, []) if not overrides_skip(job)

needs_of := {name: needs(job) | some name, job in lib.jobs}

needs_skipper(job) if {
	not overrides_skip(job)
	some reached in graph.reachable(graph_of_needs, needs(job))
	skips(lib.jobs[reached])
}

finding contains {"msg": msg} if {
	lib.on_pull_request
	some type in lib.param("drafts", "types")
	not type in types
	msg := sprintf("pull_request types must list %s, so marking a draft ready starts the run", [type])
}

finding contains {"msg": msg, "job": name} if {
	lib.on_pull_request
	some name, job in lib.jobs
	not skips(job)
	not needs_skipper(job)
	msg := sprintf("job %s must skip drafts with if: ${{ %s }}, or need a job that does", [name, condition])
}

deny_drafts contains msg if some msg in lib.denied("drafts", finding)

deny_drafts contains lib.unloaded_message if lib.unloaded("drafts")

warn_drafts contains msg if some msg in lib.warned("drafts", finding)
