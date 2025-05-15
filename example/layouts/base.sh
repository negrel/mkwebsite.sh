# This file contains the base layout used for page rendering.

layout_base() {
	cat <<EOF
<!DOCTYPE html>
<html lang="en">
	<head>
		<meta charSet="UTF-8" />
		<title>${title:=""}</title>
		<meta name="generator" content="mkwebsite.sh" />
		<meta name="description" content="${subtitle:=""}" />
		<meta name="viewport" content="width=device-width, initial-scale=1" />
		<link rel="stylesheet" href="/styles/reset.css" />
		<link rel="stylesheet" href="/styles/the_monospace_web.css" />
		<link rel="stylesheet" href="/styles/main.css" />
		<script src="/reload.js" defer></script>
	</head>
	<body class="$(test -n "${DEBUG:-}" && echo "debug")">
		<div class="debug-grid"></div>
		<header>
			<table class="header">
				<tr>
					<td colspan="2" rowspan="2" class="width-auto">
						<h1 class="title">${title}</h1>
						<span class="subtitle">$subtitle</span>
					</td>
					<th>Version</th>
					<td class="width-min">v0.1.0</td>
				</tr>
				<tr>
					<th>Updated</th>
					<td class="width-min"><time style="white-space: pre;">$(date --rfc-3339=date)</time></td>
				</tr>
				<tr>
					<th class="width-min">Author</th>
					<td class="width-auto">
						<a href="https://www.negrel.dev">
							<cite>Alexandre Negrel</cite>
						</a>
					</td>
					<th class="width-min">License</th>
					<td>MIT</td>
				</tr>
			</table>
		</header>
		$(cat)
	</body>
</html>
EOF
}
