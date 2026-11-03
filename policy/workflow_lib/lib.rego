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

# A repository's exceptions live in its own package workflow_exceptions, one
# entry per rule and workflow file, each with a reason. An entry without a
# reason excepts nothing.
excepted(rule) if {
	some entry in data.workflow_exceptions.exceptions
	entry.rule == rule
	entry.file == data.conftest.file.name
	trim_space(object.get(entry, "reason", "")) != ""
}
