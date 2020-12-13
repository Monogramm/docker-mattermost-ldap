#!/bin/bash
set -eo pipefail

declare -A cmd=(
	[apache]='apache2-foreground'
	[fpm]='php-fpm'
	[fpm-alpine]='php-fpm'
)

declare -A compose=(
	[apache]='apache'
	[fpm]='fpm'
	[fpm-alpine]='fpm'
)

declare -A base=(
	[apache]='debian'
	[fpm]='debian'
	[fpm-alpine]='alpine'
)

variants=(
	apache
	fpm
	fpm-alpine
)

min_version='2.0'


# version_greater_or_equal A B returns whether A >= B
function version_greater_or_equal() {
	[[ "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1" || "$1" == "$2" ]];
}

dockerRepo="monogramm/docker-mattermost-ldap"
# Retrieve automatically the latest versions
latests=( master
	$( curl -fsSL 'https://api.github.com/repos/Crivaledaz/Mattermost-LDAP/tags' |tac|tac| \
	grep -oE '[[:digit:]]+\.[[:digit:]]+' | \
	sort -urV ) )

# Remove existing images
echo "reset docker images"
#find ./images -maxdepth 1 -type d -regextype sed -regex '\./images/[[:digit:]]\+\.[[:digit:]]\+' -exec rm -r '{}' \;
rm -rf ./images/*

echo "update docker images"
travisEnv=
for latest in "${latests[@]}"; do
	version=$(echo "$latest" | cut -d. -f1-2)

	# Only add versions >= "$min_version"
	if version_greater_or_equal "$version" "$min_version"; then

		for variant in "${variants[@]}"; do
			# Create the version directory with a Dockerfile.
			dir="images/$version/$variant"
			if [ -d "$dir" ]; then
				continue
			fi
			echo "Updating $latest [$version-$variant]"
			mkdir -p "$dir"

			template="Dockerfile.${base[$variant]}"
			cp "template/$template" "$dir/Dockerfile"
			cp "template/entrypoint.sh" "$dir/entrypoint.sh"

			cp "template/.dockerignore" "$dir/.dockerignore"
			cp -r "template/hooks" "$dir/"
			cp -r "template/test" "$dir/"
			cp "template/.env" "$dir/.env"
			cp "template/docker-compose_${compose[$variant]}.yml" "$dir/docker-compose.test.yml"
			cp "template/nginx.conf" "$dir/nginx.conf"

			# Replace the variables.
			if [[ "$latest" == 'master' ]]; then
				sed -ri -e '
					s/%%VARIANT%%/-'"$variant"'/g;
					s/%%VERSION%%/'"$latest"'/g;
					s/%%CMD%%/'"${cmd[$variant]}"'/g;
				' "$dir/Dockerfile"
			else
				sed -ri -e '
					s/%%VARIANT%%/-'"$variant"'/g;
					s/%%VERSION%%/v'"$latest"'/g;
					s/%%CMD%%/'"${cmd[$variant]}"'/g;
				' "$dir/Dockerfile"
			fi

			# Create a list of "alias" tags for DockerHub post_push
			if [ "$latest" = 'master' ]; then
				echo "$variant " > "$dir/.dockertags"
			else
				echo "$latest-$variant " > "$dir/.dockertags"
			fi

			# Add Travis-CI env var
			travisEnv='\n    - VERSION='"$version"' VARIANT='"$variant$travisEnv"

			if [[ $1 == 'build' ]]; then
				tag="$version-$variant"
				echo "Build Dockerfile for ${tag}"
				docker build \
                                    --build-arg VCS_REF=`git rev-parse --short HEAD` \
                                    --build-arg BUILD_DATE=`date -u +"%Y-%m-%dT%H:%M:%SZ"` \
                                    -t "${dockerRepo}:${tag}" "$dir"
			fi
		done
	fi

done

# update .travis.yml
travis="$(awk -v 'RS=\n\n' '$1 == "env:" && $2 == "#" && $3 == "Environments" { $0 = "env: # Environments'"$travisEnv"'" } { printf "%s%s", $0, RS }' .travis.yml)"
echo "$travis" > .travis.yml
