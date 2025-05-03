# This module contains a shell based component system used to generate
# static document of any format.

pre_setup_phase+=("template_detect")

# Detect if file is a template file.
template_detect() {
	if [ -f "$SRC" ] && [ "${SRC%.tpl}" != "$SRC" ]; then
		log_debug "$SRC is a template page"
		require "$SRC"
		if [ "${ignore:-"false"}" != "false" ]; then
			log_debug "ignoring $SRC template page"
		else
			build_phase+=("template_build")
		fi
	else
		log_debug "$SRC is not a template page (no .tpl extension)"
	fi
}

# Build template.
template_build() {
	mkdir -p "$(dirname "$DST")"
	DST="${DST%.tpl}"
	(
		exec > "$DST"
		require "$SRC"
		render "$@"
	)
}

