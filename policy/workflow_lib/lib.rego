# What every workflow rule reads. conftest passes one workflow at a time
# through its ignore parser, so `input` is the file's lines: the pins rule
# reads them as written, comments included, and the other rules read the same
# text through yaml.unmarshal.
package workflow_lib

import rego.v1

text := concat("\n", [entry.Original | some entry in input])

lines := [{"number": i + 1, "text": entry.Original} | some i, entry in input]

workflow := yaml.unmarshal(text)

jobs := object.get(workflow, "jobs", {})

# YAML 1.1 reads the key `on` as true.
triggers := object.get(workflow, "on", object.get(workflow, "true", {}))

# `on` is a map, one event name, or a list of event names.
on_pull_request if "pull_request" in object.keys(triggers)

on_pull_request if triggers == "pull_request"

on_pull_request if {
	is_array(triggers)
	"pull_request" in triggers
}

# The repository's config, from conftest --data: workflow_policy holds
# parameters and exceptions. It is optional.
default config := {}

config := data.workflow_policy

# A rule's parameter: the repository's workflow_policy.<rule>.<name>, which
# replaces the default whole, else workflow_policy_defaults.<rule>.<name> from
# the shared defaults.yaml.
param(rule, name) := object.get(config, [rule, name], data.workflow_policy_defaults[rule][name])

# Without the defaults a rule would read no parameter and pass everything, so
# it fails instead.
unloaded(rule) if not data.workflow_policy_defaults[rule]

unloaded_message := "the workflow policy's defaults are not loaded; pass its defaults.yaml with --data"

# A repository's exceptions: entries in workflow_policy.exceptions, each with a
# rule, a workflow file name and a reason, and optionally a job, and within
# that job a step by its id or name. An entry without a job covers the whole
# file; one with a job covers only what the rule reports for that job. An
# entry without a reason excepts nothing.
exceptions := object.get(config, "exceptions", [])

step_names(finding) := {name |
	some key in ["id", "name"]
	name := object.get(finding, ["step", key], null)
	name != null
}

covers(entry, finding) if not "job" in object.keys(entry)

covers(entry, finding) if {
	entry.job == finding.job
	not "step" in object.keys(entry)
}

covers(entry, finding) if {
	entry.job == finding.job
	entry.step in step_names(finding)
}

reasons(rule, finding) := {trim_space(entry.reason) |
	some entry in exceptions
	entry.rule == rule
	entry.file == data.conftest.file.name
	trim_space(object.get(entry, "reason", "")) != ""
	covers(entry, finding)
}

# A rule reports each finding as {"msg": …}, with "job" and "step" (the step
# object) where it has them. What no exception covers fails; what one covers
# is a warning that names the reason.
denied(rule, findings) := {finding.msg |
	some finding in findings
	count(reasons(rule, finding)) == 0
}

warned(rule, findings) := {sprintf("excepted (%s): %s", [concat("; ", reasons(rule, finding)), finding.msg]) |
	some finding in findings
	count(reasons(rule, finding)) > 0
}
