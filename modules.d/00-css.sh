pre_setup_phase+=("css_detect")

css_detect() {
	if [ -f "$SRC" ] && [ "${SRC%.css}" != "$SRC" ]; then
		log_debug "$SRC is a css file"
		build_phase+=("css_build")
	else
		log_debug "$SRC is not a css page (no .css extension)"
	fi
}

css_build() {
	mkdir -p "$(dirname "$DST")"
	cp "$SRC" "$DST"
}
