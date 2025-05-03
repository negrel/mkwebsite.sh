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
: "${MKWEBSITE_ENV:="dev"}"

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

	# Execute phases in a subshell so pages are isolated.
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

# Build all pages.
build() {
	# Build output pages.
	find "$SRC_DIR" -type f | while read -r file; do
		mkpage "$file" "$OUT_DIR/${file#"$SRC_DIR"/}"
	done
}

# Load and sources modules.
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

# Print help menu.
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
	# Initial build.
	load_modules
	build

	cp "$0" "$OUT_DIR/reload.sh"

	# Start light http server in background.
	lighttpd -D -f <(cat <<EOF
server.document-root = "$(realpath "$OUT_DIR")"
server.bind = "$HOST"
server.port = $PORT

server.modules = (
	"mod_accesslog",
	"mod_indexfile",
	"mod_setenv",
	"mod_cgi"
)

accesslog.filename = "$(tty)"
server.errorlog = "$(tty)"
server.breakagelog = "$(tty)"

# File to search for when a directory is requested (e.g. /)
index-file.names = ("index.html", "index.htm")

# Allow websocket upgrade.
cgi.upgrade = "enable"
# Hot reload CGI script.
cgi.assign = ( "/reload.sh" => "" )
# Forward PATH for CGI scripts.
setenv.set-environment = (
	"PATH" => "$PATH",
	"OUT_DIR" => "$(realpath "$OUT_DIR")",
	"MKWEBSITE_ENV" => "cgi"
)
EOF
) &

cat <<EOF > "$OUT_DIR/reload.js"
(() => {
  const socket = new WebSocket('/reload.sh');
  socket.addEventListener('error', console.error);
  socket.addEventListener('close', () => {
    window.location.reload()
  });
})();
EOF

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

				# Close reload websockets.
				xargs kill < "$OUT_DIR/reload.pid" || true
				rm "$OUT_DIR/reload.pid"
			done
}

# CGI hot reload websocket handler.
cgi_reload_wss() {
	# Store PID.
	echo $$ >> "$OUT_DIR/reload.pid"

	# See https://www.rfc-editor.org/rfc/rfc6455.html
	local guid="258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
	local key
	key="$(echo -n "$HTTP_SEC_WEBSOCKET_KEY$guid" | sha1sum | cut -d ' ' -f 1 | xxd -p -r | base64)"

	log_info "hot reload websocket initialization"
	# Upgrade to web socket.
	echo "Status: 101"
	echo "Upgrade: WebSocket"
	echo "Connection: Upgrade"
	echo "Sec-WebSocket-Accept: $key"
	echo ""
	# Sleep forever to keep socket open.
	while true; do sleep 1; done
}

main() {
	# Hot reload CGI handler.
	if [ "$MKWEBSITE_ENV" = "cgi" ]; then
		cgi_reload_wss
		exit 0
	fi

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
				MKWEBSITE_ENV="production"
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
