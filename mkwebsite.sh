#!/usr/bin/env bash

set -euo pipefail
shopt -s inherit_errexit
test -n "${DEBUG:-""}" && set -x

eval "$(log4bash)"

# Config vars.
: "${SRC_DIR:="src"}"
: "${OUT_DIR:="build"}"
: "${CACHE_DIR:="cache"}"
: "${HOST:="127.0.0.1"}"
: "${PORT:=8080}"

# Globals
declare -a \
	pre_setup_phase setup_phase post_setup_phase \
	pre_build_phase build_phase post_build_phase \
	pre_clean_phase clean_phase post_clean_phase

# Execute provided phase hooks sequentially until one fails or sets
# $PHASE_STOP to a non empty string.
phase() {
	local old="${PHASE:-}"
	export PHASE="$1"
	shift

	log_debug "phase $PHASE ($#: $*)..."

	while [ "$#" -gt 0 ] && [ -z "${PHASE_STOP:-}" ]; do
		log_debug "$PHASE: $1..."
		"$1"
		log_debug "$PHASE: $1 done"
		shift
	done
	log_debug "phase $PHASE done (stopped: ${PHASE_STOP:-false})"

	unset PHASE_STOP
	unset PHASE

	if [ -n "$old" ]; then
		export PHASE="$old"
	fi
}

# Build a single page.
mkpage() {
	local src="$1"
	local dst="$2"

	(
		export SRC="$src"
		export DST="$dst"

		log_debug "$SRC..."
		phase "pre-setup" "${pre_setup_phase[@]}"
		phase "setup" "${setup_phase[@]}"
		phase "post-setup" "${post_setup_phase[@]}"
		phase "pre-build" "${pre_build_phase[@]}"
		phase "build" "${build_phase[@]}"
		phase "post-build" "${post_build_phase[@]}"
		phase "pre-clean" "${pre_clean_phase[@]}"
		phase "clean" "${clean_phase[@]}"
		phase "post-clean" "${post_clean_phase[@]}"
	)
}

load_modules() {
	: "${MODULES:="$(find "$SRC_DIR/../modules.d" -type f -printf ':%p' | cut -d ':' -f 2-)"}"

	test -z "$MODULES" && log_fatal "no modules to load: \$MODULES is empty"
	log_debug "\$MODULES=$MODULES"
	while read -r mod; do
		log_debug "loading module $mod"
		# shellcheck disable=SC1090
		source "$mod"
	done < <(tr ':' '\n' <<< "$MODULES")

}

build() {
	# Build output pages.
	find "$SRC_DIR" -type f | while read -r file; do
		mkpage "$file" "$OUT_DIR/${file#"$SRC_DIR"/}"
	done
}

print_help() {
	echo "mkwebsite.sh v0.1.0"
	echo "Static site generator in bash"
	echo ""
	echo "USAGE:"
	echo "  mkwebsite.sh COMMAND COMMAND_OPTIONS..."
	echo ""
	echo "COMMANDS:"
	echo "  build                            build website"
	echo "  help                             print this menu"
	echo "  watch                            watch '$SRC_DIR' (e.g. \$SRC_DIR) for changes and rebuild on change"
}

# Watch for changes under $SRC_DIR and rebuild on change.
watch() {
	load_modules
	build

	lighttpd -D -f <(cat <<EOF
server.document-root = "$(realpath "$OUT_DIR")"
server.bind = "$HOST"
server.port = $PORT

server.modules = (
  "mod_accesslog",
  "mod_indexfile"
)

accesslog.filename = "$(tty)"
server.errorlog = "$(tty)"

# File to search for when a directory is requested (e.g. /)
index-file.names = ("index.html", "index.htm")
EOF
) &

	# Watch for file changes.
	inotifywait \
		-e 'modify' -e 'close_write' -e 'moved_to' -e 'moved_from' -e 'move' \
		-e 'move_self' -e 'create' -e 'delete' -e 'delete_self' \
		-rm "$SRC_DIR" \
		| while read -r _; do
				log_info "fs changed, rebuilding..."

				# Read all events without blocking.
				while read -r -t 0.1 _; do
					true
				done
				# Then build once.
				build
			done
}

main() {
	if [ "$#" = "0" ]; then
		print_help
		exit 1
	fi

	# Load config file.
	if [ -f "mkwebsite.conf" ]; then
		log_info "loading configuration file"
		# shellcheck disable=SC1091
		source "mkwebsite.conf"
	fi

	while [ "$#" -gt 0 ]; do
		case "$1" in
			-h|--help|help)
				print_help
				exit 0
				;;

			build)
				shift
				load_modules
				build "$@"
				exit 0
				;;

			watch)
				shift
				watch "$@"
				exit 0
				;;

			*)
				log_error "unknown command $1"
				print_help
				exit 1
				;;
		esac
	done
}

main "$@"
