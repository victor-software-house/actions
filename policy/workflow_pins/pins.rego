# Every `uses:` pins a commit and names its release in a comment, so a moved
# tag or branch never changes what runs. YAML parsing drops comments, so this
# rule reads the file's lines as written (data.workflow_texts), and reports no
# job: an exception for it covers the whole file.
package workflow_pins

import data.workflow_lib as lib
import rego.v1

pinned := lib.param("pins", "pattern")

finding contains {"msg": msg} if {
	some line in lib.lines
	match := regex.find_all_string_submatch_n(`^\s*(?:-\s+)?uses:\s*(.+)$`, line.text, 1)
	count(match) == 1
	ref := trim_space(match[0][1])
	not local_in_workflow(ref)
	not regex.match(pinned, ref)
	msg := sprintf("line %d: uses %s must pin a commit SHA and name its release in a comment, such as @<sha> # v1.2.3", [line.number, ref])
}

# A workflow runs a local path from its own checkout, so the path needs no
# pin. A composite action has `runs` and no `jobs`: there a local path
# resolves against the caller's checkout, so it must pin like any other.
local_in_workflow(ref) if {
	startswith(ref, "./")
	lib.workflow.jobs
}

deny_pins contains msg if some msg in lib.denied("pins", finding)

deny_pins contains lib.unloaded_message if lib.unloaded("pins")

deny_pins contains "the workflow's text is not loaded; pass policy/texts.sh's output with --data" if not lib.text_loaded

warn_pins contains msg if some msg in lib.warned("pins", finding)
