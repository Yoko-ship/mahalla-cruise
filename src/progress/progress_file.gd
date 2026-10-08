class_name ProgressFile
extends RefCounted
## File access for the save document: size limit, temporary files, and atomic replacement.
## Static and stateless; LocalProgressStore keeps the error state and the backup policy.

const MAX_FILE_BYTES: int = 1048576


## Returns {"document": Dictionary, "error": Error, "blocked": bool}. A missing file is
## an empty document; an unreadable, oversized, or newer file blocks further writes.
static func read(path: String) -> Dictionary:
	var result := {"document": {}, "error": OK, "blocked": false}
	if not FileAccess.file_exists(path):
		return result
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		result.error = FileAccess.get_open_error()
		result.blocked = true
		return result
	if file.get_length() > MAX_FILE_BYTES:
		file.close()
		result.error = ERR_FILE_CORRUPT
		result.blocked = true
		return result
	result.document = ProgressData.parse(file.get_as_text())
	file.close()
	if ProgressData.is_newer(result.document):
		result.error = ERR_UNAVAILABLE
		result.blocked = true
	return result


static func write(path: String, document: Dictionary) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(document, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	return error


static func replace(source: String, destination: String) -> Error:
	return DirAccess.rename_absolute(
		ProjectSettings.globalize_path(source), ProjectSettings.globalize_path(destination)
	)
