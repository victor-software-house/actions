# The workflow token reads only; a job that writes grants that scope itself.
package workflow_permissions

import data.workflow_lib as lib
import rego.v1

top_level := lib.param("permissions", "top_level")

finding contains {"msg": msg} if {
	# object.get, because a missing key outside `not` would skip the rule.
	not is_object(object.get(lib.workflow, "permissions", null))
	msg := sprintf("top-level permissions must map each scope to one of: %s", [concat(", ", top_level)])
}

finding contains {"msg": msg} if {
	some scope, level in object.get(lib.workflow, "permissions", {})
	not level in top_level
	msg := sprintf("top-level permission %s is %s; grant it on the job that needs it", [scope, level])
}

finding contains {"msg": msg, "job": name} if {
	some name, job in lib.jobs
	"permissions" in object.keys(job)
	not is_object(job.permissions)
	msg := sprintf("job %s must map each permission scope, not %v", [name, job.permissions])
}

deny_permissions contains msg if some msg in lib.denied("permissions", finding)

deny_permissions contains lib.unloaded_message if lib.unloaded("permissions")

warn_permissions contains msg if some msg in lib.warned("permissions", finding)
