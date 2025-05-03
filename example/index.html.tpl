export title="mkwebsite.sh"
export subtitle="Static site generator in bash"

render() {
	require "$SRC_DIR/layouts/base.tpl"

	cat <<EOF | layout_base
mkwebsite.sh is a static site generator with unlimited possibilities.
\$(date) -> $(date)
EOF
}
